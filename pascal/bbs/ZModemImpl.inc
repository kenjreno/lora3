{ ======================================================================
  TZModem constructor / destructor
  ====================================================================== }

constructor TZModem.Create;
begin
  inherited Create;
  Com := nil;
  Log := nil;
  Progress := nil;
  EndRun := 0;
  Hangup := 0;
  FileSent := 0;
  Wantfcs32 := 1;
  Txfcs32 := 0;
  ZCtlesc := 0;
  Znulls := 0;
  LastSent_ := -1;
  Rxtimeout := 200;
  Tframlen := 1024;
  TryZHdrType := ZRINIT;
  Maxblklen := 1024;
  RxTempSize := 0;
  Telnet := 0;
  Speed := 0;
  Pathname := '';
  TxBuffer := @ZRxBuffer[0];
  FillChar(Txhdr, SizeOf(Txhdr), 0);
  FillChar(Rxhdr, SizeOf(Rxhdr), 0);
  FillChar(Attn, SizeOf(Attn), 0);
  FillChar(ZRxBuffer, SizeOf(ZRxBuffer), 0);
  FillChar(RxTemp, SizeOf(RxTemp), 0);
  RxTempPos := nil;
  Rxframeind := 0;
  Rxtype := 0;
  Rxflags := 0;
  Rxbuflen := 0;
  Rxcount := 0;
  Rxpos := 0;
  Txpos := 0;
  Rxbytes := 0;
end;

destructor TZModem.Destroy;
begin
  { TxBuffer points into ZRxBuffer, so don't free it }
  TxBuffer := nil;
  inherited Destroy;
end;

{ ======================================================================
  AbortSession - check if session should be aborted
  ====================================================================== }

function TZModem.AbortSession: Boolean;
begin
  Result := False;
  if (EndRun <> 0) or (Hangup <> 0) then
    Result := True
  else if (Com <> nil) and (Com.Carrier = 0) then
    Result := True;
end;

{ ======================================================================
  TimedRead - read a byte with timeout (hSec in hundredths of second)
  ====================================================================== }

function TZModem.TimedRead(hSec: LongInt): SmallInt;
var
  tout: LongInt;
begin
  Result := -1;
  if Com.BytesReady = 0 then
  begin
    tout := TimerSet(hSec);
    repeat
      if Com.BytesReady <> 0 then
      begin
        Result := SmallInt(Com.ReadByte);
        Exit;
      end;
    until (TimeUp(tout) <> 0) or AbortSession;
  end
  else
    Result := SmallInt(Com.ReadByte);
end;

{ ======================================================================
  ZAckBiBi - end session acknowledgment
  ====================================================================== }

procedure TZModem.ZAckBiBi;
var
  n: Integer;
  c: SmallInt;
begin
  ZPutLong(Txhdr, 0);

  n := 4;
  while (n > 0) and (not AbortSession) do
  begin
    Dec(n);
    ZSendHexHeader(ZFIN, Txhdr);
    c := TimedRead(100);
    case c of
      Ord('O'):
      begin
        TimedRead(1);
        Exit;
      end;
      Z_TIMEOUT, Z_RCDO:
        Exit;
    end;
  end;
end;

{ ======================================================================
  ZDLRead - read a ZDLE-escaped byte
  ====================================================================== }

function TZModem.ZDLRead: SmallInt;
var
  c: SmallInt;
begin
  c := TimedRead(SmallInt(Rxtimeout));
  if c <> ZDLE then
  begin
    Result := c;
    Exit;
  end;

  c := TimedRead(SmallInt(Rxtimeout));
  if c < 0 then
  begin
    Result := c;
    Exit;
  end;

  { Handle up to 4 consecutive CANs }
  if c = CTRL_X then
  begin
    c := TimedRead(SmallInt(Rxtimeout));
    if c < 0 then begin Result := c; Exit; end;
  end;
  if c = CTRL_X then
  begin
    c := TimedRead(SmallInt(Rxtimeout));
    if c < 0 then begin Result := c; Exit; end;
  end;
  if c = CTRL_X then
  begin
    c := TimedRead(SmallInt(Rxtimeout));
    if c < 0 then begin Result := c; Exit; end;
  end;

  case c of
    CTRL_X:
      Result := GOTCAN;
    ZCRCE, ZCRCG, ZCRCQ, ZCRCW:
      Result := SmallInt(c or GOTOR);
    ZRUB0:
      Result := $7F;
    ZRUB1:
      Result := $FF;
  else
    if (c and $60) = $40 then
      Result := SmallInt(c xor $40)
    else
      Result := Z_ERROR;
  end;
end;

{ ======================================================================
  ZGetLong - extract a 32-bit value from a header
  ====================================================================== }

function TZModem.ZGetLong(var hdr): LongInt;
var
  h: array[0..3] of Byte absolute hdr;
  l: LongInt;
begin
  l := h[ZP3] and $FF;
  l := (l shl 8) or (h[ZP2] and $FF);
  l := (l shl 8) or (h[ZP1] and $FF);
  l := (l shl 8) or (h[ZP0] and $FF);
  Result := l;
end;

{ ======================================================================
  ZReceiveData - receive Zmodem data subpacket
  ====================================================================== }

function TZModem.ZReceiveData(buf: PByte; length: SmallInt): SmallInt;
var
  d, c: SmallInt;
  pos: SmallInt;
  crc16: Word;
  crc32: LongWord;
  GotFrame: Boolean;
begin
  Rxcount := 0;
  pos := 0;
  GotFrame := False;

  if Rxframeind = ZBIN32 then
  begin
    crc32 := $FFFFFFFF;
    while pos <= length do
    begin
      c := ZDLRead;
      if (c and (not $FF)) <> 0 then
      begin
        { Process frame end or error }
        repeat
          GotFrame := True;
          case c of
            GOTCRCE, GOTCRCG, GOTCRCQ, GOTCRCW:
            begin
              d := c;
              crc32 := Crc32(Byte(c and $FF), crc32);
              c := ZDLRead;
              if (c and (not $FF)) <> 0 then begin GotFrame := False; Continue; end;
              crc32 := Crc32(Byte(c), crc32);
              c := ZDLRead;
              if (c and (not $FF)) <> 0 then begin GotFrame := False; Continue; end;
              crc32 := Crc32(Byte(c), crc32);
              c := ZDLRead;
              if (c and (not $FF)) <> 0 then begin GotFrame := False; Continue; end;
              crc32 := Crc32(Byte(c), crc32);
              c := ZDLRead;
              if (c and (not $FF)) <> 0 then begin GotFrame := False; Continue; end;
              crc32 := Crc32(Byte(c), crc32);
              if crc32 <> $DEBB20E3 then
              begin
                Result := Z_ERROR;
                Exit;
              end;
              Result := d;
              Exit;
            end;
            GOTCAN:
            begin
              Result := ZCAN;
              Exit;
            end;
          else
            begin
              Result := c;
              Exit;
            end;
          end;
        until GotFrame;
      end;
      Inc(Rxcount);
      if pos < length then
        buf[pos] := Byte(c);
      Inc(pos);
      crc32 := Crc32(Byte(c), crc32);
    end;
  end
  else
  begin
    crc16 := 0;
    while pos <= length do
    begin
      c := ZDLRead;
      if (c and (not $FF)) <> 0 then
      begin
        repeat
          GotFrame := True;
          case c of
            GOTCRCE, GOTCRCG, GOTCRCQ, GOTCRCW:
            begin
              d := c;
              crc16 := Crc16(Byte(c and $FF), crc16);
              c := ZDLRead;
              if (c and (not $FF)) <> 0 then begin GotFrame := False; Continue; end;
              crc16 := Crc16(Byte(c), crc16);
              c := ZDLRead;
              if (c and (not $FF)) <> 0 then begin GotFrame := False; Continue; end;
              crc16 := Crc16(Byte(c), crc16);
              if (crc16 and $FFFF) <> 0 then
              begin
                Result := Z_ERROR;
                Exit;
              end;
              Result := d;
              Exit;
            end;
            GOTCAN:
            begin
              Result := ZCAN;
              Exit;
            end;
          else
            begin
              Result := c;
              Exit;
            end;
          end;
        until GotFrame;
      end;
      Inc(Rxcount);
      if pos < length then
        buf[pos] := Byte(c);
      Inc(pos);
      crc16 := Crc16(Byte(c), crc16);
    end;
  end;

  Result := Z_ERROR;
end;

{ ======================================================================
  ZSendLine - send a byte with ZDLE escaping
  ====================================================================== }

procedure TZModem.ZSendLine(c: Byte);
begin
  case c of
    $7F:  { DEL }
    begin
      if Telnet <> 0 then
      begin
        Com.BufferByte(ZDLE);
        LastSent_ := ZRUB0;
        Com.BufferByte(Byte(ZRUB0));
      end
      else
      begin
        LastSent_ := c;
        Com.BufferByte(c);
      end;
    end;

    $FF:  { rubout 0377 }
    begin
      if Telnet <> 0 then
      begin
        Com.BufferByte(ZDLE);
        LastSent_ := ZRUB1;
        Com.BufferByte(Byte(ZRUB1));
      end
      else
      begin
        LastSent_ := c;
        Com.BufferByte(c);
      end;
    end;

    $0D, $8D:  { CR variants }
    begin
      if (ZCtlesc = 0) and ((LastSent_ and $7F) <> Ord('@')) then
      begin
        { Send without escaping }
        LastSent_ := c;
        Com.BufferByte(c);
      end
      else
      begin
        { Escape it }
        Com.BufferByte(ZDLE);
        c := c xor $40;
        LastSent_ := c;
        Com.BufferByte(c);
      end;
    end;

    $10, $11, $13,       { DLE, XON, XOFF }
    $90, $91, $93,       { High-bit variants }
    ZDLE:
    begin
      Com.BufferByte(ZDLE);
      c := c xor $40;
      LastSent_ := c;
      Com.BufferByte(c);
    end;
  else
    LastSent_ := c;
    Com.BufferByte(c);
  end;
end;

{ ======================================================================
  ZSendBinaryHeader - send a binary header with CRC
  ====================================================================== }

procedure TZModem.ZSendBinaryHeader(ftype: SmallInt; var hdr);
var
  h: array[0..3] of Byte absolute hdr;
  n: SmallInt;
  crc16: Word;
  crc32: LongWord;
begin
  if not AbortSession then
  begin
    if ftype = ZDATA then
    begin
      n := Znulls;
      while n > 0 do
      begin
        Com.BufferByte(0);
        Dec(n);
      end;
    end;

    Com.BufferByte(ZPAD);
    Com.BufferByte(ZDLE);

    if Txfcs32 <> 0 then
    begin
      Com.BufferByte(ZBIN32);
      ZSendLine(Byte(ftype));
      crc32 := Crc32(Byte(ftype), $FFFFFFFF);

      for n := 0 to 3 do
      begin
        ZSendLine(h[n]);
        crc32 := Crc32(h[n], crc32);
      end;
      crc32 := not crc32;
      for n := 0 to 3 do
      begin
        ZSendLine(Byte(crc32));
        crc32 := crc32 shr 8;
      end;
    end
    else
    begin
      Com.BufferByte(ZBIN);
      ZSendLine(Byte(ftype));
      crc16 := Crc16(Byte(ftype), 0);

      for n := 0 to 3 do
      begin
        ZSendLine(h[n]);
        crc16 := Crc16(h[n], crc16);
      end;
      ZSendLine(Byte(crc16 shr 8));
      ZSendLine(Byte(crc16));
    end;

    Com.UnbufferBytes;
  end;
end;

{ ======================================================================
  ZSendData - send data subpacket with CRC and frame end
  ====================================================================== }

procedure TZModem.ZSendData(buf: PByte; length: SmallInt; frameend: SmallInt);
var
  i, n: SmallInt;
  crc16: Word;
  crc32: LongWord;
begin
  if not AbortSession then
  begin
    if Txfcs32 <> 0 then
    begin
      crc32 := $FFFFFFFF;
      for i := 0 to length - 1 do
      begin
        ZSendLine(buf[i]);
        crc32 := Crc32(buf[i], crc32);
      end;
      Com.BufferByte(ZDLE);
      Com.BufferByte(Byte(frameend));
      crc32 := Crc32(Byte(frameend), crc32);
      crc32 := not crc32;
      for n := 0 to 3 do
      begin
        ZSendLine(Byte(crc32));
        crc32 := crc32 shr 8;
      end;
      Com.UnbufferBytes;
    end
    else
    begin
      crc16 := 0;
      for i := 0 to length - 1 do
      begin
        ZSendLine(buf[i]);
        crc16 := Crc16(buf[i], crc16);
      end;
      Com.BufferByte(ZDLE);
      Com.BufferByte(Byte(frameend));
      crc16 := Crc16(Byte(frameend), crc16);
      ZSendLine(Byte(crc16 shr 8));
      ZSendLine(Byte(crc16 and $FF));
      Com.UnbufferBytes;
    end;
  end;
end;

{ ======================================================================
  ZGetByte - get a byte, filtering XON/XOFF
  ====================================================================== }

function TZModem.ZGetByte: SmallInt;
var
  c: SmallInt;
begin
  while not AbortSession do
  begin
    c := TimedRead(SmallInt(Rxtimeout));
    if c < 0 then
    begin
      Result := Z_TIMEOUT;
      Exit;
    end;
    c := c and $7F;
    case c of
      XON, XOFF: ; { skip }
    else
      begin
        Result := c;
        Exit;
      end;
    end;
  end;
  Result := Z_RCDO;
end;

{ ======================================================================
  ZGetHex - decode two hex digits
  ====================================================================== }

function TZModem.ZGetHex: SmallInt;
var
  c, n: SmallInt;
begin
  c := ZGetByte;
  if c < 0 then begin Result := c; Exit; end;

  n := c - Ord('0');
  if n > 9 then
    Dec(n, Ord('a') - Ord(':'));
  if (n and (not $F)) <> 0 then
  begin
    Result := Z_ERROR;
    Exit;
  end;

  c := ZGetByte;
  if c < 0 then begin Result := c; Exit; end;

  Dec(c, Ord('0'));
  if c > 9 then
    Dec(c, Ord('a') - Ord(':'));
  if (c and (not $F)) <> 0 then
  begin
    Result := Z_ERROR;
    Exit;
  end;

  Result := c + (n shl 4);
end;

{ ======================================================================
  ZReceiveHexHeader
  ====================================================================== }

function TZModem.ZReceiveHexHeader(var hdr): SmallInt;
var
  h: array[0..3] of Byte absolute hdr;
  n, c: SmallInt;
  crc: Word;
begin
  c := ZGetHex;
  if c < 0 then begin Result := c; Exit; end;
  Rxtype := c;
  crc := Crc16(Byte(c), 0);

  for n := 0 to 3 do
  begin
    c := ZGetHex;
    if c < 0 then begin Result := c; Exit; end;
    crc := Crc16(Byte(c), crc);
    h[n] := Byte(c);
  end;

  c := ZGetHex;
  if c < 0 then begin Result := c; Exit; end;
  crc := Crc16(Byte(c), crc);

  c := ZGetHex;
  if c < 0 then begin Result := c; Exit; end;
  crc := Crc16(Byte(c), crc);

  if (crc and $FFFF) <> 0 then
  begin
    Result := Z_ERROR;
    Exit;
  end;

  if TimedRead(20) = $0D then  { Throw away possible CR/LF }
    TimedRead(20);

  Result := Rxtype;
end;

{ ======================================================================
  ZReceiveBinaryHeader - 16-bit CRC
  ====================================================================== }

function TZModem.ZReceiveBinaryHeader(var hdr): SmallInt;
var
  h: array[0..3] of Byte absolute hdr;
  c, n: SmallInt;
  crc: Word;
begin
  c := ZDLRead;
  if (c and (not $FF)) <> 0 then begin Result := c; Exit; end;
  Rxtype := c;
  crc := Crc16(Byte(c), 0);

  for n := 0 to 3 do
  begin
    c := ZDLRead;
    if (c and (not $FF)) <> 0 then begin Result := c; Exit; end;
    crc := Crc16(Byte(c), crc);
    h[n] := Byte(c);
  end;

  c := ZDLRead;
  if (c and (not $FF)) <> 0 then begin Result := c; Exit; end;
  crc := Crc16(Byte(c), crc);

  c := ZDLRead;
  if (c and (not $FF)) <> 0 then begin Result := c; Exit; end;
  crc := Crc16(Byte(c), crc);

  if (crc and $FFFF) <> 0 then
  begin
    Result := Z_ERROR;
    Exit;
  end;

  Result := Rxtype;
end;

{ ======================================================================
  ZReceiveBinaryHeader32 - 32-bit CRC
  ====================================================================== }

function TZModem.ZReceiveBinaryHeader32(var hdr): SmallInt;
var
  h: array[0..3] of Byte absolute hdr;
  c, n: SmallInt;
  crc: LongWord;
begin
  c := ZDLRead;
  if (c and (not $FF)) <> 0 then begin Result := c; Exit; end;
  Rxtype := c;
  crc := Crc32(Byte(c), $FFFFFFFF);

  for n := 0 to 3 do
  begin
    c := ZDLRead;
    if (c and (not $FF)) <> 0 then begin Result := c; Exit; end;
    crc := Crc32(Byte(c), crc);
    h[n] := Byte(c);
  end;

  for n := 0 to 3 do
  begin
    c := ZDLRead;
    if (c and (not $FF)) <> 0 then begin Result := c; Exit; end;
    crc := Crc32(Byte(c), crc);
  end;

  if crc <> $DEBB20E3 then
  begin
    Result := Z_ERROR;
    Exit;
  end;

  Result := Rxtype;
end;

{ ======================================================================
  ZGetHeader - receive any style header
  State machine replacing the C goto-based logic
  ====================================================================== }

function TZModem.ZGetHeader(var hdr): SmallInt;
var
  h: array[0..3] of Byte absolute hdr;
  c: SmallInt;
  n, cancount: SmallInt;
  State: (stAgain, stSplat, stDecide, stDone);
begin
  n := 2400;
  cancount := 5;
  Rxframeind := 0;
  Rxtype := 0;
  c := 0;
  State := stAgain;

  while State <> stDone do
  begin
    case State of
      stAgain:
      begin
        Rxframeind := 0;
        Rxtype := 0;
        c := ZGetByte;
        case c of
          Z_RCDO, Z_TIMEOUT:
            State := stDone;
          CTRL_X:  { CAN }
          begin
            Dec(cancount);
            if cancount <= 0 then
            begin
              c := ZCAN;
              State := stDone;
            end
            else
            begin
              Dec(n);
              if n = 0 then begin Result := Z_ERROR; Exit; end;
              { cancount already decremented, stay in stAgain }
            end;
          end;
          ZPAD:
          begin
            cancount := 5;
            State := stSplat;
          end;
        else
          begin
            Dec(n);
            if n = 0 then begin Result := Z_ERROR; Exit; end;
            if c <> CTRL_X then
              cancount := 5;
            { stay in stAgain }
          end;
        end;
      end;

      stSplat:
      begin
        c := ZGetByte;
        case c of
          ZPAD:
            ; { stay in stSplat }
          Z_RCDO, Z_TIMEOUT:
            State := stDone;
          ZDLE:
            State := stDecide;
        else
          begin
            { go to agn2 equivalent }
            Dec(n);
            if n = 0 then begin Result := Z_ERROR; Exit; end;
            if c <> CTRL_X then
              cancount := 5;
            State := stAgain;
          end;
        end;
      end;

      stDecide:
      begin
        c := ZGetByte;
        case c of
          Z_RCDO, Z_TIMEOUT:
            State := stDone;
          ZBIN:
          begin
            Rxframeind := ZBIN;
            c := ZReceiveBinaryHeader(hdr);
            State := stDone;
          end;
          ZBIN32:
          begin
            Rxframeind := ZBIN32;
            c := ZReceiveBinaryHeader32(hdr);
            State := stDone;
          end;
          ZHEX:
          begin
            Rxframeind := ZHEX;
            c := ZReceiveHexHeader(hdr);
            State := stDone;
          end;
          CTRL_X:  { CAN }
          begin
            Dec(cancount);
            if cancount <= 0 then
            begin
              c := ZCAN;
              State := stDone;
            end
            else
            begin
              Dec(n);
              if n = 0 then begin Result := Z_ERROR; Exit; end;
              State := stAgain;
            end;
          end;
        else
          begin
            Dec(n);
            if n = 0 then begin Result := Z_ERROR; Exit; end;
            if c <> CTRL_X then
              cancount := 5;
            State := stAgain;
          end;
        end;
      end;

      stDone: ; { handled by while condition }
    end; { case State }
  end;

  { Extract position from header }
  Rxpos := h[ZP3] and $FF;
  Rxpos := (Rxpos shl 8) + (h[ZP2] and $FF);
  Rxpos := (Rxpos shl 8) + (h[ZP1] and $FF);
  Rxpos := (Rxpos shl 8) + (h[ZP0] and $FF);

  if c = GOTCAN then
    c := ZCAN;

  Result := c;
end;

{ ======================================================================
  ZPutHex - send a byte as two hex digits
  ====================================================================== }

procedure TZModem.ZPutHex(c: SmallInt);
const
  HexDigits: array[0..15] of Byte =
    (Ord('0'),Ord('1'),Ord('2'),Ord('3'),Ord('4'),Ord('5'),Ord('6'),Ord('7'),
     Ord('8'),Ord('9'),Ord('a'),Ord('b'),Ord('c'),Ord('d'),Ord('e'),Ord('f'));
begin
  Com.BufferByte(HexDigits[(c and $F0) shr 4]);
  Com.BufferByte(HexDigits[c and $0F]);
end;

{ ======================================================================
  ZSendHexHeader
  ====================================================================== }

procedure TZModem.ZSendHexHeader(ftype: SmallInt; var hdr);
var
  h: array[0..3] of Byte absolute hdr;
  n: SmallInt;
  crc: Word;
begin
  if not AbortSession then
  begin
    Com.BufferByte(ZPAD);
    Com.BufferByte(ZPAD);
    Com.BufferByte(ZDLE);
    Com.BufferByte(ZHEX);
    ZPutHex(ftype);

    crc := Crc16(Byte(ftype), 0);
    for n := 0 to 3 do
    begin
      ZPutHex(h[n]);
      crc := Crc16(Byte(h[n] and $FF), crc);
    end;
    ZPutHex(SmallInt(crc shr 8));
    ZPutHex(SmallInt(crc));

    Com.BufferByte($0D);  { CR }
    Com.BufferByte($0A);  { LF }

    if ftype <> ZFIN then
      Com.BufferByte($11);  { XON }

    Com.UnbufferBytes;
  end;
end;

{ ======================================================================
  ZPutLong - store a 32-bit position into header bytes
  ====================================================================== }

procedure TZModem.ZPutLong(var hdr; pos: LongInt);
var
  h: array[0..3] of Byte absolute hdr;
begin
  h[ZP0] := Byte(pos);
  h[ZP1] := Byte(pos shr 8);
  h[ZP2] := Byte(pos shr 16);
  h[ZP3] := Byte(pos shr 24);
end;

{ ======================================================================
  ZInitReceiver - initialize Zmodem receive session
  ====================================================================== }

function TZModem.ZInitReceiver: SmallInt;
var
  n, errors: SmallInt;
  c: SmallInt;
begin
  FileSent := 0;
  Txfcs32 := 1;
  errors := 0;
  Com.ClearInbound;
  RxTempSize := 0;

  n := 10;
  while (n > 0) and (not AbortSession) do
  begin
    Dec(n);
    ZPutLong(Txhdr, 0);
    Txhdr[ZF0] := CANFC32 or CANFDX or CANOVIO;
    ZSendHexHeader(TryZHdrType, Txhdr);

    { Inner loop for "goto again" pattern }
    while True do
    begin
      c := ZGetHeader(Rxhdr);
      case c of
        ZRQINIT:
          Break;  { back to outer loop }

        ZFILE:
        begin
          TryZHdrType := ZRINIT;
          if ZReceiveData(@ZRxBuffer[0], KSIZE) = GOTCRCW then
          begin
            Result := ZFILE;
            Exit;
          end;
          ZSendHexHeader(ZNAK, Txhdr);
          Continue;
        end;

        ZSINIT:
        begin
          if ZReceiveData(@Attn[0], ZATTNLEN) = GOTCRCW then
          begin
            ZPutLong(Txhdr, 1);
            ZSendHexHeader(ZACK, Txhdr);
          end
          else
            ZSendHexHeader(ZNAK, Txhdr);
          Continue;
        end;

        ZFREECNT:
        begin
          ZPutLong(Txhdr, LongInt($FFFFFFFF));
          ZSendHexHeader(ZACK, Txhdr);
          Continue;
        end;

        ZCOMMAND:
        begin
          if ZReceiveData(@ZRxBuffer[0], KSIZE) = GOTCRCW then
          begin
            ZPutLong(Txhdr, 0);
            repeat
              ZSendHexHeader(ZCOMPL, Txhdr);
              Inc(errors);
            until (errors >= 10) or (ZGetHeader(Rxhdr) = ZFIN);
            ZAckBiBi;
            Result := ZCOMPL;
            Exit;
          end
          else
            ZSendHexHeader(ZNAK, Txhdr);
          Continue;
        end;

        ZCOMPL:
          Continue;

        ZFIN:
        begin
          ZAckBiBi;
          Result := ZCOMPL;
          Exit;
        end;

        Z_RCDO, ZCAN:
        begin
          Result := Z_ERROR;
          Exit;
        end;
      else
        Break;  { back to outer loop }
      end;
    end; { inner while }
  end; { outer for }

  Result := Z_OK;
end;

{ ======================================================================
  ZInitSender - initialize Zmodem send session
  ====================================================================== }

function TZModem.ZInitSender(NothingToDo: Boolean): SmallInt;
var
  i: SmallInt;
  c: SmallInt;
  RzStr: array[0..3] of Byte;
begin
  if (not NothingToDo) and (FileSent = 0) then
  begin
    RzStr[0] := Ord('r');
    RzStr[1] := Ord('z');
    RzStr[2] := $0D;
    Com.SendBytes(@RzStr[0], 3);
    ZPutLong(Txhdr, 0);
    ZSendHexHeader(ZRQINIT, Txhdr);
  end;

  if NothingToDo or ((not NothingToDo) and (FileSent = 0)) then
  begin
    for i := 0 to 9 do
    begin
      if AbortSession then Break;

      c := ZGetHeader(Rxhdr);
      case c of
        ZCHALLENGE:
        begin
          ZPutLong(Txhdr, Rxpos);
          ZSendHexHeader(ZACK, Txhdr);
        end;

        ZCOMMAND:
        begin
          ZPutLong(Txhdr, 0);
          ZSendHexHeader(ZRQINIT, Txhdr);
        end;

        ZRINIT:
        begin
          Rxflags := SmallInt($FF and Rxhdr[ZF0]);
          if (Wantfcs32 <> 0) and ((Rxflags and CANFC32) <> 0) then
            Txfcs32 := 1;
          Rxbuflen := SmallInt(($FF and Rxhdr[ZP0]) + (($FF and Rxhdr[ZP1]) shl 8));
          if (Rxbuflen < 32) or (Rxbuflen > 1024) then
            Rxbuflen := 1024;
          if (Rxbuflen <> 0) and (Rxbuflen > Tframlen) and (Tframlen >= 32) then
            Rxbuflen := Tframlen;
          if (Rxbuflen = 0) and (Tframlen >= 32) and (Tframlen <= 1024) then
            Rxbuflen := Tframlen;
          Result := Z_OK;
          Exit;
        end;

        Z_RCDO, ZCAN, Z_TIMEOUT:
        begin
          Result := Z_ERROR;
          Exit;
        end;

        ZRQINIT:
        begin
          if Rxhdr[ZF0] = ZCOMMAND then
            Continue;
          ZSendHexHeader(ZNAK, Txhdr);
        end;
      else
        ZSendHexHeader(ZNAK, Txhdr);
      end;
    end;

    Result := Z_ERROR;
    Exit;
  end;

  Result := Z_OK;
end;

{ ======================================================================
  ZReceiveFile - receive a file via Zmodem
  ====================================================================== }

function TZModem.ZReceiveFile(const Path: String): SmallInt;
var
  fout: TFileStream;
  c, n: SmallInt;
  gota: Boolean;
  p, q: PChar;
  fileinfo: PChar;
  NameStr, PathBuf: String;
  filesize, filetime, starttime: LongInt;
  existSize, existTime: LongInt;
  SR: TSearchRec;
  ch: Char;
  i: Integer;

  procedure CloseAndSetTime;
  begin
    if fout <> nil then
    begin
      FreeAndNil(fout);
      if filetime <> 0 then
        FileSetDate(Pathname, DateTimeToFileDate(
          UnixToDateTime(filetime)));
    end;
  end;

  procedure EndProgress;
  begin
    if Progress <> nil then
      Progress.EndTransfer;
  end;

begin
  { Extract filename from ZRxBuffer (strip path) }
  p := PChar(@ZRxBuffer[0]);
  q := p;
  while p^ <> #0 do
  begin
    if (p^ = '/') or (p^ = '\') or (p^ = ':') then
      q := p + 1;
    Inc(p);
  end;

  NameStr := LowerCase(StrPas(q));
  Pathname := IncludeTrailingPathDelimiter(Path) + NameStr;

  { Parse file info (size and timestamp) }
  filesize := 0;
  filetime := 0;
  fileinfo := PChar(@ZRxBuffer[0]) + StrLen(PChar(@ZRxBuffer[0])) + 1;
  if fileinfo^ <> #0 then
  begin
    PathBuf := StrPas(fileinfo);
    i := Pos(' ', PathBuf);
    if i > 0 then
    begin
      filesize := StrToIntDef(Copy(PathBuf, 1, i - 1), 0);
      { Octal timestamp }
      filetime := 0;
      for i := i + 1 to Length(PathBuf) do
      begin
        ch := PathBuf[i];
        if (ch >= '0') and (ch <= '7') then
          filetime := filetime * 8 + (Ord(ch) - Ord('0'))
        else
          Break;
      end;
    end
    else
      filesize := StrToIntDef(PathBuf, 0);
  end;

  if Log <> nil then
    Log.Write(' Receiving %s; %db, %d min.',
      [NameStr, filesize, (filesize * 10 div LongInt(Speed) + 53) div 54]);

  Rxbytes := 0;
  fout := nil;

  { Check if file already exists }
  if FileExists(Pathname) then
  begin
    existSize := 0;
    existTime := 0;
    if FindFirst(Pathname, faAnyFile, SR) = 0 then
    begin
      existSize := SR.Size;
      existTime := FileAge(Pathname);
      if existTime > 0 then
        existTime := DateTimeToUnix(FileDateToDateTime(existTime));
      FindClose(SR);
    end;

    if (filesize = existSize) and (filetime = existTime) then
    begin
      if Log <> nil then
        Log.Write('+Already have %s', [Pathname]);
      ZSendHexHeader(ZSKIP, Txhdr);
      Result := ZEOF;
      Exit;
    end
    else if filesize > existSize then
    begin
      Rxbytes := existSize;
      if Log <> nil then
        Log.Write('+Synchronizing to offset %d', [Rxbytes]);
    end
    else
    begin
      { Rename duplicate: increment last character of filename }
      i := Length(Pathname);
      gota := False;
      repeat
        ch := Pathname[i];
        if (ch >= '0') and (ch <= '9') or gota then
        begin
          if ch = '9' then
          begin
            gota := True;
            Pathname[i] := 'A';
          end
          else
            Pathname[i] := Chr(Ord(ch) + 1);
        end
        else
          Pathname[i] := '0';
      until not FileExists(Pathname);
      if Log <> nil then
        Log.Write('+Renaming dupe file %s', [Pathname]);
    end;
  end;

  { Set up progress }
  if Progress <> nil then
  begin
    Progress.ProgressType := FILE_RECEIVING;
    Progress.RxFileName := NameStr;
    Progress.RxBlockSize := 0;
    Progress.RxSize := filesize;
    Progress.BeginTransfer;
    Progress.RxPosition := Rxbytes;
    Progress.Update;
  end;

  n := 10;
  starttime := DateTimeToUnix(Now);

  { Open file for append }
  try
    if FileExists(Pathname) and (Rxbytes > 0) then
    begin
      fout := TFileStream.Create(Pathname, fmOpenReadWrite or fmShareDenyNone);
      fout.Seek(0, soFromEnd);
    end
    else
      fout := TFileStream.Create(Pathname, fmCreate);
  except
    EndProgress;
    Result := Z_ERROR;
    Exit;
  end;

  try
    while not AbortSession do
    begin
      ZPutLong(Txhdr, Rxbytes);
      ZSendBinaryHeader(ZRPOS, Txhdr);

      { nxthdr: }
      while True do
      begin
        c := ZGetHeader(Rxhdr);
        case c of
          ZNAK, Z_TIMEOUT:
          begin
            Dec(n);
            if n < 0 then
            begin
              CloseAndSetTime;
              EndProgress;
              Result := Z_ERROR;
              Exit;
            end;
            Break; { back to outer while for ZRPOS }
          end;

          ZFILE:
          begin
            ZReceiveData(@ZRxBuffer[0], KSIZE);
            Continue;
          end;

          ZEOF:
          begin
            if ZGetLong(Rxhdr) <> Rxbytes then
              Continue;
            EndProgress;
            CloseAndSetTime;
            starttime := DateTimeToUnix(Now) - starttime;
            if starttime = 0 then Inc(starttime);
            if Log <> nil then
            begin
              Log.Write('+CPS: %d (%d bytes)  Efficiency: %d%%',
                [Rxbytes div starttime, Rxbytes,
                 ((Rxbytes div starttime) * 100) div LongInt(Speed div 10)]);
              if Txfcs32 <> 0 then
                Log.Write('+Received-Z/32 %s', [UpperCase(Pathname)])
              else
                Log.Write('+Received-Z %s', [UpperCase(Pathname)]);
            end;
            Result := c;
            Exit;
          end;

          Z_ERROR:
          begin
            Dec(n);
            if n < 0 then
            begin
              CloseAndSetTime;
              EndProgress;
              Result := Z_ERROR;
              Exit;
            end;
            if StrLen(PChar(@Attn[0])) > 0 then
              Com.SendBytes(@Attn[0], Word(StrLen(PChar(@Attn[0]))));
            Continue;
          end;

          ZDATA:
          begin
            if ZGetLong(Rxhdr) <> Rxbytes then
            begin
              Dec(n);
              if n < 0 then
              begin
                CloseAndSetTime;
                EndProgress;
                Result := Z_ERROR;
                Exit;
              end;
              if StrLen(PChar(@Attn[0])) > 0 then
                Com.SendBytes(@Attn[0], Word(StrLen(PChar(@Attn[0]))));
              Continue;
            end;

            { moredata: }
            while True do
            begin
              c := ZReceiveData(@ZRxBuffer[0], KSIZE);
              case c of
                ZCAN:
                begin
                  CloseAndSetTime;
                  EndProgress;
                  Result := Z_ERROR;
                  Exit;
                end;

                Z_ERROR:
                begin
                  Dec(n);
                  if n < 0 then
                  begin
                    CloseAndSetTime;
                    EndProgress;
                    Result := Z_ERROR;
                    Exit;
                  end;
                  if StrLen(PChar(@Attn[0])) > 0 then
                    Com.SendBytes(@Attn[0], Word(StrLen(PChar(@Attn[0]))));
                  Continue;
                end;

                Z_TIMEOUT:
                begin
                  Dec(n);
                  if n < 0 then
                  begin
                    CloseAndSetTime;
                    EndProgress;
                    Result := Z_ERROR;
                    Exit;
                  end;
                  Continue;
                end;

                GOTCRCW:
                begin
                  n := 10;
                  if Rxcount > 0 then
                    fout.Write(ZRxBuffer[0], Rxcount);
                  Inc(Rxbytes, Rxcount);
                  ZPutLong(Txhdr, Rxbytes);
                  ZSendBinaryHeader(ZACK, Txhdr);
                  if Progress <> nil then
                  begin
                    Progress.RxPosition := Rxbytes;
                    Progress.RxBlockSize := Rxcount;
                    Progress.Update;
                  end;
                  Break; { back to nxthdr }
                end;

                GOTCRCQ:
                begin
                  n := 10;
                  if Rxcount > 0 then
                    fout.Write(ZRxBuffer[0], Rxcount);
                  Inc(Rxbytes, Rxcount);
                  ZPutLong(Txhdr, Rxbytes);
                  ZSendBinaryHeader(ZACK, Txhdr);
                  if Progress <> nil then
                  begin
                    Progress.RxPosition := Rxbytes;
                    Progress.RxBlockSize := Rxcount;
                    Progress.Update;
                  end;
                  { continue moredata }
                end;

                GOTCRCG:
                begin
                  n := 10;
                  if Rxcount > 0 then
                    fout.Write(ZRxBuffer[0], Rxcount);
                  Inc(Rxbytes, Rxcount);
                  if Progress <> nil then
                  begin
                    Progress.RxPosition := Rxbytes;
                    Progress.RxBlockSize := Rxcount;
                    Progress.Update;
                  end;
                  { continue moredata }
                end;

                GOTCRCE:
                begin
                  n := 10;
                  if Rxcount > 0 then
                    fout.Write(ZRxBuffer[0], Rxcount);
                  Inc(Rxbytes, Rxcount);
                  if Progress <> nil then
                  begin
                    Progress.RxPosition := Rxbytes;
                    Progress.RxBlockSize := Rxcount;
                    Progress.Update;
                  end;
                  Break; { back to nxthdr }
                end;
              end; { case c }
            end; { moredata while }
          end; { ZDATA }
        else
          Break; { unhandled header, back to outer ZRPOS loop }
        end; { case }
      end; { nxthdr while }
    end; { outer while }
  finally
    EndProgress;
    CloseAndSetTime;
  end;

  Result := Z_ERROR;
end;

{ ======================================================================
  ZSendFile - send a file via Zmodem
  ====================================================================== }

function TZModem.ZSendFile(const FileName: String; const SendName: String): SmallInt;
var
  fs: TFileStream;
  c: SmallInt;
  filedone: Boolean;
  len: SmallInt;
  goodneeded, goodblks: SmallInt;
  buf: array[0..63] of Byte;
  qpos: Integer;
  BaseName, InfoStr: String;
  starttime: LongWord;
  fsize: LongInt;
  fmode: LongInt;
  SR: TSearchRec;
  ftime: LongInt;
begin
  if not FileExists(FileName) then
  begin
    Result := Z_ERROR;
    Exit;
  end;

  try
    fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  except
    Result := Z_ERROR;
    Exit;
  end;

  try
    { Build file info block: name\0size mtime mode }
    FillChar(buf, SizeOf(buf), 0);
    if SendName <> '' then
      BaseName := SendName
    else
      BaseName := ExtractFileName(FileName);

    fsize := fs.Size;
    ftime := 0;
    fmode := 0;
    if FindFirst(FileName, faAnyFile, SR) = 0 then
    begin
      ftime := DateTimeToUnix(FileDateToDateTime(SR.Time));
      {$IFDEF UNIX}
      fmode := SR.Attr;
      {$ENDIF}
      FindClose(SR);
    end;

    { Copy name into buf }
    if Length(BaseName) > 62 then
      BaseName := Copy(BaseName, 1, 62);
    Move(BaseName[1], buf[0], Length(BaseName));
    qpos := Length(BaseName) + 1;
    buf[Length(BaseName)] := 0;  { null terminator after name }

    InfoStr := Format('%d %o %o', [fsize, ftime, fmode]);
    if qpos + Length(InfoStr) < SizeOf(buf) then
      Move(InfoStr[1], buf[qpos], Length(InfoStr));

    starttime := DateTimeToUnix(Now);

    Txpos := 0;
    Rxpos := 0;
    if Log <> nil then
      Log.Write(' Sending %s; %db, %d min.',
        [FileName, fsize, (fsize * 10 div LongInt(Speed) + 53) div 54]);

    if Progress <> nil then
    begin
      Progress.ProgressType := FILE_SENDING;
      if SendName <> '' then
        Progress.TxFileName := SendName
      else
        Progress.TxFileName := FileName;
      Progress.TxBlockSize := 0;
      Progress.TxSize := fsize;
      Progress.BeginTransfer;
      Progress.Update;
    end;

    { Drain any pending input }
    while (TimedRead(50) <> -1) and (not AbortSession) do
      ;

    { Send ZFILE header and file info }
    repeat
      Txhdr[ZF0] := LZCONV;
      Txhdr[ZF1] := LZMANAG;
      Txhdr[ZF2] := LZTRANS;
      Txhdr[ZF3] := 0;
      ZSendBinaryHeader(ZFILE, Txhdr);
      ZSendData(@buf[0], SmallInt(StrLen(PChar(@buf[0])) + 1 +
        StrLen(PChar(@buf[qpos]))), ZCRCW);

      c := ZGetHeader(Rxhdr);
      case c of
        ZRINIT:
          Continue;

        ZCAN, Z_TIMEOUT, ZABORT, ZFIN, Z_RCDO:
        begin
          if Progress <> nil then
            Progress.EndTransfer;
          if Log <> nil then
            Log.Write('!Aborted by remote', []);
          Result := Z_ERROR;
          Exit;
        end;

        ZSKIP:
        begin
          if Progress <> nil then
            Progress.EndTransfer;
          if Log <> nil then
            Log.Write('+Remote refused %s', [BaseName]);
          Result := c;
          Exit;
        end;

        ZRPOS:
          ; { break out of repeat }

        Z_ERROR:
          Continue;
      else
        Continue;
      end;
    until (c = ZRPOS) or AbortSession;

    { Seek to requested position }
    fs.Seek(Rxpos, soFromBeginning);
    Txpos := Rxpos;
    filedone := False;
    goodblks := 0;
    goodneeded := 4;
    Rxbuflen := 1024;

    if Progress <> nil then
    begin
      Progress.TxPosition := Txpos;
      Progress.TxBlockSize := 0;
      Progress.Update;
    end;

    if Txpos < fsize then
    begin
      ZPutLong(Txhdr, Txpos);
      ZSendBinaryHeader(ZDATA, Txhdr);
    end;

    { Main send loop }
    while not AbortSession do
    begin
      if not filedone then
      begin
        len := SmallInt(fs.Read(TxBuffer^, Rxbuflen));
        if len > 0 then
        begin
          if len < Rxbuflen then
            ZSendData(TxBuffer, len, ZCRCE)
          else
            ZSendData(TxBuffer, len, ZCRCG);
          Inc(Txpos, len);
          if Progress <> nil then
          begin
            Inc(Progress.TxPosition, len);
            Progress.TxBlockSize := len;
            Progress.Update;
          end;
        end
        else
        begin
          filedone := True;
          ZPutLong(Txhdr, Txpos);
          ZSendBinaryHeader(ZEOF, Txhdr);
        end;
      end;

      { Adaptive block size }
      if (Rxbuflen < Maxblklen) then
      begin
        Inc(goodblks);
        if goodblks > goodneeded then
        begin
          if (Rxbuflen shl 1) < Maxblklen then
            Rxbuflen := Rxbuflen shl 1
          else
            Rxbuflen := Maxblklen;
          goodblks := 0;
        end;
      end;

      { Check for incoming headers }
      while (Com.BytesReady <> 0) and (not AbortSession) do
      begin
        c := Com.ReadByte;
        if (c = CTRL_X) or (c = ZPAD) then
        begin
          c := ZGetHeader(Rxhdr);
          case c of
            ZACK:
              ; { continue }

            ZRINIT:
            begin
              if Progress <> nil then
                Progress.EndTransfer;
              starttime := DateTimeToUnix(Now) - starttime;
              if starttime = 0 then Inc(starttime);
              if Log <> nil then
              begin
                Log.Write('+CPS: %d (%d bytes)  Efficiency: %d%%',
                  [fsize div LongInt(starttime), fsize,
                   ((fsize div LongInt(starttime)) * 100) div LongInt(Speed div 10)]);
                if Txfcs32 <> 0 then
                  Log.Write('+Sent-Z/32 %s', [UpperCase(FileName)])
                else
                  Log.Write('+Sent-Z %s', [UpperCase(FileName)]);
              end;
              Result := Z_OK;
              Exit;
            end;

            ZRPOS:
            begin
              Txpos := Rxpos;
              fs.Seek(Txpos, soFromBeginning);
              filedone := False;
              Com.ClearOutbound;
              if Txpos < fsize then
              begin
                ZPutLong(Txhdr, Txpos);
                ZSendBinaryHeader(ZDATA, Txhdr);
              end;
              if Rxpos > 0 then
              begin
                if (Rxbuflen shr 2) > 64 then
                  Rxbuflen := Rxbuflen shr 2
                else
                  Rxbuflen := 64;
                goodblks := 0;
                if (goodneeded shl 1) > 16 then
                  goodneeded := 16
                else
                  goodneeded := goodneeded shl 1;
              end;
              if Progress <> nil then
              begin
                Progress.TxPosition := Rxpos;
                Progress.TxBlockSize := Rxbuflen;
                Progress.Update;
              end;
              Break; { back to main send loop }
            end;

            ZSKIP:
            begin
              if Progress <> nil then
                Progress.EndTransfer;
              if Log <> nil then
                Log.Write('+Remote refused %s', [BaseName]);
              Result := c;
              Exit;
            end;
          end; { case }
        end;
      end; { while BytesReady }
    end; { main send loop }

    if Progress <> nil then
      Progress.EndTransfer;
  finally
    fs.Free;
  end;

  Result := Z_ERROR;
end;

{ ======================================================================
  ZEndSender - end Zmodem send session
  ====================================================================== }

procedure TZModem.ZEndSender;
var
  Timeout_: LongInt;
  c: SmallInt;
begin
  FileSent := 0;

  Timeout_ := TimerSet(200);
  while (not AbortSession) and (TimeUp(Timeout_) = 0) do
  begin
    ZPutLong(Txhdr, 0);
    ZSendBinaryHeader(ZFIN, Txhdr);

    c := ZGetHeader(Rxhdr);
    case c of
      ZFIN:
      begin
        Com.SendByte(Ord('O'));
        Com.SendByte(Ord('O'));
        Exit;
      end;
      ZCAN, Z_TIMEOUT, Z_RCDO:
        Exit;
    end;
  end;

  Com.ClearInbound;
end;

