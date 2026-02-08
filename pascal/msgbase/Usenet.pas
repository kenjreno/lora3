{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of usenet.cpp
  NNTP (Usenet) newsgroup message base
}

unit Usenet;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Collect, Struc299, Tcpip, MsgBase;

type
  TUsenet = class(TMsgBase)
  private
    FTcp: TTcpip;
    ulHighest: LongWord;
    ulFirst: LongWord;
    ulTotal: LongWord;
    LastReaded: LongWord;

    function GetResponse(pszResponse: PChar; usMaxLen: Word): Word;

  public
    HostName: array[0..31] of Char;
    Organization: array[0..63] of Char;
    NewsGroup: array[0..63] of Char;
    User: array[0..31] of Char;
    ProgramID: array[0..31] of Char;
    Error: array[0..127] of Char;

    constructor Create; overload;
    constructor CreateOpen(pszServer, pszGroup: PChar);
    destructor Destroy; override;

    function Add: Boolean; override;
    function AddFrom(AMsgBase: TMsgBase): Boolean; override;
    function AddText(var MsgText: TCollection): Boolean; override;
    procedure Close; override;
    function Delete(ulMsg: LongWord): Boolean; override;
    function Highest: LongWord; override;
    function GetHWM(var ulMsg: LongWord): Boolean; override;
    function Lock(ulTimeout: LongWord = 0): Boolean; override;
    function Lowest: LongWord; override;
    function MsgnToUid(ulMsg: LongWord): LongWord; override;
    procedure New; override;
    function Next(var ulMsg: LongWord): Boolean; override;
    function Number: LongWord; override;
    function Open(pszServer, pszGroup: PChar): Boolean;
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

uses
  DateUtils;

const
  CMD_GROUP: string = 'GROUP %s'#13#10;
  CMD_HEAD: string = 'HEAD'#13#10;
  CMD_LAST: string = 'LAST'#13#10;
  CMD_NEXT: string = 'NEXT'#13#10;
  CMD_POST: string = 'POST'#13#10;
  CMD_QUIT: string = 'QUIT'#13#10;
  CMD_STAT: string = 'STAT %d'#13#10;
  CMD_ARTICLE: string = 'ARTICLE %d'#13#10;

  MONTHS: array[0..11] of string = (
    'January', 'February', 'March', 'April', 'Maj', 'Juni',
    'July', 'August', 'September', 'October', 'November', 'December'
  );

constructor TUsenet.Create;
begin
  inherited Create;
  FTcp := TTcpip.Create;
  ulHighest := 0;
  ulFirst := 0;
  ulTotal := 0;
  LastReaded := 0;
  StrPCopy(HostName, 'unknown.host');
  StrPCopy(User, 'anonymous');
  NewsGroup[0] := #0;
  StrPCopy(Organization, 'No Organization');
  StrPCopy(ProgramID, 'LoraBBS');
  FillChar(Error, SizeOf(Error), 0);
end;

constructor TUsenet.CreateOpen(pszServer, pszGroup: PChar);
begin
  Create;
  Open(pszServer, pszGroup);
end;

destructor TUsenet.Destroy;
begin
  FTcp.Free;
  inherited Destroy;
end;

function TUsenet.GetResponse(pszResponse: PChar; usMaxLen: Word): Word;
var
  Len: Word;
  c: Char;
  pResp: PChar;
  Timeout: LongInt;
begin
  Result := 0;
  Timeout := DateTimeToUnix(Now) + 60;
  pResp := pszResponse;
  Len := 0;

  repeat
    c := #0;
    if FTcp.BytesReady <> 0 then
    begin
      c := Char(FTcp.ReadByte);
      if c <> #13 then
      begin
        if c <> #10 then
        begin
          pResp^ := c;
          Inc(pResp);
          Inc(Len);
          if Len >= usMaxLen then
            c := #13;
        end;
      end;
    end;
  until (c = #13) or (FTcp.Carrier = 0) or (DateTimeToUnix(Now) >= Timeout);

  pResp^ := #0;
  if pszResponse[3] = ' ' then
    Result := StrToIntDef(Copy(StrPas(pszResponse), 1, 3), 0);
end;

function TUsenet.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TUsenet.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Move(AMsgBase.FromAddress, FromAddress, SizeOf(FromAddress));
  Move(AMsgBase.ToAddress, ToAddress, SizeOf(ToAddress));
  Result := AddText(AMsgBase.Text);
end;

function TUsenet.AddText(var MsgText: TCollection): Boolean;
var
  Lines: Word;
  GotPath, GotFrom, GotNews, GotSubject, GotOrg, GotLines, GotXNews: Boolean;
  pszText: PChar;
  MonthIdx: Integer;
begin
  Result := False;
  GotPath := False; GotFrom := False; GotNews := False;
  GotSubject := False; GotOrg := False; GotLines := False; GotXNews := False;

  if FTcp.Carrier = 0 then Exit;

  StrPCopy(szBuff, CMD_POST);
  FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
  if GetResponse(szBuff, SizeOf(szBuff) - 1) <> 340 then
  begin
    StrCopy(Error, szBuff);
    Exit;
  end;

  { Send kludge headers }
  pszText := PChar(MsgText.First);
  while pszText <> nil do
  begin
    if StrLComp(pszText, #1'Path: ', 7) = 0 then
    begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotPath := True; end
    else if StrLComp(pszText, #1'From: ', 7) = 0 then
    begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotFrom := True; end
    else if StrLComp(pszText, #1'Subject: ', 10) = 0 then
    begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotSubject := True; end
    else if StrLComp(pszText, #1'Organization: ', 15) = 0 then
    begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotOrg := True; end
    else if StrLComp(pszText, #1'X-Newsreader: ', 15) = 0 then
    begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotXNews := True; end
    else if (StrLComp(pszText, #1'References: ', 13) = 0) or (StrLComp(pszText, #1'Sender: ', 9) = 0) or (StrLComp(pszText, #1'X-To: ', 7) = 0) then
    begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); end;
    pszText := PChar(MsgText.Next);
  end;

  { Generate missing headers }
  if not GotPath then
  begin StrPCopy(szBuff, Format('Path: %s'#13#10, [StrPas(HostName)])); FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff)); end;
  if not GotFrom then
  begin StrPCopy(szBuff, Format('From: %s <%s@%s>'#13#10, [StrPas(From_), StrPas(User), StrPas(HostName)])); FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff)); end;
  if not GotNews then
  begin StrPCopy(szBuff, Format('Newsgroups: %s'#13#10, [StrPas(NewsGroup)])); FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff)); end;
  if not GotSubject then
  begin StrPCopy(szBuff, Format('Subject: %s'#13#10, [StrPas(Subject_)])); FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff)); end;
  if not GotOrg then
  begin StrPCopy(szBuff, Format('Organization: %s'#13#10, [StrPas(Organization)])); FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff)); end;

  MonthIdx := Written.Month;
  if (MonthIdx < 1) or (MonthIdx > 12) then MonthIdx := 1;
  StrPCopy(szBuff, Format('Date: %d %s %d %02d:%02d:%02d GMT'#13#10,
    [Written.Day, Copy(MONTHS[MonthIdx - 1], 1, 3), Written.Year,
     Written.Hour, Written.Minute, Written.Second]));
  FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff));

  if not GotLines then
  begin
    Lines := 1;
    pszText := PChar(MsgText.First);
    while pszText <> nil do
    begin
      if (pszText^ <> #1) and (StrLComp(pszText, 'SEEN-BY:', 8) <> 0) then
        Inc(Lines);
      pszText := PChar(MsgText.Next);
    end;
    StrPCopy(szBuff, Format('Lines: %d'#13#10, [Lines]));
    FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff));
  end;

  if not GotXNews then
  begin StrPCopy(szBuff, Format('X-Newsreader: %s'#13#10, [StrPas(ProgramID)])); FTcp.BufferBytes(PByte(@szBuff[0]), StrLen(szBuff)); end;

  { Blank line separates headers from body }
  FTcp.BufferBytes(PByte(PChar(#13#10)), 2);

  { Send body }
  pszText := PChar(MsgText.First);
  while pszText <> nil do
  begin
    if (pszText^ <> #1) and (StrLComp(pszText, 'SEEN-BY:', 8) <> 0) then
    begin
      if StrComp(pszText, '.') = 0 then
        FTcp.BufferBytes(PByte(PChar('..')), 2)
      else
        FTcp.BufferBytes(PByte(pszText), StrLen(pszText));
      FTcp.BufferBytes(PByte(PChar(#13#10)), 2);
    end;
    pszText := PChar(MsgText.Next);
  end;

  FTcp.BufferBytes(PByte(PChar('.'#13#10)), 3);
  FTcp.UnbufferBytes;
  if GetResponse(szBuff, SizeOf(szBuff) - 1) = 240 then
    Result := True;

  StrCopy(Error, szBuff);
end;

procedure TUsenet.Close;
var
  Buf: array[0..49] of Char;
begin
  StrPCopy(Buf, CMD_QUIT);
  FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
  GetResponse(Buf, SizeOf(Buf) - 1);
  ulHighest := 0;
  ulFirst := 0;
  ulTotal := 0;
end;

function TUsenet.Delete(ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

function TUsenet.GetHWM(var ulMsg: LongWord): Boolean;
begin
  ulMsg := 0;
  Result := False;
end;

function TUsenet.Highest: LongWord;
begin
  Result := ulHighest;
end;

function TUsenet.Lock(ulTimeout: LongWord): Boolean;
begin
  Result := True;
end;

function TUsenet.Lowest: LongWord;
begin
  Result := ulFirst;
end;

function TUsenet.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  if (ulMsg >= 1) and (ulMsg <= Number) then
    ulMsg := ulMsg + Lowest - 1;
  Result := ulMsg;
end;

procedure TUsenet.New;
begin
  LastReaded := 0;
  From_[0] := #0; To_[0] := #0; Subject_[0] := #0;
  Crash := 0; Direct := 0; FileAttach := 0; FileRequest := 0;
  Hold := 0; Immediate := 0; Intransit := 0; KillSent := 0;
  Local_ := 0; Private_ := 0; ReceiptRequest := 0; Received := 0;
  Sent := 0;
  FillChar(Written, SizeOf(Written), 0);
  FillChar(Arrived, SizeOf(Arrived), 0);
  Original := 0; Reply := 0;
  Text.Clear;
end;

function TUsenet.Next(var ulMsg: LongWord): Boolean;
var
  s, p: string;
  SpacePos: Integer;
begin
  Result := False;

  if FTcp.Carrier = 0 then Exit;

  if LastReaded <> ulMsg then
  begin
    StrPCopy(szBuff, Format(CMD_STAT, [ulMsg]));
    FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
    GetResponse(szBuff, SizeOf(szBuff) - 1);
  end;

  StrPCopy(szBuff, CMD_NEXT);
  FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
  if GetResponse(szBuff, SizeOf(szBuff) - 1) = 223 then
  begin
    s := StrPas(szBuff);
    SpacePos := Pos(' ', s);
    if SpacePos > 0 then
    begin
      System.Delete(s, 1, SpacePos);
      s := TrimLeft(s);
      SpacePos := Pos(' ', s);
      if SpacePos > 0 then
        s := Copy(s, 1, SpacePos - 1);
      ulMsg := StrToIntDef(s, ulMsg);
      LastReaded := ulMsg;
      Result := True;
    end;
  end;
end;

function TUsenet.Number: LongWord;
begin
  Result := ulTotal;
end;

function TUsenet.Open(pszServer, pszGroup: PChar): Boolean;
var
  Buf: array[0..127] of Char;
  i: Word;
  s: string;
  SpacePos: Integer;
begin
  Result := False;

  if FTcp.ConnectServer(pszServer, 119) <> 0 then
  begin
    i := GetResponse(Buf, SizeOf(Buf) - 1);
    if (i = 200) or (i = 201) then
    begin
      StrPCopy(Buf, Format(CMD_GROUP, [StrPas(pszGroup)]));
      FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
      if GetResponse(Buf, SizeOf(Buf) - 1) = 211 then
      begin
        s := StrPas(Buf);
        { Response: "211 total first last group" }
        SpacePos := Pos(' ', s);
        if SpacePos > 0 then
        begin
          System.Delete(s, 1, SpacePos); s := TrimLeft(s);
          SpacePos := Pos(' ', s);
          if SpacePos > 0 then
          begin
            ulTotal := StrToIntDef(Copy(s, 1, SpacePos - 1), 0);
            System.Delete(s, 1, SpacePos); s := TrimLeft(s);
            SpacePos := Pos(' ', s);
            if SpacePos > 0 then
            begin
              ulFirst := StrToIntDef(Copy(s, 1, SpacePos - 1), 0);
              System.Delete(s, 1, SpacePos); s := TrimLeft(s);
              SpacePos := Pos(' ', s);
              if SpacePos > 0 then
                ulHighest := StrToIntDef(Copy(s, 1, SpacePos - 1), 0)
              else
                ulHighest := StrToIntDef(s, 0);
            end;
          end;
        end;
        StrCopy(NewsGroup, pszGroup);
        LastReaded := 0;
        Result := True;
      end;
    end;
  end;
end;

procedure TUsenet.Pack;
begin
  { Not supported }
end;

function TUsenet.Previous(var ulMsg: LongWord): Boolean;
var
  s: string;
  SpacePos: Integer;
begin
  Result := False;

  if FTcp.Carrier = 0 then Exit;

  if LastReaded <> ulMsg then
  begin
    StrPCopy(szBuff, Format(CMD_STAT, [ulMsg]));
    FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
    GetResponse(szBuff, SizeOf(szBuff) - 1);
  end;

  StrPCopy(szBuff, CMD_LAST);
  FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
  if GetResponse(szBuff, SizeOf(szBuff) - 1) = 223 then
  begin
    s := StrPas(szBuff);
    SpacePos := Pos(' ', s);
    if SpacePos > 0 then
    begin
      System.Delete(s, 1, SpacePos);
      s := TrimLeft(s);
      SpacePos := Pos(' ', s);
      if SpacePos > 0 then
        s := Copy(s, 1, SpacePos - 1);
      ulMsg := StrToIntDef(s, ulMsg);
      LastReaded := ulMsg;
      Result := True;
    end;
  end;

  if not Result then
  begin
    Dec(ulMsg);
    StrPCopy(szBuff, Format(CMD_STAT, [ulMsg]));
    FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
    if GetResponse(szBuff, SizeOf(szBuff) - 1) = 223 then
    begin
      LastReaded := ulMsg;
      Result := True;
    end;
  end;
end;

function TUsenet.ReadHeader(ulMsg: LongWord): Boolean;
var
  gotFrom, gotSubject: Boolean;
  Temp: array[0..127] of Char;
  s, p: string;
  NowDT: TDateTime;
  yr, mo, dy, hr, mn, sc, ms: Word;
  MonthI: Integer;
  SpacePos, AnglePos: Integer;
begin
  Result := False;

  if FTcp.Carrier = 0 then Exit;

  New;
  gotFrom := False; gotSubject := False;
  Text.Clear;

  StrPCopy(szBuff, Format(CMD_STAT, [ulMsg]));
  FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
  if GetResponse(szBuff, SizeOf(szBuff) - 1) <> 223 then Exit;

  StrPCopy(szBuff, CMD_HEAD);
  FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));
  if GetResponse(szBuff, SizeOf(szBuff) - 1) <> 221 then Exit;

  Result := True;
  NowDT := Now;
  DecodeDate(NowDT, yr, mo, dy);
  DecodeTime(NowDT, hr, mn, sc, ms);
  Arrived.Day := dy; Written.Day := dy;
  Arrived.Month := mo; Written.Month := mo;
  Arrived.Year := yr; Written.Year := yr;
  Arrived.Hour := hr; Written.Hour := hr;
  Arrived.Minute := mn; Written.Minute := mn;
  Arrived.Second := sc; Written.Second := sc;

  repeat
    szBuff[0] := #1;
    GetResponse(@szBuff[1], SizeOf(szBuff) - 2);
    if StrComp(szBuff, #1'.') <> 0 then
    begin
      if (StrLComp(szBuff, #1'From: ', 7) = 0) or (StrLComp(szBuff, #1'To: ', 5) = 0) then
        Text.Add(@szBuff[0])
      else if (StrLComp(szBuff, #1'Message-ID: ', 13) = 0) or (StrLComp(szBuff, #1'References: ', 13) = 0) then
        Text.Add(@szBuff[0]);
    end;

    { Parse From header }
    if StrLComp(@szBuff[1], 'From: ', 6) = 0 then
    begin
      s := StrPas(@szBuff[7]);
      if Pos('(', s) > 0 then
      begin
        { Format: "addr (name)" }
        SpacePos := Pos(' ', s);
        if SpacePos > 0 then
        begin
          p := Copy(s, 1, SpacePos - 1);
          s := TrimLeft(Copy(s, SpacePos + 1, Length(s)));
          if (Length(s) > 0) and (s[1] = '(') then
          begin
            System.Delete(s, 1, 1);
            SpacePos := Pos(')', s);
            if SpacePos > 0 then
              s := Copy(s, 1, SpacePos - 1);
            StrPCopy(From_, s);
            StrPCopy(FromAddress, p);
          end
          else
          begin
            s := StrPas(@szBuff[7]);
            SpacePos := Pos(' ', s);
            if SpacePos > 0 then
              StrPCopy(From_, Copy(s, 1, SpacePos - 1));
          end;
        end;
      end
      else if Pos('<', s) > 0 then
      begin
        { Format: "name <addr>" }
        AnglePos := Pos('<', s);
        p := Copy(s, AnglePos + 1, Length(s));
        SpacePos := Pos('>', p);
        if SpacePos > 0 then
          p := Copy(p, 1, SpacePos - 1);
        StrPCopy(FromAddress, p);
        s := Trim(Copy(s, 1, AnglePos - 1));
        if (Length(s) > 0) and (s[1] = '"') then
          s := Copy(s, 2, Length(s));
        if (Length(s) > 0) and (s[Length(s)] = '"') then
          s := Copy(s, 1, Length(s) - 1);
        StrPCopy(From_, s);
      end;
      gotFrom := True;
    end
    { Parse To header }
    else if StrLComp(@szBuff[1], 'To: ', 4) = 0 then
    begin
      s := StrPas(@szBuff[5]);
      if Pos('(', s) > 0 then
      begin
        SpacePos := Pos(' ', s);
        if SpacePos > 0 then
        begin
          p := Copy(s, 1, SpacePos - 1);
          s := TrimLeft(Copy(s, SpacePos + 1, Length(s)));
          if (Length(s) > 0) and (s[1] = '(') then
          begin
            System.Delete(s, 1, 1);
            SpacePos := Pos(')', s);
            if SpacePos > 0 then
              s := Copy(s, 1, SpacePos - 1);
            StrPCopy(To_, s);
            StrPCopy(ToAddress, p);
          end
          else
          begin
            s := StrPas(@szBuff[5]);
            SpacePos := Pos(' ', s);
            if SpacePos > 0 then
              StrPCopy(To_, Copy(s, 1, SpacePos - 1));
          end;
        end;
      end
      else if Pos('<', s) > 0 then
      begin
        AnglePos := Pos('<', s);
        p := Copy(s, AnglePos + 1, Length(s));
        SpacePos := Pos('>', p);
        if SpacePos > 0 then
          p := Copy(p, 1, SpacePos - 1);
        StrPCopy(ToAddress, p);
        s := Trim(Copy(s, 1, AnglePos - 1));
        if (Length(s) > 0) and (s[1] = '"') then
          s := Copy(s, 2, Length(s));
        if (Length(s) > 0) and (s[Length(s)] = '"') then
          s := Copy(s, 1, Length(s) - 1);
        StrPCopy(To_, s);
      end;
    end
    else if StrLComp(@szBuff[1], 'Subject: ', 9) = 0 then
    begin
      s := StrPas(@szBuff[10]);
      if Length(s) >= SizeOf(Subject_) then
        SetLength(s, SizeOf(Subject_) - 1);
      StrPCopy(Subject_, s);
      gotSubject := True;
    end
    else if StrLComp(@szBuff[1], 'Date: ', 6) = 0 then
    begin
      s := StrPas(@szBuff[7]);
      { Skip day name }
      if (Length(s) > 0) and not (s[1] in ['0'..'9']) then
      begin
        SpacePos := Pos(' ', s);
        if SpacePos > 0 then System.Delete(s, 1, SpacePos);
        s := TrimLeft(s);
      end;
      SpacePos := Pos(' ', s);
      if SpacePos > 0 then
      begin
        Written.Day := StrToIntDef(Copy(s, 1, SpacePos - 1), 0);
        System.Delete(s, 1, SpacePos); s := TrimLeft(s);
        SpacePos := Pos(' ', s);
        if SpacePos > 0 then
        begin
          p := Copy(s, 1, SpacePos - 1);
          for MonthI := 0 to 11 do
            if SameText(Copy(MONTHS[MonthI], 1, 3), Copy(p, 1, 3)) then
            begin Written.Month := MonthI + 1; Break; end;
          System.Delete(s, 1, SpacePos); s := TrimLeft(s);
          SpacePos := Pos(' ', s);
          if SpacePos > 0 then
          begin
            Written.Year := StrToIntDef(Copy(s, 1, SpacePos - 1), 0);
            if (Written.Year >= 80) and (Written.Year < 100) then Written.Year := Written.Year + 1900
            else if Written.Year < 80 then Written.Year := Written.Year + 2000;
            System.Delete(s, 1, SpacePos); s := TrimLeft(s);
            if Length(s) >= 5 then
            begin
              Written.Hour := (Ord(s[1]) - Ord('0')) * 10 + (Ord(s[2]) - Ord('0'));
              if s[3] = ':' then System.Delete(s, 1, 3) else System.Delete(s, 1, 2);
              Written.Minute := (Ord(s[1]) - Ord('0')) * 10 + (Ord(s[2]) - Ord('0'));
              System.Delete(s, 1, 2);
              if (Length(s) > 0) and (s[1] = ':') then
              begin
                System.Delete(s, 1, 1);
                if Length(s) >= 2 then
                  Written.Second := (Ord(s[1]) - Ord('0')) * 10 + (Ord(s[2]) - Ord('0'));
              end;
            end;
          end;
        end;
      end;
    end;
  until StrComp(szBuff, #1'.') = 0;

  Id := ulMsg;
  LastReaded := ulMsg;

  if (not gotFrom) or (not gotSubject) then
    Result := False;
end;

function TUsenet.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function TUsenet.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  SkipNext: Boolean;
  i, nReaded, nCol: SmallInt;
  NowDT: TDateTime;
  yr, mo, dy, hr, mn, sc, ms: Word;
  s, p: string;
  MonthI, SpacePos: Integer;
begin
  Result := False;
  MsgText.Clear;

  if FTcp = nil then Exit;

  New;
  StrPCopy(szBuff, Format(CMD_ARTICLE, [ulMsg]));
  FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));

  if GetResponse(szBuff, SizeOf(szBuff) - 1) <> 220 then Exit;

  Result := True;
  NowDT := Now;
  DecodeDate(NowDT, yr, mo, dy);
  DecodeTime(NowDT, hr, mn, sc, ms);
  Arrived.Day := dy; Written.Day := dy;
  Arrived.Month := mo; Written.Month := mo;
  Arrived.Year := yr; Written.Year := yr;
  Arrived.Hour := hr; Written.Hour := hr;
  Arrived.Minute := mn; Written.Minute := mn;
  Arrived.Second := sc; Written.Second := sc;

  { Read headers }
  repeat
    szBuff[0] := #1;
    GetResponse(@szBuff[1], SizeOf(szBuff) - 2);
    if (szBuff[1] <> #0) and (StrComp(szBuff, '.') <> 0) then
      MsgText.Add(@szBuff[0]);

    if StrLComp(@szBuff[1], 'From: ', 6) = 0 then
    begin
      s := StrPas(@szBuff[7]);
      if Length(s) >= SizeOf(From_) then SetLength(s, SizeOf(From_) - 1);
      StrPCopy(From_, s);
    end
    else if StrLComp(@szBuff[1], 'Subject: ', 9) = 0 then
    begin
      s := StrPas(@szBuff[10]);
      if Length(s) >= SizeOf(Subject_) then SetLength(s, SizeOf(Subject_) - 1);
      StrPCopy(Subject_, s);
    end
    else if StrLComp(@szBuff[1], 'Date: ', 6) = 0 then
    begin
      s := StrPas(@szBuff[7]);
      if (Length(s) > 0) and not (s[1] in ['0'..'9']) then
      begin
        SpacePos := Pos(' ', s);
        if SpacePos > 0 then System.Delete(s, 1, SpacePos);
        s := TrimLeft(s);
      end;
      SpacePos := Pos(' ', s);
      if SpacePos > 0 then
      begin
        Written.Day := StrToIntDef(Copy(s, 1, SpacePos - 1), 0);
        System.Delete(s, 1, SpacePos); s := TrimLeft(s);
        SpacePos := Pos(' ', s);
        if SpacePos > 0 then
        begin
          p := Copy(s, 1, SpacePos - 1);
          for MonthI := 0 to 11 do
            if SameText(Copy(MONTHS[MonthI], 1, 3), Copy(p, 1, 3)) then
            begin Written.Month := MonthI + 1; Break; end;
          System.Delete(s, 1, SpacePos); s := TrimLeft(s);
          SpacePos := Pos(' ', s);
          if SpacePos > 0 then
          begin
            Written.Year := StrToIntDef(Copy(s, 1, SpacePos - 1), 0);
            if (Written.Year >= 80) and (Written.Year < 100) then Written.Year := Written.Year + 1900
            else if Written.Year < 80 then Written.Year := Written.Year + 2000;
            System.Delete(s, 1, SpacePos); s := TrimLeft(s);
            if Length(s) >= 5 then
            begin
              Written.Hour := (Ord(s[1]) - Ord('0')) * 10 + (Ord(s[2]) - Ord('0'));
              if s[3] = ':' then System.Delete(s, 1, 3) else System.Delete(s, 1, 2);
              Written.Minute := (Ord(s[1]) - Ord('0')) * 10 + (Ord(s[2]) - Ord('0'));
              System.Delete(s, 1, 2);
              if (Length(s) > 0) and (s[1] = ':') then
              begin
                System.Delete(s, 1, 1);
                if Length(s) >= 2 then
                  Written.Second := (Ord(s[1]) - Ord('0')) * 10 + (Ord(s[2]) - Ord('0'));
              end;
            end;
          end;
        end;
      end;
    end;
  until (szBuff[1] = #0) or (StrComp(szBuff, '.') = 0);

  { Read body }
  Id := ulMsg;
  LastReaded := ulMsg;
  pLine := @szLine[0];
  nCol := 0;
  SkipNext := False;

  repeat
    GetResponse(szBuff, SizeOf(szBuff) - 1);
    nReaded := StrLen(szBuff);

    pBuff := @szBuff[0];
    for i := 0 to nReaded - 1 do
    begin
      if pBuff^ <> #10 then
      begin
        pLine^ := pBuff^;
        Inc(pLine);
        Inc(nCol);
        if nCol >= nWidth then
        begin
          pLine^ := #0;
          if StrScan(szLine, ' ') <> nil then
          begin
            while (nCol > 1) and (pLine^ <> ' ') do begin Dec(nCol); Dec(pLine); end;
            if nCol > 0 then begin while pLine^ = ' ' do Inc(pLine); StrCopy(szWrp, pLine); end;
            pLine^ := #0;
          end
          else
            szWrp[0] := #0;
          MsgText.Add(@szLine[0]);
          StrCopy(szLine, szWrp);
          pLine := StrEnd(szLine);
          nCol := StrLen(szLine);
          SkipNext := True;
        end;
      end;
      Inc(pBuff);
    end;
    pLine^ := #0;
    if (pLine > @szLine[0]) and SkipNext then
    begin
      Dec(pLine);
      while (pLine > @szLine[0]) and (pLine^ = ' ') do begin pLine^ := #0; Dec(pLine); end;
      if (pLine > @szLine[0]) and (StrComp(szLine, '.') <> 0) then
        MsgText.Add(@szLine[0]);
    end
    else if not SkipNext then
    begin
      if StrComp(szLine, '.') <> 0 then
        MsgText.Add(@szLine[0]);
    end;
    SkipNext := False;
    pLine := @szLine[0];
    nCol := 0;
  until StrComp(szBuff, '.') = 0;
end;

procedure TUsenet.SetHWM(ulMsg: LongWord);
begin
  { Not supported }
end;

function TUsenet.UidToMsgn(ulMsg: LongWord): LongWord;
begin
  if (ulMsg >= Lowest) and (ulMsg <= Highest) then
    ulMsg := ulMsg - Lowest + 1;
  Result := ulMsg;
end;

procedure TUsenet.UnLock;
begin
  { Not supported }
end;

function TUsenet.WriteHeader(ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

end.
