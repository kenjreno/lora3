{ JanusImpl.inc - TJanus bidirectional transfer protocol implementation
  FreePascal conversion of janus.cpp (lines 68-713)
  Included by FTrans.pas }

{ ---- Janus protocol constants ---- }
const
  JAN_DLE          = $10;

  { Protocol capability flags }
  CANCRC32         = $80;
  CANFREQ          = $40;

  { File Transmission States }
  XDONE            = 0;
  XSENDFNAME       = 1;
  XRCVFNACK        = 2;
  XSENDBLK         = 3;
  XRCVEOFACK       = 4;
  XSENDFREQNAK     = 5;
  XRCVFRNAKACK     = 6;

  { File Reception States }
  RDONE            = 0;
  RRCVFNAME        = 1;
  RRCVBLK          = 2;

  { Packet Types }
  NOPKT            = 0;
  BADPKT           = Ord('@');
  FNAMEPKT         = Ord('A');
  FNACKPKT         = Ord('B');
  BLKPKT           = Ord('C');
  RPOSPKT          = Ord('D');
  EOFACKPKT        = Ord('E');
  HALTPKT_J        = Ord('F');
  HALTACKPKT       = Ord('G');
  FREQPKT          = Ord('H');
  FREQNAKPKT       = Ord('I');
  FRNAKACKPKT      = Ord('J');

  { Non-byte values returned by GetRawByte/GetByte }
  BUFEMPTY         = -1;
  J_PKTSTRT        = -2;
  J_PKTEND         = -3;
  J_NOCARRIER      = -4;
  J_PKTSTRT32      = -5;

  { DLE-escaped packet marker bytes }
  PKTSTRTCHR       = Ord('a');
  PKTENDCHR        = Ord('b');
  PKTSTRTCHR32     = Ord('c');

{ ======================================================================
  TJanus constructor / destructor
  ====================================================================== }

constructor TJanus.Create;
begin
  inherited Create;
  Com := nil;
  Log := nil;
  LastSentJ := 0;
  CanCrc32 := 1;
  Rxbufptr := nil;
  Rxbufmax := @JRxBuffer[BUFMAX + 7];
  WaitFlag := 0;
  RxPktCrc32 := 0;
  RxPktCrc16 := 0;
  RxCrc32 := 0;
  IsOutbound := 0;
  LastPktName := 0;
  RxTempSize := 0;
  MakeRequests := 1;
  AllowRequests := 1;
  TimeoutSecs := 10;
  Speed := 19200;
  RxPath := '';
  RxFileName := '';
  TxFileName := '';
  TxQueue := nil;
  RxQueue := nil;
  Outbound := nil;
  RxFile := -1;
  TxFile := -1;
  Rxblklen := 0;
  FillChar(RxTemp, SizeOf(RxTemp), 0);
  RxTempPos := nil;
  FillChar(JRxBuffer, SizeOf(JRxBuffer), 0);
  FillChar(JTxBuffer, SizeOf(JTxBuffer), 0);
  Rxpos := 0;
  RxFilesize := 0;
  RxFiletime := 0;
  pkttype := 0;
  SharedCap := 0;
  Done := 0;
  xstate := 0;
  rstate := 0;
  rpos_count := 0;
  blklen := 0;
  txblklen := 0;
  txblkmax := 0;
  rxstpos := 0;
  length_ := 0;
  xmit_retry := 0;
  txpos := 0;
  txstpos := 0;
  timeout := 0;
  txlength := 0;
  lasttx := 0;
  last_blkpos := 0;
  rpos_retry := 0;
  rpos_sttime := 0;
end;

destructor TJanus.Destroy;
begin
  inherited Destroy;
end;

{ ======================================================================
  GetRawByte - read raw byte from comm with optional wait
  ====================================================================== }

function TJanus.GetRawByte: SmallInt;
var
  timeval: LongInt;
begin
  if Com.BytesReady <> 0 then
  begin
    Result := SmallInt(Com.ReadByte);
    Exit;
  end;
  if Com.Carrier = 0 then
  begin
    Result := J_NOCARRIER;
    Exit;
  end;

  if WaitFlag = 0 then
  begin
    Result := BUFEMPTY;
    Exit;
  end;

  timeval := DateTimeToUnix(Now) + TimeoutSecs;

  while Com.BytesReady = 0 do
  begin
    if Com.Carrier = 0 then
    begin
      Result := J_NOCARRIER;
      Exit;
    end;
    if DateTimeToUnix(Now) > timeval then
    begin
      Result := BUFEMPTY;
      Exit;
    end;
  end;

  Result := SmallInt(Com.ReadByte);
end;

{ ======================================================================
  GetByte - read byte with DLE unescaping
  ====================================================================== }

function TJanus.GetByte: SmallInt;
var
  c: SmallInt;
  w: SmallInt;
begin
  c := GetRawByte;
  if c = JAN_DLE then
  begin
    w := WaitFlag;
    WaitFlag := 1;
    c := GetRawByte;
    if c >= 0 then
    begin
      c := c xor $40;
      case c of
        PKTSTRTCHR:
          c := J_PKTSTRT;
        PKTSTRTCHR32:
          c := J_PKTSTRT32;
        PKTENDCHR:
          c := J_PKTEND;
      end;
    end;
    WaitFlag := w;
  end;
  Result := c;
end;

{ ======================================================================
  GetPacket - receive and validate a complete packet
  ====================================================================== }

function TJanus.GetPacket: Byte;
var
  c: SmallInt;
  i: SmallInt;
  p: PByte;
  PktCrc: LongWord;
begin
  WaitFlag := 0;

  p := Rxbufptr;
  if p = nil then
  begin
    repeat
      c := GetByte;
    until (c < 0) and (c <> J_PKTEND);

    case c of
      J_PKTSTRT:
      begin
        RxCrc32 := 0;
        p := @JRxBuffer[0];
        RxPktCrc16 := 0;
      end;
      J_PKTSTRT32:
      begin
        RxCrc32 := 1;
        p := @JRxBuffer[0];
        RxPktCrc32 := $FFFFFFFF;
      end;
      J_NOCARRIER:
      begin
        Result := HALTPKT_J;
        Exit;
      end;
    else
      begin
        Result := NOPKT;
        Exit;
      end;
    end;
  end;

  if RxCrc32 <> 0 then
  begin
    c := GetByte;
    while (c >= 0) and (PtrUInt(p) < PtrUInt(Rxbufmax)) do
    begin
      p^ := Byte(c);
      Inc(p);
      RxPktCrc32 := Crc32(Byte(c), RxPktCrc32);
      c := GetByte;
    end;
  end
  else
  begin
    c := GetByte;
    while (c >= 0) and (PtrUInt(p) < PtrUInt(Rxbufmax)) do
    begin
      p^ := Byte(c);
      Inc(p);
      RxPktCrc16 := Crc16(Byte(c), RxPktCrc16);
      c := GetByte;
    end;
  end;

  case c of
    J_PKTEND:
    begin
      WaitFlag := 1;
      PktCrc := 0;
      if RxCrc32 <> 0 then
        i := 4
      else
        i := 2;
      while i > 0 do
      begin
        c := GetByte;
        if c < 0 then
          Break;
        PktCrc := (PktCrc shl 8) or LongWord(Byte(c));
        Dec(i);
      end;
      if i = 0 then
      begin
        if ((RxCrc32 <> 0) and (PktCrc = RxPktCrc32)) or
           ((RxCrc32 = 0) and (Word(PktCrc) = RxPktCrc16)) then
        begin
          Rxbufptr := nil;
          Dec(p);
          Rxblklen := Word(PtrUInt(p) - PtrUInt(@JRxBuffer[0]));
          Result := p^;
          Exit;
        end;
      end;
      { Bad CRC - fall through }
      if c = J_NOCARRIER then
      begin
        Result := HALTPKT_J;
        Exit;
      end;
      Rxbufptr := nil;
      Result := BADPKT;
      Exit;
    end;

    BUFEMPTY:
    begin
      Rxbufptr := p;
      Result := NOPKT;
      Exit;
    end;

    J_PKTSTRT:
    begin
      RxCrc32 := 0;
      Rxbufptr := @JRxBuffer[0];
      RxPktCrc16 := 0;
      Result := BADPKT;
      Exit;
    end;

    J_PKTSTRT32:
    begin
      RxCrc32 := 1;
      Rxbufptr := @JRxBuffer[0];
      RxPktCrc32 := $FFFFFFFF;
      Result := BADPKT;
      Exit;
    end;

    J_NOCARRIER:
    begin
      Result := HALTPKT_J;
      Exit;
    end;
  else
    begin
      Rxbufptr := nil;
      Result := BADPKT;
    end;
  end;
end;

{ ======================================================================
  SendByte - send byte with DLE escaping for special chars
  ====================================================================== }

procedure TJanus.SendByte(AByte: Byte);
begin
  case AByte of
    $0D:
    begin
      if LastSentJ <> Ord('@') then
      begin
        LastSentJ := AByte;
        Com.BufferByte(AByte);
      end
      else
      begin
        Com.BufferByte(JAN_DLE);
        AByte := AByte xor $40;
        LastSentJ := AByte;
        Com.BufferByte(AByte);
      end;
    end;

    JAN_DLE, XON, XOFF:
    begin
      Com.BufferByte(JAN_DLE);
      AByte := AByte xor $40;
      LastSentJ := AByte;
      Com.BufferByte(AByte);
    end;
  else
    LastSentJ := AByte;
    Com.BufferByte(AByte);
  end;
end;

{ ======================================================================
  SendJPacket - send a complete Janus packet
  ====================================================================== }

procedure TJanus.SendJPacket(Buffer: PByte; Len: Word; PType: Word);
var
  i: SmallInt;
  crc16: Word;
  crc32val: LongWord;
begin
  Com.BufferByte(JAN_DLE);

  if (CanCrc32 <> 0) and (PType <> Word(FNAMEPKT)) then
  begin
    Com.BufferByte(Byte(PKTSTRTCHR32 xor $40));

    crc32val := $FFFFFFFF;
    if Buffer <> nil then
    begin
      for i := 0 to Len - 1 do
      begin
        SendByte(Buffer[i]);
        crc32val := Crc32(Byte(Buffer[i] and $FF), crc32val);
      end;
    end;

    Com.BufferByte(Byte(PType));
    crc32val := Crc32(Byte(PType), crc32val);

    Com.BufferByte(JAN_DLE);
    Com.BufferByte(Byte(PKTENDCHR xor $40));

    SendByte(Byte(crc32val shr 24));
    SendByte(Byte((crc32val shr 16) and $FF));
    SendByte(Byte((crc32val shr 8) and $FF));
    SendByte(Byte(crc32val and $FF));
  end
  else
  begin
    Com.BufferByte(Byte(PKTSTRTCHR xor $40));

    crc16 := 0;
    if Buffer <> nil then
    begin
      for i := 0 to Len - 1 do
      begin
        SendByte(Buffer[i]);
        crc16 := Crc16(Byte(Buffer[i] and $FF), crc16);
      end;
    end;

    Com.BufferByte(Byte(PType));
    crc16 := Crc16(Byte(PType), crc16);

    Com.BufferByte(JAN_DLE);
    Com.BufferByte(Byte(PKTENDCHR xor $40));

    SendByte(Byte(crc16 shr 8));
    SendByte(Byte(crc16 and $FF));
  end;

  Com.UnbufferBytes;
end;

{ ======================================================================
  ProcessFileName - process received filename packet
  ====================================================================== }

function TJanus.ProcessFileName: LongInt;
var
  p, q: PChar;
  fileinfo: PChar;
  cap: Byte;
  gota: Boolean;
  existSize, existTime: LongInt;
  SR: TSearchRec;
  ch: Char;
  i: Integer;
  InfoStr: String;
  fd: TFileStream;
begin
  RxFileName := '';
  Result := -1;

  { Parse capability flags from after the second null }
  fileinfo := PChar(@JRxBuffer[0]);
  fileinfo := StrEnd(fileinfo) + 1;  { skip filename to fileinfo }
  p := StrEnd(fileinfo) + 1;         { skip fileinfo to capability byte }
  if Rxblklen > Word(PtrUInt(p) - PtrUInt(@JRxBuffer[0])) then
  begin
    cap := Byte(p^) and (CANCRC32 or CANFREQ);
    if (cap and CANCRC32) <> 0 then
      CanCrc32 := 1;
  end;

  { Extract base filename (strip path) }
  p := PChar(@JRxBuffer[0]);
  q := p;
  while p^ <> #0 do
  begin
    if (p^ = '/') or (p^ = '\') or (p^ = ':') then
      q := p + 1;
    Inc(p);
  end;

  if q^ <> #0 then
  begin
    RxFileName := IncludeTrailingPathDelimiter(RxPath) + LowerCase(StrPas(q));

    { Parse size and octal time from fileinfo }
    RxFilesize := 0;
    RxFiletime := 0;
    if fileinfo^ <> #0 then
    begin
      InfoStr := StrPas(fileinfo);
      i := Pos(' ', InfoStr);
      if i > 0 then
      begin
        RxFilesize := StrToIntDef(Copy(InfoStr, 1, i - 1), 0);
        RxFiletime := 0;
        for i := i + 1 to Length(InfoStr) do
        begin
          ch := InfoStr[i];
          if (ch >= '0') and (ch <= '7') then
            RxFiletime := RxFiletime * 8 + (Ord(ch) - Ord('0'))
          else
            Break;
        end;
      end
      else
        RxFilesize := StrToIntDef(InfoStr, 0);
    end;

    if Log <> nil then
      Log.Write(' Receiving %s; %db, %d min.',
        [StrPas(q), RxFilesize, (RxFilesize * 10 div LongInt(Speed) + 53) div 54]);

    { Add to receive queue }
    if RxQueue <> nil then
    begin
      RxQueue.Init;
      RxQueue.Name := StrPas(q);
      RxQueue.Complete := RxFileName;
      RxQueue.Size := RxFilesize;
    end;

    Result := 0;

    { Check for existing file }
    if FileExists(RxFileName) then
    begin
      existSize := 0;
      existTime := 0;
      if FindFirst(RxFileName, faAnyFile, SR) = 0 then
      begin
        existSize := SR.Size;
        existTime := FileAge(RxFileName);
        if existTime > 0 then
          existTime := DateTimeToUnix(FileDateToDateTime(existTime));
        FindClose(SR);
      end;

      if (RxFilesize = existSize) and (RxFiletime = existTime) then
      begin
        if Log <> nil then
          Log.Write('+Already have %s', [RxFileName]);
        Result := -1;
        Exit;
      end
      else if RxFilesize > existSize then
      begin
        Result := existSize;
        if Log <> nil then
          Log.Write('+Synchronizing to offset %d', [Result]);
      end
      else
      begin
        { Rename duplicate }
        i := Length(RxFileName);
        gota := False;
        repeat
          ch := RxFileName[i];
          if ((ch >= '0') and (ch <= '9')) or gota then
          begin
            if ch = '9' then
            begin
              gota := True;
              RxFileName[i] := 'A';
            end
            else
              RxFileName[i] := Chr(Ord(ch) + 1);
          end
          else
            RxFileName[i] := '0';
        until not FileExists(RxFileName);
        if Log <> nil then
          Log.Write('+Renaming dupe file %s', [RxFileName]);
      end;
    end;

    { Open receive file for append }
    try
      if FileExists(RxFileName) and (Result > 0) then
      begin
        fd := TFileStream.Create(RxFileName, fmOpenReadWrite or fmShareDenyNone);
        fd.Seek(0, soFromEnd);
      end
      else
        fd := TFileStream.Create(RxFileName, fmCreate);
      RxFile := fd.Handle;
      fd.Free;  { keep fd handle open via OS }
    except
      Result := -1;
    end;
  end;
end;

{ ======================================================================
  GetNextFile - get next file to transmit from queue
  ====================================================================== }

procedure TJanus.GetNextFile;
var
  BaseName, InfoStr: String;
  SR: TSearchRec;
  fsize, ftime, fmode: LongInt;
begin
  TxFileName := '';
  FillChar(JTxBuffer, 2, 0);

  if TxQueue <> nil then
  begin
    IsOutbound := 0;
    while TxQueue.First do
    begin
      if FileExists(TxQueue.Complete) then
      begin
        TxFileName := TxQueue.Complete;
        BaseName := TxQueue.Name;

        { Build packet: name\0info\0 }
        FillChar(JTxBuffer, SizeOf(JTxBuffer), 0);
        if Length(BaseName) < BUFMAX - 64 then
          Move(BaseName[1], JTxBuffer[0], Length(BaseName));

        fsize := 0;
        ftime := 0;
        fmode := 0;
        if FindFirst(TxFileName, faAnyFile, SR) = 0 then
        begin
          fsize := SR.Size;
          ftime := DateTimeToUnix(FileDateToDateTime(SR.Time));
          {$IFDEF UNIX}
          fmode := SR.Attr;
          {$ENDIF}
          FindClose(SR);
        end;

        InfoStr := Format('%d %o %o', [fsize, ftime, fmode]);
        Move(InfoStr[1], JTxBuffer[Length(BaseName) + 1], Length(InfoStr));

        if Log <> nil then
          Log.Write(' Sending %s; %db, %d min.',
            [TxQueue.Name, fsize, (fsize * 10 div LongInt(Speed) + 53) div 54]);
        Break;
      end
      else
        TxQueue.Remove('');
    end;
  end;
end;

{ ======================================================================
  Transfer - main Janus bidirectional transfer loop
  ====================================================================== }

procedure TJanus.Transfer;
var
  nowTime: LongInt;
  txBufLong: PLongInt;
  rxBufLong: PLongInt;
  fs: TFileStream;
  bytesRead: LongInt;
  flen: LongInt;
  capByte: Byte;
begin
  RxFile := -1;
  TxFile := -1;
  fs := nil;

  if Speed > 64000 then
    txblkmax := BUFMAX
  else
  begin
    txblkmax := Word((Speed div 300) * 128);
    if txblkmax > BUFMAX then
      txblkmax := BUFMAX;
  end;
  txblklen := txblkmax;
  xmit_retry := 0;
  lasttx := 0;
  txlength := 0;
  rxstpos := 0;
  length_ := 0;
  rpos_count := 0;
  rpos_sttime := 0;
  rpos_retry := 0;
  last_blkpos := 0;

  xstate := XSENDFNAME;
  rstate := RRCVFNAME;

  GetNextFile;

  repeat
    nowTime := DateTimeToUnix(Now);

    { Handle transmit retries }
    if xmit_retry <> 0 then
    begin
      if nowTime > xmit_retry then
      begin
        xmit_retry := 0;
        case xstate of
          XRCVFNACK:
            xstate := XSENDFNAME;
          XRCVFRNAKACK:
            xstate := XSENDFREQNAK;
          XRCVEOFACK:
          begin
            txpos := lasttx;
            if fs <> nil then
              fs.Seek(txpos, soFromBeginning);
            xstate := XSENDBLK;
          end;
        end;
      end;
    end;

    { Transmit state machine }
    txBufLong := PLongInt(@JTxBuffer[0]);
    case xstate of
      XSENDFNAME:
      begin
        { Calculate packet length: find double-null at end of name\0info\0 }
        blklen := 0;
        while blklen < BUFMAX do
        begin
          if (JTxBuffer[blklen] = 0) and (blklen > 0) then
          begin
            Inc(blklen);
            if JTxBuffer[blklen] = 0 then
            begin
              Inc(blklen);
              Break;
            end;
            { Skip to end of info string }
            while (blklen < BUFMAX) and (JTxBuffer[blklen] <> 0) do
              Inc(blklen);
            Inc(blklen);
            Break;
          end;
          Inc(blklen);
        end;
        JTxBuffer[blklen] := CANCRC32 or CANFREQ;
        Inc(blklen);
        SendJPacket(@JTxBuffer[0], blklen, FNAMEPKT);
        xstate := XRCVFNACK;
        xmit_retry := DateTimeToUnix(Now) + TimeoutSecs;
        SendJPacket(nil, 0, EOFACKPKT);
      end;

      XSENDBLK:
      begin
        txBufLong^ := txpos;
        lasttx := txpos;
        bytesRead := 0;
        if fs <> nil then
          bytesRead := fs.Read(JTxBuffer[SizeOf(LongInt)], txblklen);
        blklen := Word(bytesRead);
        SendJPacket(@JTxBuffer[0], Word(SizeOf(LongInt) + blklen), BLKPKT);
        Inc(txpos, blklen);

        flen := 0;
        if fs <> nil then
          flen := fs.Size;
        if (txpos >= flen) or (blklen < txblklen) then
        begin
          xmit_retry := DateTimeToUnix(Now) + TimeoutSecs;
          xstate := XRCVEOFACK;
        end;
      end;

      XSENDFREQNAK:
      begin
        SendJPacket(nil, 0, FREQNAKPKT);
        xmit_retry := DateTimeToUnix(Now) + TimeoutSecs;
        xstate := XRCVFRNAKACK;
      end;
    end;

    { Receive packet processing }
    rxBufLong := PLongInt(@JRxBuffer[0]);

    pkttype := GetPacket;
    while pkttype <> 0 do
    begin
      case pkttype of
        BADPKT, BLKPKT:
        begin
          if rstate = RRCVBLK then
          begin
            if (pkttype = BADPKT) or (rxBufLong^ <> Rxpos) then
            begin
              if pkttype = BLKPKT then
              begin
                if rxBufLong^ < last_blkpos then
                begin
                  rpos_retry := 0;
                  rpos_count := 0;
                end;
                last_blkpos := rxBufLong^;
              end;
              nowTime := DateTimeToUnix(Now);
              if nowTime > rpos_retry then
              begin
                Inc(rpos_count);
                if rpos_count = 1 then
                  rpos_sttime := nowTime;
                rxBufLong^ := Rxpos;
                PLongInt(@JRxBuffer[SizeOf(LongInt)])^ := rpos_sttime;
                SendJPacket(@JRxBuffer[0], Word(SizeOf(LongInt) + SizeOf(LongInt)), RPOSPKT);
                rpos_retry := nowTime + (TimeoutSecs div 2);
              end;
            end
            else
            begin
              { Good data block }
              last_blkpos := Rxpos;
              rpos_retry := 0;
              rpos_count := 0;
              Dec(Rxblklen, Word(SizeOf(LongInt)));
              FileWrite(RxFile, JRxBuffer[SizeOf(LongInt)], Rxblklen);
              Inc(Rxpos, Rxblklen);
              if Rxpos >= RxFilesize then
              begin
                FileClose(RxFile);
                RxFile := -1;
                nowTime := DateTimeToUnix(Now);
                if length_ = 0 then length_ := 1;
                length_ := nowTime - length_;
                if length_ = 0 then length_ := 1;
                if Log <> nil then
                begin
                  Log.Write('+CPS: %d (%d bytes)  Efficiency: %d%%',
                    [(Rxpos - rxstpos) div length_, Rxpos,
                     (((Rxpos - rxstpos) div length_) * 100) div LongInt(Speed div 10)]);
                  if CanCrc32 <> 0 then
                    Log.Write('+Received-J/32 %s', [UpperCase(RxFileName)])
                  else
                    Log.Write('+Received-J %s', [UpperCase(RxFileName)]);
                end;
                if (RxFiletime <> 0) and (RxFileName <> '') then
                  FileSetDate(RxFileName, DateTimeToFileDate(
                    UnixToDateTime(RxFiletime)));
                if RxQueue <> nil then
                  RxQueue.Add;
                rstate := RRCVFNAME;
              end;
            end;
          end;
          if rstate = RRCVFNAME then
            SendJPacket(nil, 0, EOFACKPKT);
        end;

        FNAMEPKT:
        begin
          if rstate = RRCVFNAME then
          begin
            Rxpos := ProcessFileName;
            rxstpos := Rxpos;
          end;
          rxBufLong^ := Rxpos;
          capByte := CANFREQ;
          if CanCrc32 <> 0 then
            capByte := capByte or CANCRC32;
          JRxBuffer[SizeOf(LongInt)] := capByte;
          SendJPacket(@JRxBuffer[0], Word(SizeOf(LongInt) + 1), FNACKPKT);
          if RxFileName <> '' then
            rstate := RRCVBLK
          else
            rstate := RDONE;
          length_ := DateTimeToUnix(Now);
        end;

        FNACKPKT:
        begin
          if xstate = XRCVFNACK then
          begin
            xmit_retry := 0;
            if TxFileName <> '' then
            begin
              capByte := 0;
              if Rxblklen > Word(SizeOf(LongInt)) then
                capByte := JRxBuffer[SizeOf(LongInt)];
              if (capByte and CANCRC32) <> 0 then
                CanCrc32 := 1;
              txpos := rxBufLong^;
              if txpos > -1 then
              begin
                if txpos <> 0 then
                begin
                  if Log <> nil then
                    Log.Write('+Synchronizing to offset %d', [txpos]);
                end;
                txstpos := txpos;

                { Open file for sending }
                try
                  fs := TFileStream.Create(TxFileName, fmOpenRead or fmShareDenyNone);
                  fs.Seek(txpos, soFromBeginning);
                except
                  fs := nil;
                end;
                xstate := XSENDBLK;
                txlength := DateTimeToUnix(Now);
              end
              else
              begin
                if Log <> nil then
                  Log.Write('+Remote refused %s', [TxFileName]);
                FreeAndNil(fs);
                if (TxQueue <> nil) and (IsOutbound = 0) then
                begin
                  TxQueue.DeleteAfter := False;
                  TxQueue.TruncateAfter := False;
                  TxQueue.Remove('');
                end;
                GetNextFile;
                xstate := XSENDFNAME;
              end;
            end
            else
              xstate := XDONE;
          end;
        end;

        RPOSPKT:
        begin
          if (xstate = XSENDBLK) or (xstate = XRCVEOFACK) then
          begin
            xmit_retry := 0;
            Com.ClearOutbound;
            txpos := rxBufLong^;
            if fs <> nil then
              fs.Seek(txpos, soFromBeginning);
            xstate := XSENDBLK;
          end;
        end;

        EOFACKPKT:
        begin
          if (xstate = XRCVEOFACK) or (xstate = XRCVFNACK) then
          begin
            if (xstate = XRCVEOFACK) and (fs <> nil) then
            begin
              FreeAndNil(fs);
              TxFile := -1;
              xmit_retry := 0;
              nowTime := DateTimeToUnix(Now);
              txlength := nowTime - txlength;
              if txlength = 0 then txlength := 1;
              if (TxQueue <> nil) and (IsOutbound = 0) and (Log <> nil) then
                Log.Write('+CPS: %d (%d bytes)  Efficiency: %d%%',
                  [(TxQueue.Size - LongWord(txstpos)) div LongWord(txlength), TxQueue.Size,
                   (((TxQueue.Size - LongWord(txstpos)) div LongWord(txlength)) * 100) div (Speed div 10)]);
              if Log <> nil then
              begin
                if CanCrc32 <> 0 then
                  Log.Write('+Sent-J/32 %s', [UpperCase(TxFileName)])
                else
                  Log.Write('+Sent-J %s', [UpperCase(TxFileName)]);
              end;
              if (TxQueue <> nil) and (IsOutbound = 0) then
                TxQueue.Remove('');
              GetNextFile;
            end;
            xstate := XSENDFNAME;
          end;
        end;

        FREQPKT:
        begin
          if xstate = XRCVFNACK then
          begin
            xmit_retry := 0;
            SharedCap := PByte(StrEnd(PChar(@JRxBuffer[0])) + 1)^;
            xstate := XSENDFREQNAK;
          end;
        end;

        HALTPKT_J:
        begin
          SendJPacket(nil, 0, HALTACKPKT);
          xstate := XDONE;
          rstate := RDONE;
        end;
      end; { case pkttype }

      if (pkttype = HALTPKT_J) or ((xstate = XDONE) and (rstate = RDONE)) then
        Break;

      pkttype := GetPacket;
    end; { while pkttype }
  until ((xstate = XDONE) and (rstate = RDONE)) or (Com.Carrier = 0);

  { Cleanup }
  if RxFile <> -1 then
    FileClose(RxFile);
  FreeAndNil(fs);

  { Send halt acknowledgment }
  if Com.Carrier <> 0 then
  begin
    SendJPacket(nil, 0, HALTACKPKT);
    SendJPacket(nil, 0, HALTACKPKT);
    SendJPacket(nil, 0, HALTACKPKT);
    SendJPacket(nil, 0, HALTACKPKT);
    SendJPacket(nil, 0, HALTACKPKT);
  end;
end;
