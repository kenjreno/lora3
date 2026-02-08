{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of packet.cpp
  FidoNet packet (.PKT) message base format
}

unit Packet;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect, Struc299, MsgBase;

type
  PKTINDEX = packed record
    Number: LongWord;
    Position: LongWord;
  end;
  PPKTINDEX = ^PKTINDEX;

  TPacket = class(TMsgBase)
  private
    fpStream: TFileStream;
    pkt2Hdr: PKT2HDR;
    pkt22Hdr: PKT22HDR;
    msgHdr: PKTMSGHDR;
    LastRead: Char;
    Line: array[0..255] of Char;
    FileName: array[0..127] of Char;
    TotalMsgs: LongWord;
    Index: TCollection;

    function GetLine: Boolean;
    procedure ParseAddress(const Addr: PChar; var Zone, Net, Node, Point: Word);

  public
    Password: array[0..15] of Char;
    Date_: MDATE;

    constructor Create; overload;
    constructor CreateOpen(const AName: string);
    destructor Destroy; override;

    function Add: Boolean; override;
    function AddFrom(AMsgBase: TMsgBase): Boolean; override;
    function AddText(var MsgText: TCollection): Boolean; override;
    procedure Close; override;
    function Delete(ulMsg: LongWord): Boolean; override;
    function Highest: LongWord; override;
    function GetHWM(var ulMsg: LongWord): Boolean; override;
    procedure Kill;
    function Lock(ulTimeout: LongWord = 0): Boolean; override;
    function Lowest: LongWord; override;
    function MsgnToUid(ulMsg: LongWord): LongWord; override;
    procedure New; override;
    function Next(var ulMsg: LongWord): Boolean; override;
    function Number: LongWord; override;
    function Open(const AName: string; doScan: Boolean = True): Boolean;
    procedure Pack; override;
    function Previous(var ulMsg: LongWord): Boolean; override;
    function ReadHeader(ulMsg: LongWord): Boolean; override;
    function ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt = 79): Boolean; override;
    function ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt = 79): Boolean; override;
    procedure SetHWM(ulMsg: LongWord); override;
    function UidToMsgn(ulMsg: LongWord): LongWord; override;
    procedure UnLock; override;
    function WriteHeader(ulMsg: LongWord): Boolean; override;
  end;

implementation

const
  pktMonths: array[0..11] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );

procedure TPacket.ParseAddress(const Addr: PChar; var Zone, Net, Node, Point: Word);
var
  s, p: string;
  idx, atIdx: Integer;
begin
  Zone := 0; Net := 0; Node := 0; Point := 0;
  s := StrPas(Addr);

  idx := Pos(':', s);
  if idx > 0 then
  begin
    Zone := StrToIntDef(Copy(s, 1, idx - 1), 0);
    System.Delete(s, 1, idx);
  end;

  idx := Pos('/', s);
  if idx > 0 then
  begin
    Net := StrToIntDef(Copy(s, 1, idx - 1), 0);
    System.Delete(s, 1, idx);
  end;

  atIdx := Pos('@', s);
  if atIdx > 0 then
    s := Copy(s, 1, atIdx - 1);

  idx := Pos('.', s);
  if idx > 0 then
  begin
    Node := StrToIntDef(Copy(s, 1, idx - 1), 0);
    Point := StrToIntDef(Copy(s, idx + 1, Length(s)), 0);
  end
  else
    Node := StrToIntDef(s, 0);
end;

constructor TPacket.Create;
begin
  inherited Create;
  fpStream := nil;
  TotalMsgs := 0;
  Index := TCollection.Create;
  FillChar(Password, SizeOf(Password), 0);
  LastRead := #0;
end;

constructor TPacket.CreateOpen(const AName: string);
begin
  Create;
  Open(AName);
end;

destructor TPacket.Destroy;
begin
  Close;
  Index.Free;
  inherited Destroy;
end;

function TPacket.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TPacket.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Move(AMsgBase.FromAddress, FromAddress, SizeOf(FromAddress));
  Move(AMsgBase.ToAddress, ToAddress, SizeOf(ToAddress));
  Result := AddText(AMsgBase.Text);
end;

function TPacket.AddText(var MsgText: TCollection): Boolean;
var
  f1, f2, f3, f4, t1, t2, t3, t4: Word;
  AddedIntl, IsEchomail: Boolean;
  Temp: string;
  pszText: PChar;
  pktIndex: PKTINDEX;
  NowDT: TDateTime;
  yr, mo, dy, hr, mn, sc, ms: Word;
  DateStr: string;
begin
  Result := True;
  if fpStream = nil then Exit;

  { Seek to end - 2 (before terminator) }
  fpStream.Position := fpStream.Size - 2;

  FillChar(pktIndex, SizeOf(PKTINDEX), 0);
  pktIndex.Number := TotalMsgs + 1;
  pktIndex.Position := fpStream.Position;

  FillChar(msgHdr, SizeOf(PKTMSGHDR), 0);
  msgHdr.Version := 2;

  ParseAddress(FromAddress, f1, f2, f3, f4);
  msgHdr.OrigNet := f2;
  msgHdr.OrigNode := f3;

  ParseAddress(ToAddress, t1, t2, t3, t4);
  msgHdr.DestNet := t2;
  msgHdr.DestNode := t3;

  if Crash <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGCRASH;
  if FileAttach <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGFILE;
  if FileRequest <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGFRQ;
  if Hold <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGHOLD;
  if KillSent <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGKILL;
  if Local_ <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGLOCAL;
  if Private_ <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGPRIVATE;
  if ReceiptRequest <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGRRQ;
  if Received <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGREAD;
  if Sent <> 0 then msgHdr.Attrib := msgHdr.Attrib or MSGSENT;

  fpStream.Write(msgHdr, SizeOf(PKTMSGHDR));

  { Fill in Written date defaults if needed }
  if Written.Day = 0 then
  begin
    NowDT := Now;
    DecodeDate(NowDT, yr, mo, dy);
    DecodeTime(NowDT, hr, mn, sc, ms);
    Written.Day := dy;
    Written.Month := mo;
    Written.Year := yr;
    Written.Hour := hr;
    Written.Minute := mn;
    Written.Second := sc;
  end;

  { Write date string null-terminated }
  if Written.Month >= 1 then
    DateStr := Format('%2d %s %02d  %02d:%02d:%02d', [
      Written.Day, pktMonths[Written.Month - 1], Written.Year mod 100,
      Written.Hour, Written.Minute, 0])
  else
    DateStr := '';
  DateStr := DateStr + #0;
  fpStream.Write(DateStr[1], Length(DateStr));

  { Write To, From, Subject null-terminated }
  fpStream.Write(To_, StrLen(To_) + 1);
  fpStream.Write(From_, StrLen(From_) + 1);
  fpStream.Write(Subject_, StrLen(Subject_) + 1);

  { Check if echomail }
  IsEchomail := False;
  AddedIntl := False;
  pszText := PChar(MsgText.First);
  if pszText <> nil then
    if StrLComp(pszText, 'AREA:', 5) = 0 then
      IsEchomail := True;

  { Add kludges for netmail }
  if not IsEchomail then
  begin
    if f1 <> t1 then
    begin
      Temp := Format(#1'INTL %d:%d/%d %d:%d/%d'#13, [t1, t2, t3, f1, f2, f3]);
      fpStream.Write(Temp[1], Length(Temp));
      AddedIntl := True;
    end;
    if f4 <> 0 then
    begin
      Temp := Format(#1'FMPT %u'#13, [f4]);
      fpStream.Write(Temp[1], Length(Temp));
    end;
    if t4 <> 0 then
    begin
      Temp := Format(#1'TOPT %u'#13, [t4]);
      fpStream.Write(Temp[1], Length(Temp));
    end;
  end;

  { Write message text }
  pszText := PChar(MsgText.First);
  if pszText <> nil then
  repeat
    if not IsEchomail then
    begin
      if StrLComp(pszText, #1'FMPT ', 6) = 0 then continue;
      if StrLComp(pszText, #1'TOPT ', 6) = 0 then continue;
      if (StrLComp(pszText, #1'INTL ', 6) = 0) and AddedIntl then continue;
    end;
    fpStream.Write(pszText^, StrLen(pszText));
    fpStream.Write(#13, 1);
  until PChar(MsgText.Next) = nil;

  { Write message terminator + packet end }
  fpStream.Write(#0#0#0, 3);

  Index.Add(@pktIndex, SizeOf(PKTINDEX));
  Inc(TotalMsgs);
end;

procedure TPacket.Close;
begin
  Id := 0;
  FreeAndNil(fpStream);
  Index.Clear;
end;

function TPacket.Delete(ulMsg: LongWord): Boolean;
var
  pktIdx: PPKTINDEX;
begin
  Result := False;
  pktIdx := PPKTINDEX(Index.First);
  while pktIdx <> nil do
  begin
    if pktIdx^.Number = ulMsg then
    begin
      Index.Remove;
      Result := True;
    end;
    pktIdx := PPKTINDEX(Index.Next);
  end;
end;

function TPacket.GetHWM(var ulMsg: LongWord): Boolean;
begin
  ulMsg := 0;
  Result := False;
end;

function TPacket.GetLine: Boolean;
var
  Readed: Integer;
  c: Integer;
  Ptr: PChar;
  MaybeEOM: Boolean;
begin
  Readed := 0;
  MaybeEOM := False;
  Ptr := @Line[0];

  if LastRead = #13 then
  begin
    MaybeEOM := True;
    c := 0;
    fpStream.Read(c, 1);
    if (c >= Ord(' ')) or (c = $01) then
    begin
      Ptr^ := Char(c);
      Inc(Ptr);
      Inc(Readed);
    end
    else if c <> 10 then
      fpStream.Position := fpStream.Position - 1;
  end;

  repeat
    if Readed < SizeOf(Line) - 1 then
    begin
      c := 0;
      if fpStream.Read(c, 1) = 0 then
      begin
        c := -1; { EOF }
        Break;
      end;
      if c <> 0 then
      begin
        Ptr^ := Char(c);
        Inc(Ptr);
        Inc(Readed);
      end;
    end
    else
      Break;
  until (c = 0) or (c = -1);

  Ptr^ := #0;
  if c >= 0 then
    LastRead := Char(c)
  else
    LastRead := #0;

  if MaybeEOM and (c = 0) then
    fpStream.Position := fpStream.Position - 1;

  Result := not ((Readed = 0) and (c = -1));
end;

function TPacket.Highest: LongWord;
var
  pktIdx: PPKTINDEX;
begin
  Result := 0;
  pktIdx := PPKTINDEX(Index.Last);
  if pktIdx <> nil then
    Result := pktIdx^.Number;
end;

procedure TPacket.Kill;
begin
  if fpStream <> nil then
  begin
    FreeAndNil(fpStream);
  end;
  if FileName[0] <> #0 then
    SysUtils.DeleteFile(StrPas(FileName));
  Index.Clear;
end;

function TPacket.Lock(ulTimeout: LongWord): Boolean;
begin
  Result := True;
end;

function TPacket.Lowest: LongWord;
var
  pktIdx: PPKTINDEX;
begin
  Result := 0;
  pktIdx := PPKTINDEX(Index.First);
  if pktIdx <> nil then
    Result := pktIdx^.Number;
end;

function TPacket.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TPacket.New;
begin
  From_[0] := #0; To_[0] := #0; Subject_[0] := #0;
  Crash := 0; Direct := 0; FileAttach := 0; FileRequest := 0;
  Hold := 0; Immediate := 0; Intransit := 0; KillSent := 0;
  Local_ := 0; Private_ := 0; ReceiptRequest := 0; Received := 0;
  Sent := 0;
  FillChar(Written, SizeOf(Written), 0);
  Written.Month := 1;
  FillChar(Arrived, SizeOf(Arrived), 0);
  Arrived.Month := 1;
  Original := 0; Reply := 0;
  Text.Clear;
end;

function TPacket.Next(var ulMsg: LongWord): Boolean;
var
  pktIdx: PPKTINDEX;
  c: Byte;
begin
  Result := False;
  pktIdx := PPKTINDEX(Index.Next);
  if pktIdx <> nil then
  begin
    ulMsg := pktIdx^.Number;
    if fpStream.Position <> Int64(pktIdx^.Position) then
      fpStream.Position := pktIdx^.Position;
    Result := True;
  end
  else if Index.Elements = 0 then
  begin
    c := 0;
    if fpStream.Read(c, 1) = 1 then
    begin
      if c = 2 then
      begin
        Inc(ulMsg);
        Current := ulMsg;
        Result := True;
      end;
      fpStream.Position := fpStream.Position - 1;
    end;
  end;
end;

function TPacket.Number: LongWord;
begin
  Result := TotalMsgs;
end;

function TPacket.Open(const AName: string; doScan: Boolean): Boolean;
var
  c: Byte;
  Position: Int64;
  pktIndex: PKTINDEX;
  NowDT: TDateTime;
  yr, mo, dy, hr, mn, sc, ms: Word;
  i: Word;
  s: string;
begin
  Result := False;
  TotalMsgs := 0;
  Index.Clear;

  FreeAndNil(fpStream);

  if FileExists(AName) then
    fpStream := TFileStream.Create(AName, fmOpenReadWrite or fmShareDenyNone)
  else
    fpStream := TFileStream.Create(AName, fmCreate);
  StrPCopy(FileName, AName);

  if fpStream <> nil then
  begin
    if fpStream.Size = 0 then
    begin
      { Create new packet }
      FillChar(pkt2Hdr, SizeOf(PKT2HDR), 0);

      NowDT := Now;
      DecodeDate(NowDT, yr, mo, dy);
      DecodeTime(NowDT, hr, mn, sc, ms);

      pkt2Hdr.Version := 2;
      pkt2Hdr.CWValidation := $0100;
      pkt2Hdr.Capability := $0001;
      pkt2Hdr.ProductL := $4E;

      pkt2Hdr.Day := dy;
      pkt2Hdr.Month := mo - 1;
      pkt2Hdr.Year := yr;
      pkt2Hdr.Hour := hr;
      pkt2Hdr.Minute := mn;
      pkt2Hdr.Second := sc;

      ParseAddress(ToAddress, pkt2Hdr.DestZone2, pkt2Hdr.DestNet, pkt2Hdr.DestNode, pkt2Hdr.DestPoint);
      pkt2Hdr.DestZone := pkt2Hdr.DestZone2;

      ParseAddress(FromAddress, pkt2Hdr.OrigZone2, pkt2Hdr.OrigNet, pkt2Hdr.OrigNode, pkt2Hdr.OrigPoint);
      pkt2Hdr.OrigZone := pkt2Hdr.OrigZone2;

      Move(Password, pkt2Hdr.Password, 8);
      fpStream.Write(pkt2Hdr, SizeOf(PKT2HDR));

      { Write initial terminator (2 bytes of zero = empty MSGHDR.Version) }
      FillChar(msgHdr, SizeOf(PKTMSGHDR), 0);
      fpStream.Write(msgHdr, 2);

      StrPCopy(FromAddress, Format('%d:%d/%d.%d', [pkt2Hdr.OrigZone, pkt2Hdr.OrigNet, pkt2Hdr.OrigNode, pkt2Hdr.OrigPoint]));
      StrPCopy(ToAddress, Format('%d:%d/%d.%d', [pkt2Hdr.DestZone, pkt2Hdr.DestNet, pkt2Hdr.DestNode, pkt2Hdr.DestPoint]));

      fpStream.Position := fpStream.Size - SizeOf(PKTMSGHDR);
      Result := True;
    end
    else
    begin
      { Read existing packet header }
      fpStream.Read(pkt2Hdr, SizeOf(PKT2HDR));
      if pkt2Hdr.Version = 2 then
      begin
        if pkt2Hdr.Rate = 2 then
        begin
          { Type 2.2 packet }
          Move(pkt2Hdr, pkt22Hdr, SizeOf(PKT22HDR));
          StrPCopy(FromAddress, Format('%d:%d/%d.%d', [pkt22Hdr.OrigZone, pkt22Hdr.OrigNet, pkt22Hdr.OrigNode, pkt22Hdr.OrigPoint]));
          if pkt22Hdr.OrigDomain[0] <> #0 then
          begin
            s := StrPas(FromAddress) + '@' + StrPas(pkt22Hdr.OrigDomain);
            StrPCopy(FromAddress, s);
          end;
          StrPCopy(ToAddress, Format('%d:%d/%d.%d', [pkt22Hdr.DestZone, pkt22Hdr.DestNet, pkt22Hdr.DestNode, pkt22Hdr.DestPoint]));
          if pkt22Hdr.DestDomain[0] <> #0 then
          begin
            s := StrPas(ToAddress) + '@' + StrPas(pkt22Hdr.DestDomain);
            StrPCopy(ToAddress, s);
          end;
          Result := True;
        end
        else
        begin
          { Type 2+ packet - check capability word }
          i := Swap(pkt2Hdr.CWValidation);
          pkt2Hdr.CWValidation := i;
          if (pkt2Hdr.Capability <> pkt2Hdr.CWValidation) or ((pkt2Hdr.Capability and $0001) = 0) then
          begin
            StrPCopy(FromAddress, Format('%d:%d/%d.%d', [pkt2Hdr.OrigZone, pkt2Hdr.OrigNet, pkt2Hdr.OrigNode, 0]));
            StrPCopy(ToAddress, Format('%d:%d/%d.%d', [pkt2Hdr.DestZone, pkt2Hdr.DestNet, pkt2Hdr.DestNode, 0]));
          end
          else
          begin
            StrPCopy(FromAddress, Format('%d:%d/%d.%d', [pkt2Hdr.OrigZone, pkt2Hdr.OrigNet, pkt2Hdr.OrigNode, pkt2Hdr.OrigPoint]));
            StrPCopy(ToAddress, Format('%d:%d/%d.%d', [pkt2Hdr.DestZone, pkt2Hdr.DestNet, pkt2Hdr.DestNode, pkt2Hdr.DestPoint]));
          end;
          Move(pkt2Hdr.Password, Password, SizeOf(pkt2Hdr.Password));
          Password[SizeOf(pkt2Hdr.Password)] := #0;
          Result := True;
        end;
      end;
    end;
  end;

  if Result then
  begin
    Date_.Day := pkt2Hdr.Day;
    Date_.Month := pkt2Hdr.Month + 1;
    Date_.Year := pkt2Hdr.Year;
    Date_.Hour := pkt2Hdr.Hour;
    Date_.Minute := pkt2Hdr.Minute;
    Date_.Second := pkt2Hdr.Second;
  end;

  { Scan messages if requested }
  if Result and (fpStream <> nil) and doScan then
  begin
    repeat
      FillChar(pktIndex, SizeOf(PKTINDEX), 0);
      pktIndex.Position := fpStream.Position;

      FillChar(msgHdr, SizeOf(PKTMSGHDR), 0);
      if fpStream.Read(msgHdr, SizeOf(PKTMSGHDR)) < SizeOf(PKTMSGHDR) then
        Break;

      if msgHdr.Version = 2 then
      begin
        { Skip Date, To, From, Subject - all null-terminated strings }
        repeat c := 0; if fpStream.Read(c, 1) = 0 then c := 0; until (c = 0) or (fpStream.Position >= fpStream.Size);
        repeat c := 0; if fpStream.Read(c, 1) = 0 then c := 0; until (c = 0) or (fpStream.Position >= fpStream.Size);
        repeat c := 0; if fpStream.Read(c, 1) = 0 then c := 0; until (c = 0) or (fpStream.Position >= fpStream.Size);
        repeat c := 0; if fpStream.Read(c, 1) = 0 then c := 0; until (c = 0) or (fpStream.Position >= fpStream.Size);
        { Skip text body }
        repeat c := 0; if fpStream.Read(c, 1) = 0 then c := 0; until (c = 0) or (fpStream.Position >= fpStream.Size);

        Inc(TotalMsgs);
        pktIndex.Number := TotalMsgs;
        Index.Add(@pktIndex, SizeOf(PKTINDEX));
      end
      else if msgHdr.Version <> 0 then
      begin
        { Unknown version - skip until null or EOF }
        repeat
          c := 0;
          if fpStream.Read(c, 1) = 0 then Break;
        until (c = 0) or (fpStream.Position >= fpStream.Size);
        if c = 0 then
        begin
          Position := fpStream.Position;
          FillChar(msgHdr, SizeOf(PKTMSGHDR), 0);
          fpStream.Read(msgHdr, SizeOf(PKTMSGHDR));
          fpStream.Position := Position;
        end
        else
          msgHdr.Version := 0;
      end;
    until msgHdr.Version = 0;
  end;
end;

procedure TPacket.Pack;
begin
  { Not implemented }
end;

function TPacket.Previous(var ulMsg: LongWord): Boolean;
var
  pktIdx: PPKTINDEX;
begin
  Result := False;
  pktIdx := PPKTINDEX(Index.Previous);
  if pktIdx <> nil then
  begin
    ulMsg := pktIdx^.Number;
    if fpStream.Position <> Int64(pktIdx^.Position) then
      fpStream.Position := pktIdx^.Position;
    Result := True;
  end;
end;

function TPacket.ReadHeader(ulMsg: LongWord): Boolean;
var
  dd, yy, hr, mn, sc, i: Integer;
  mm: array[0..3] of Char;
  pktIdx: PPKTINDEX;
  NowDT: TDateTime;
  yr2, mo2, dy2, hr2, mn2, sc2, ms2: Word;
  DateLine: string;
begin
  Result := False;
  New;

  { Seek to message position }
  pktIdx := PPKTINDEX(Index.First);
  while pktIdx <> nil do
  begin
    if pktIdx^.Number = ulMsg then
    begin
      fpStream.Position := pktIdx^.Position;
      Break;
    end;
    pktIdx := PPKTINDEX(Index.Next);
  end;

  FillChar(msgHdr, SizeOf(PKTMSGHDR), 0);
  fpStream.Read(msgHdr, SizeOf(PKTMSGHDR));

  if msgHdr.Version = 2 then
  begin
    Result := True;

    if (pkt2Hdr.Capability <> pkt2Hdr.CWValidation) or ((pkt2Hdr.Capability and $0001) = 0) then
    begin
      StrPCopy(FromAddress, Format('%d:%d/%d.%d', [pkt2Hdr.OrigZone, msgHdr.OrigNet, msgHdr.OrigNode, 0]));
      StrPCopy(ToAddress, Format('%d:%d/%d.%d', [pkt2Hdr.DestZone, msgHdr.DestNet, msgHdr.DestNode, 0]));
    end
    else
    begin
      StrPCopy(FromAddress, Format('%d:%d/%d.%d', [pkt2Hdr.OrigZone, msgHdr.OrigNet, msgHdr.OrigNode, pkt2Hdr.OrigPoint]));
      StrPCopy(ToAddress, Format('%d:%d/%d.%d', [pkt2Hdr.DestZone, msgHdr.DestNet, msgHdr.DestNode, pkt2Hdr.DestPoint]));
    end;

    { Read date line }
    LastRead := #0;
    GetLine;
    { Parse: "dd Mon yy  hh:mm:ss" }
    dd := 0; yy := 0; hr := 0; mn := 0; sc := 0;
    FillChar(mm, SizeOf(mm), 0);
    DateLine := StrPas(@Line[0]);
    try
      dd := StrToIntDef(Trim(Copy(DateLine, 1, 2)), 0);
      Move(DateLine[4], mm, 3);
      yy := StrToIntDef(Trim(Copy(DateLine, 8, 2)), 0);
      hr := StrToIntDef(Copy(DateLine, 12, 2), 0);
      mn := StrToIntDef(Copy(DateLine, 15, 2), 0);
      sc := StrToIntDef(Copy(DateLine, 18, 2), 0);
    except
    end;

    Written.Day := dd;
    for i := 0 to 11 do
      if SameText(pktMonths[i], StrPas(@mm[0])) then
      begin
        Written.Month := i + 1;
        Break;
      end;
    if (Written.Month < 1) or (Written.Month > 12) then
      Written.Month := 1;
    Written.Year := yy + 1900;
    if Written.Year < 1990 then
      Written.Year := Written.Year + 100;
    Written.Hour := hr;
    Written.Minute := mn;
    Written.Second := sc;

    { Set arrived to now }
    NowDT := Now;
    DecodeDate(NowDT, yr2, mo2, dy2);
    DecodeTime(NowDT, hr2, mn2, sc2, ms2);
    Arrived.Day := dy2;
    Arrived.Month := mo2;
    Arrived.Year := yr2;
    Arrived.Hour := hr2;
    Arrived.Minute := mn2;
    Arrived.Second := sc2;

    { Read To, From, Subject }
    GetLine;
    StrCopy(To_, Line);
    GetLine;
    StrCopy(From_, Line);
    GetLine;
    StrCopy(Subject_, Line);
  end;
end;

function TPacket.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

{ Helper: parse "z:n/d z:n/d" INTL format }
function ParseINTL(const s: string; var t1, t2, t3, f1, f2, f3: Integer): Boolean;
var
  Parts: TStringArray;
  Part1, Part2: string;
  p1, p2: Integer;
begin
  Result := False;
  Parts := s.Split([' ']);
  if Length(Parts) < 2 then Exit;

  Part1 := Parts[0]; Part2 := Parts[1];

  p1 := Pos(':', Part1);
  if p1 = 0 then Exit;
  t1 := StrToIntDef(Copy(Part1, 1, p1 - 1), 0);
  System.Delete(Part1, 1, p1);
  p2 := Pos('/', Part1);
  if p2 = 0 then Exit;
  t2 := StrToIntDef(Copy(Part1, 1, p2 - 1), 0);
  t3 := StrToIntDef(Copy(Part1, p2 + 1, Length(Part1)), 0);

  p1 := Pos(':', Part2);
  if p1 = 0 then Exit;
  f1 := StrToIntDef(Copy(Part2, 1, p1 - 1), 0);
  System.Delete(Part2, 1, p1);
  p2 := Pos('/', Part2);
  if p2 = 0 then Exit;
  f2 := StrToIntDef(Copy(Part2, 1, p2 - 1), 0);
  f3 := StrToIntDef(Copy(Part2, p2 + 1, Length(Part2)), 0);

  Result := True;
end;

function TPacket.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  c: Byte;
  f1, f2, f3, f4, t1, t2, t3, t4: Integer;
  nCol: SmallInt;
  IntlLine: string;
  n1, n2, n3, n4, n5, n6: Integer;
begin
  MsgText.Clear;

  if not ReadHeader(ulMsg) then
  begin
    Result := False;
    Exit;
  end;

  Current := ulMsg;
  pLine := @szLine[0];
  nCol := 0;

  f1 := pkt2Hdr.OrigZone; f2 := msgHdr.OrigNet; f3 := msgHdr.OrigNode; f4 := pkt2Hdr.OrigPoint;
  t1 := pkt2Hdr.DestZone; t2 := msgHdr.DestNet; t3 := msgHdr.DestNode; t4 := pkt2Hdr.DestPoint;

  StrPCopy(FromAddress, Format('%d:%d/%d.%d', [f1, f2, f3, f4]));
  StrPCopy(ToAddress, Format('%d:%d/%d.%d', [t1, t2, t3, t4]));

  { Read message body character by character }
  while True do
  begin
    c := 0;
    if fpStream.Read(c, 1) = 0 then Break;
    if c = 0 then Break;

    if c = Ord(#13) then
    begin
      pLine^ := #0;
      if StrLComp(szLine, #1'FMPT ', 6) = 0 then
      begin
        f4 := StrToIntDef(StrPas(@szLine[6]), 0);
        StrPCopy(FromAddress, Format('%d:%d/%d.%d', [f1, f2, f3, f4]));
      end
      else if StrLComp(szLine, #1'TOPT ', 6) = 0 then
      begin
        t4 := StrToIntDef(StrPas(@szLine[6]), 0);
        StrPCopy(ToAddress, Format('%d:%d/%d.%d', [t1, t2, t3, t4]));
      end
      else if StrLComp(szLine, #1'INTL ', 6) = 0 then
      begin
        { Parse INTL kludge: dest_zone:dest_net/dest_node from_zone:from_net/from_node }
        IntlLine := StrPas(@szLine[6]);
        n1 := 0; n2 := 0; n3 := 0; n4 := 0; n5 := 0; n6 := 0;
        if ParseINTL(IntlLine, n1, n2, n3, n4, n5, n6) then
        begin
          if (n1 <> msgHdr.DestNet) or (n3 <> msgHdr.DestNode) then
          begin
            { INTL addresses don't match header - keep kludge as-is }
            MsgText.Add(@szLine[0], StrLen(szLine) + 1);
            t2 := msgHdr.DestNet;
            t3 := msgHdr.DestNode;
          end
          else
          begin
            t1 := n1; t2 := n2; t3 := n3;
            f1 := n4; f2 := n5; f3 := n6;
            StrPCopy(FromAddress, Format('%d:%d/%d.%d', [f1, f2, f3, f4]));
            StrPCopy(ToAddress, Format('%d:%d/%d.%d', [t1, t2, t3, t4]));
          end;
        end;
      end
      else
        MsgText.Add(@szLine[0], StrLen(szLine) + 1);
      pLine := @szLine[0];
      nCol := 0;
    end
    else if c <> Ord(#10) then
    begin
      pLine^ := Char(c);
      Inc(pLine);
      Inc(nCol);
      if nCol >= nWidth then
      begin
        pLine^ := #0;
        while (nCol > 1) and (pLine^ <> ' ') do begin Dec(nCol); Dec(pLine); end;
        if nCol > 0 then begin while pLine^ = ' ' do Inc(pLine); StrCopy(szWrp, pLine); end;
        pLine^ := #0;
        MsgText.Add(@szLine[0], StrLen(szLine) + 1);
        StrCopy(szLine, szWrp);
        pLine := StrEnd(szLine);
        nCol := StrLen(szLine);
      end;
    end;
  end;

  Result := True;
end;

procedure TPacket.SetHWM(ulMsg: LongWord);
begin
  { Not supported }
end;

function TPacket.UidToMsgn(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TPacket.UnLock;
begin
  { Not supported }
end;

function TPacket.WriteHeader(ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

end.
