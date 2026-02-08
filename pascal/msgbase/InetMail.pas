{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of inetmail.cpp
  POP3/SMTP Internet mail message base
}

unit InetMail;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Collect, Struc299, Tcpip, MsgBase;

type
  TInetMail = class(TMsgBase)
  private
    FTcp: TTcpip;
    TotalMsgs: LongWord;
    LastReaded: LongWord;

    function GetResponse(pszResponse: PChar; usMaxLen: Word): Word;
    function GetLine_(pszResponse: PChar; usMaxLen: Word): Word;

  public
    HostName: array[0..63] of Char;
    SMTPHostName: array[0..63] of Char;
    Error: array[0..127] of Char;

    constructor Create; overload;
    constructor CreateOpen(pszServer, pszUser, pszPwd: PChar);
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
    function Open(pszServer, pszUser, pszPwd: PChar): Boolean;
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
  MONTHS: array[0..11] of string = (
    'January', 'February', 'March', 'April', 'May', 'Juni',
    'July', 'August', 'September', 'October', 'November', 'December'
  );

constructor TInetMail.Create;
begin
  inherited Create;
  FTcp := TTcpip.Create;
  TotalMsgs := 0;
  LastReaded := 0;
  StrPCopy(HostName, 'unknown.host');
  FillChar(SMTPHostName, SizeOf(SMTPHostName), 0);
  FillChar(Error, SizeOf(Error), 0);
end;

constructor TInetMail.CreateOpen(pszServer, pszUser, pszPwd: PChar);
begin
  Create;
  Open(pszServer, pszUser, pszPwd);
end;

destructor TInetMail.Destroy;
begin
  FTcp.Free;
  inherited Destroy;
end;

function TInetMail.GetResponse(pszResponse: PChar; usMaxLen: Word): Word;
var
  Len: Word;
  c: Char;
  pResp: PChar;
begin
  Result := 0;

  repeat
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
    until (c = #13) or (FTcp.Carrier = 0);

    pResp^ := #0;
    if pszResponse[0] = '+' then
    begin
      Result := 1; { TRUE }
      Exit;
    end
    else if pszResponse[0] = '-' then
    begin
      Result := 0; { FALSE }
      Exit;
    end
    else if pszResponse[3] = ' ' then
    begin
      Result := StrToIntDef(Copy(StrPas(pszResponse), 1, 3), 0);
      Exit;
    end;
    { else: continuation line, loop again }
  until False;
end;

function TInetMail.GetLine_(pszResponse: PChar; usMaxLen: Word): Word;
var
  Len: Word;
  c: Char;
  pResp: PChar;
begin
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
  until (c = #13) or (FTcp.Carrier = 0);

  pResp^ := #0;
  if pszResponse[0] = '+' then
    Result := 1
  else if pszResponse[0] = '-' then
    Result := 0
  else if pszResponse[3] = ' ' then
    Result := StrToIntDef(Copy(StrPas(pszResponse), 1, 3), 0)
  else
    Result := 0;
end;

function TInetMail.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TInetMail.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Move(AMsgBase.FromAddress, FromAddress, SizeOf(FromAddress));
  Move(AMsgBase.ToAddress, ToAddress, SizeOf(ToAddress));
  Result := AddText(AMsgBase.Text);
end;

function TInetMail.AddText(var MsgText: TCollection): Boolean;
var
  GotFrom, GotSubject, GotTo: Boolean;
  Buf: array[0..127] of Char;
  pszText: PChar;
  OldTcp, SmtpTcp: TTcpip;
  MonthIdx: Integer;
begin
  Result := False;
  GotFrom := False; GotSubject := False; GotTo := False;

  OldTcp := FTcp;
  SmtpTcp := TTcpip.Create;
  FTcp := SmtpTcp;
  try
    if FTcp.ConnectServer(SMTPHostName, 25) <> 0 then
    begin
      if GetResponse(Buf, SizeOf(Buf) - 1) = 220 then
      begin
        StrPCopy(Buf, Format('HELO %s'#13#10, [StrPas(HostName)]));
        FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
        GetResponse(Buf, SizeOf(Buf) - 1);

        if Pos('@', StrPas(From_)) > 0 then
          StrPCopy(Buf, Format('MAIL FROM:<%s>'#13#10, [StrPas(From_)]))
        else
          StrPCopy(Buf, Format('MAIL FROM:<%s>'#13#10, [StrPas(FromAddress)]));
        FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));

        if GetResponse(Buf, SizeOf(Buf) - 1) = 250 then
        begin
          if Pos('@', StrPas(To_)) > 0 then
            StrPCopy(Buf, Format('RCPT TO:<%s>'#13#10, [StrPas(To_)]))
          else
            StrPCopy(Buf, Format('RCPT TO:<%s>'#13#10, [StrPas(ToAddress)]));
          FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));

          if GetResponse(Buf, SizeOf(Buf) - 1) = 250 then
          begin
            StrPCopy(Buf, 'DATA'#13#10);
            FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));

            if GetResponse(Buf, SizeOf(Buf) - 1) = 354 then
            begin
              { Send headers from kludges }
              pszText := PChar(MsgText.First);
              while pszText <> nil do
              begin
                if StrLComp(pszText, #1'From: ', 7) = 0 then
                begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotFrom := True; end
                else if StrLComp(pszText, #1'To: ', 5) = 0 then
                begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotTo := True; end
                else if StrLComp(pszText, #1'Subject: ', 10) = 0 then
                begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); GotSubject := True; end
                else if StrLComp(pszText, #1'X-Mailreader: ', 15) = 0 then
                begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); end
                else if StrLComp(pszText, #1'In-Reply-To: ', 14) = 0 then
                begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); end
                else if StrLComp(pszText, #1'Sender: ', 9) = 0 then
                begin FTcp.BufferBytes(PByte(@pszText[1]), StrLen(pszText) - 1); FTcp.BufferBytes(PByte(PChar(#13#10)), 2); end;
                pszText := PChar(MsgText.Next);
              end;

              { Generate missing headers }
              if not GotFrom then
              begin
                if Pos('@', StrPas(From_)) > 0 then
                  StrPCopy(Buf, Format('From: %s'#13#10, [StrPas(From_)]))
                else
                  StrPCopy(Buf, Format('From: %s <%s>'#13#10, [StrPas(From_), StrPas(FromAddress)]));
                FTcp.BufferBytes(PByte(@Buf[0]), StrLen(Buf));
              end;
              if not GotTo then
              begin
                if Pos('@', StrPas(To_)) > 0 then
                  StrPCopy(Buf, Format('To: %s'#13#10, [StrPas(To_)]))
                else
                  StrPCopy(Buf, Format('To: %s <%s>'#13#10, [StrPas(To_), StrPas(ToAddress)]));
                FTcp.BufferBytes(PByte(@Buf[0]), StrLen(Buf));
              end;
              if not GotSubject then
              begin
                StrPCopy(Buf, Format('Subject: %s'#13#10, [StrPas(Subject_)]));
                FTcp.BufferBytes(PByte(@Buf[0]), StrLen(Buf));
              end;

              MonthIdx := Written.Month;
              if (MonthIdx < 1) or (MonthIdx > 12) then MonthIdx := 1;
              StrPCopy(Buf, Format('Date: %d %s %d %02d:%02d:%02d GMT'#13#10,
                [Written.Day, Copy(MONTHS[MonthIdx - 1], 1, 3), Written.Year,
                 Written.Hour, Written.Minute, Written.Second]));
              FTcp.BufferBytes(PByte(@Buf[0]), StrLen(Buf));

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

              StrPCopy(Buf, '.'#13#10);
              FTcp.BufferBytes(PByte(@Buf[0]), StrLen(Buf));
              FTcp.UnbufferBytes;

              if GetResponse(Buf, SizeOf(Buf) - 1) = 250 then
                Result := True;
            end;
          end;
        end;

        StrPCopy(Buf, 'QUIT'#13#10);
        FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
        GetResponse(Buf, SizeOf(Buf) - 1);
      end;
    end;
  finally
    SmtpTcp.Free;
  end;
  FTcp := OldTcp;
end;

procedure TInetMail.Close;
var
  Buf: array[0..49] of Char;
begin
  StrPCopy(Buf, 'QUIT'#13#10);
  FTcp.SendBytes(PByte(@Buf[0]), 6);
  GetResponse(Buf, SizeOf(Buf) - 1);
  TotalMsgs := 0;
end;

function TInetMail.Delete(ulMsg: LongWord): Boolean;
var
  Buf: array[0..49] of Char;
begin
  StrPCopy(Buf, Format('DELE %u'#13#10, [ulMsg]));
  FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
  Result := GetResponse(Buf, SizeOf(Buf) - 1) <> 0;
end;

function TInetMail.GetHWM(var ulMsg: LongWord): Boolean;
begin
  ulMsg := 0;
  Result := False;
end;

function TInetMail.Highest: LongWord;
begin
  Result := TotalMsgs;
end;

function TInetMail.Lock(ulTimeout: LongWord): Boolean;
begin
  Result := True;
end;

function TInetMail.Lowest: LongWord;
begin
  Result := 1;
end;

function TInetMail.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TInetMail.New;
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

function TInetMail.Next(var ulMsg: LongWord): Boolean;
begin
  Result := False;
  if ulMsg < TotalMsgs then
  begin
    Inc(ulMsg);
    Result := True;
  end;
end;

function TInetMail.Number: LongWord;
begin
  Result := TotalMsgs;
end;

function TInetMail.Open(pszServer, pszUser, pszPwd: PChar): Boolean;
var
  Buf: array[0..127] of Char;
  s: string;
  SpacePos: Integer;
begin
  Result := False;

  if FTcp.ConnectServer(pszServer, 110) <> 0 then
  begin
    if GetResponse(Buf, SizeOf(Buf) - 1) <> 0 then
    begin
      StrPCopy(Buf, Format('USER %s'#13#10, [StrPas(pszUser)]));
      FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
      if GetResponse(Buf, SizeOf(Buf) - 1) <> 0 then
      begin
        StrPCopy(Buf, Format('PASS %s'#13#10, [StrPas(pszPwd)]));
        FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
        if GetResponse(Buf, SizeOf(Buf) - 1) <> 0 then
        begin
          StrPCopy(Buf, 'STAT'#13#10);
          FTcp.SendBytes(PByte(@Buf[0]), StrLen(Buf));
          if GetResponse(Buf, SizeOf(Buf) - 1) <> 0 then
          begin
            s := StrPas(Buf);
            { Response: "+OK nn mm" - extract message count }
            SpacePos := Pos(' ', s);
            if SpacePos > 0 then
            begin
              System.Delete(s, 1, SpacePos);
              s := Trim(s);
              SpacePos := Pos(' ', s);
              if SpacePos > 0 then
                s := Copy(s, 1, SpacePos - 1);
              TotalMsgs := StrToIntDef(s, 0);
            end;
          end;
          Result := True;
          LastReaded := 0;
        end;
      end;
    end;
  end;
end;

procedure TInetMail.Pack;
begin
  { Not supported }
end;

function TInetMail.Previous(var ulMsg: LongWord): Boolean;
begin
  Result := False;
  if ulMsg > 1 then
  begin
    Dec(ulMsg);
    Result := True;
  end;
end;

function TInetMail.ReadHeader(ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

function TInetMail.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function TInetMail.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  SkipNext: Boolean;
  i, nReaded, nCol: SmallInt;
  NowDT: TDateTime;
  yr, mo, dy, hr, mn, sc, ms: Word;
  p, s: string;
  MonthI: Integer;
  SpacePos: Integer;
begin
  Result := False;
  From_[0] := #0; To_[0] := #0; Subject_[0] := #0;
  MsgText.Clear;

  if FTcp = nil then Exit;

  New;
  StrPCopy(szBuff, Format('RETR %u'#13#10, [ulMsg]));
  FTcp.SendBytes(PByte(@szBuff[0]), StrLen(szBuff));

  if GetResponse(szBuff, SizeOf(szBuff) - 1) <> 0 then
  begin
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
      GetLine_(@szBuff[1], SizeOf(szBuff) - 2);
      if (szBuff[1] <> #0) and (StrComp(szBuff, '.') <> 0) then
        Text.Add(@szBuff[0]);

      if StrLComp(@szBuff[1], 'From: ', 6) = 0 then
      begin
        s := StrPas(@szBuff[7]);
        if Length(s) >= SizeOf(From_) then
          SetLength(s, SizeOf(From_) - 1);
        StrPCopy(From_, s);
      end
      else if StrLComp(@szBuff[1], 'Subject: ', 9) = 0 then
      begin
        s := StrPas(@szBuff[10]);
        if Length(s) >= SizeOf(Subject_) then
          SetLength(s, SizeOf(Subject_) - 1);
        StrPCopy(Subject_, s);
      end
      else if StrLComp(@szBuff[1], 'Date: ', 6) = 0 then
      begin
        { Parse RFC date: "dd Mon yyyy hh:mm:ss" or "Day, dd Mon yyyy..." }
        s := StrPas(@szBuff[7]);
        { Skip day name if present }
        if (Length(s) > 0) and not (s[1] in ['0'..'9']) then
        begin
          SpacePos := Pos(' ', s);
          if SpacePos > 0 then
            System.Delete(s, 1, SpacePos);
          s := TrimLeft(s);
        end;
        { Now: "dd Mon yyyy hh:mm:ss..." }
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
              begin
                Written.Month := MonthI + 1;
                Break;
              end;
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
      GetLine_(szBuff, SizeOf(szBuff) - 1);
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
            while (nCol > 1) and (pLine^ <> ' ') do begin Dec(nCol); Dec(pLine); end;
            if nCol > 0 then begin while pLine^ = ' ' do Inc(pLine); StrCopy(szWrp, pLine); end;
            pLine^ := #0;
            MsgText.Add(@szLine[0], StrLen(szLine) + 1);
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
          MsgText.Add(@szLine[0], StrLen(szLine) + 1);
      end
      else if not SkipNext then
      begin
        if StrComp(szLine, '.') <> 0 then
          MsgText.Add(@szLine[0], StrLen(szLine) + 1);
      end;
      SkipNext := False;
      pLine := @szLine[0];
      nCol := 0;
    until StrComp(szBuff, '.') = 0;
  end;
end;

procedure TInetMail.SetHWM(ulMsg: LongWord);
begin
  { Not supported }
end;

function TInetMail.UidToMsgn(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TInetMail.UnLock;
begin
  { Not supported }
end;

function TInetMail.WriteHeader(ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

end.
