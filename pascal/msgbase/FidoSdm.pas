{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of fidosdm.cpp
  FidoNet *.MSG (stored message) format message base
}

unit FidoSdm;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, DateUtils, Collect, Struc299, MsgBase;

type
  PMSGINDEX = ^TMSGINDEX;
  TMSGINDEX = packed record
    Number: LongWord;
    FileName: array[0..15] of Char;
  end;

  TFidoSdm = class(TMsgBase)
  private
    FBasePath: string;
    FLastFile: string;
    FTotalMsgs: LongWord;
    FMsgHdr: FIDOMSG;
    FIndex: TCollection;

    procedure ParseFidoDate(const DateStr: PChar; var D: MDATE);
    procedure SetFlagsFromAttr(Attr: Word);
    function AttrFromFlags: Word;

  public
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
    function Lock(ulTimeout: LongWord = 0): Boolean; override;
    function Lowest: LongWord; override;
    function MsgnToUid(ulMsg: LongWord): LongWord; override;
    procedure New; override;
    function Next(var ulMsg: LongWord): Boolean; override;
    function Number: LongWord; override;
    function Open(const AName: string): Boolean;
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

function sscanf6D(const s: string; var tz, tn, t_o, fz, fn, f_o: Integer): Boolean; forward;

const
  FidoMonths: array[0..11] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );
  FidoDays: array[0..6] of string = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  );

procedure TFidoSdm.ParseFidoDate(const DateStr: PChar; var D: MDATE);
var
  s: string;
  HasDayName: Boolean;
  dd, yy, hr, mn, sc, i: Integer;
  mm: string;
  Parts: TStringList;
begin
  s := StrPas(DateStr);
  HasDayName := False;

  { Check if date starts with day name like "Mon " }
  for i := 0 to 6 do
    if Copy(s, 1, 3) = FidoDays[i] then
    begin
      HasDayName := True;
      Break;
    end;

  if HasDayName then
    System.Delete(s, 1, 4); { Remove "Mon " prefix }

  { Parse: "dd Mon yy  hh:mm:ss" or "dd Mon yy hh:mm" }
  s := StringReplace(s, '  ', ' ', [rfReplaceAll]);
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ' ';
    Parts.StrictDelimiter := False;
    Parts.DelimitedText := s;

    dd := 0; yy := 0; hr := 0; mn := 0; sc := 0;
    mm := '';

    if Parts.Count >= 3 then
    begin
      dd := StrToIntDef(Parts[0], 0);
      mm := Parts[1];
      yy := StrToIntDef(Parts[2], 0);
    end;
    if Parts.Count >= 4 then
    begin
      { Parse "hh:mm:ss" or "hh:mm" }
      s := Parts[3];
      hr := StrToIntDef(Copy(s, 1, 2), 0);
      mn := StrToIntDef(Copy(s, 4, 2), 0);
      if Length(s) >= 8 then
        sc := StrToIntDef(Copy(s, 7, 2), 0);
    end;

    D.Day := dd;
    D.Month := 1;
    for i := 0 to 11 do
      if SameText(FidoMonths[i], Copy(mm, 1, 3)) then
      begin
        D.Month := i + 1;
        Break;
      end;
    if (D.Month < 1) or (D.Month > 12) then
      D.Month := 1;
    D.Year := yy + 1900;
    if D.Year < 1990 then
      D.Year := D.Year + 100;
    D.Hour := hr;
    D.Minute := mn;
    D.Second := sc;
  finally
    Parts.Free;
  end;
end;

procedure TFidoSdm.SetFlagsFromAttr(Attr: Word);
begin
  Crash := Ord(Attr and MSGCRASH <> 0);
  FileAttach := Ord(Attr and MSGFILE <> 0);
  FileRequest := Ord(Attr and MSGFRQ <> 0);
  Hold := Ord(Attr and MSGHOLD <> 0);
  KillSent := Ord(Attr and MSGKILL <> 0);
  Local_ := Ord(Attr and MSGLOCAL <> 0);
  Private_ := Ord(Attr and MSGPRIVATE <> 0);
  ReceiptRequest := Ord(Attr and MSGRRQ <> 0);
  Received := Ord(Attr and MSGREAD <> 0);
  Sent := Ord(Attr and MSGSENT <> 0);
end;

function TFidoSdm.AttrFromFlags: Word;
begin
  Result := 0;
  if Crash <> 0 then Result := Result or MSGCRASH;
  if FileAttach <> 0 then Result := Result or MSGFILE;
  if FileRequest <> 0 then Result := Result or MSGFRQ;
  if Hold <> 0 then Result := Result or MSGHOLD;
  if KillSent <> 0 then Result := Result or MSGKILL;
  if Local_ <> 0 then Result := Result or MSGLOCAL;
  if Private_ <> 0 then Result := Result or MSGPRIVATE;
  if ReceiptRequest <> 0 then Result := Result or MSGRRQ;
  if Received <> 0 then Result := Result or MSGREAD;
  if Sent <> 0 then Result := Result or MSGSENT;
end;

constructor TFidoSdm.Create;
begin
  inherited Create;
  FIndex := TCollection.Create;
  FTotalMsgs := 0;
end;

constructor TFidoSdm.CreateOpen(const AName: string);
begin
  Create;
  Open(AName);
end;

destructor TFidoSdm.Destroy;
begin
  FIndex.Free;
  inherited Destroy;
end;

function TFidoSdm.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TFidoSdm.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Result := AddText(AMsgBase.Text);
end;

function TFidoSdm.AddText(var MsgText: TCollection): Boolean;
var
  fs: TFileStream;
  pszText, pszAddress: PChar;
  MsgIdx: TMSGINDEX;
  Temp: string;
  cr: Char;
  nul: Byte;
begin
  Result := False;

  { Determine next message number }
  MsgIdx.Number := Highest + 1;
  if MsgIdx.Number = 1 then
  begin
    { Check if echomail (contains PATH or SEEN-BY) - skip msg 1 }
    pszText := PChar(MsgText.First);
    while pszText <> nil do
    begin
      if (StrLComp(pszText, #1'PATH', 5) = 0) or
         (StrLComp(pszText, 'SEEN-BY:', 8) = 0) then
      begin
        Inc(MsgIdx.Number);
        Break;
      end;
      pszText := PChar(MsgText.Next);
    end;
  end;
  StrPCopy(MsgIdx.FileName, Format('%d.msg', [MsgIdx.Number]));

  { Build FIDOMSG header }
  FillChar(FMsgHdr, SizeOf(FIDOMSG), 0);

  { Parse FromAddress for net/node }
  pszAddress := FromAddress;
  if StrScan(pszAddress, ':') <> nil then
    pszAddress := StrScan(pszAddress, ':') + 1;
  if StrScan(pszAddress, '/') <> nil then
  begin
    FMsgHdr.OrigNet := StrToIntDef(Copy(StrPas(pszAddress), 1, Pos('/', StrPas(pszAddress)) - 1), 0);
    pszAddress := StrScan(pszAddress, '/') + 1;
  end;
  FMsgHdr.OrigNode := StrToIntDef(StrPas(pszAddress), 0);

  { Parse ToAddress for net/node }
  pszAddress := ToAddress;
  if StrScan(pszAddress, ':') <> nil then
    pszAddress := StrScan(pszAddress, ':') + 1;
  if StrScan(pszAddress, '/') <> nil then
  begin
    FMsgHdr.DestNet := StrToIntDef(Copy(StrPas(pszAddress), 1, Pos('/', StrPas(pszAddress)) - 1), 0);
    pszAddress := StrScan(pszAddress, '/') + 1;
  end;
  FMsgHdr.DestNode := StrToIntDef(StrPas(pszAddress), 0);

  FMsgHdr.Attrib := AttrFromFlags;
  FMsgHdr.Reply := Word(Original);
  FMsgHdr.Up := Word(Reply);

  Move(From_, FMsgHdr.From_, SizeOf(FMsgHdr.From_));
  Move(To_, FMsgHdr.To_, SizeOf(FMsgHdr.To_));
  Move(Subject_, FMsgHdr.Subject_, SizeOf(FMsgHdr.Subject_));

  { Format date }
  if (Written.Month >= 1) and (Written.Month <= 12) then
    StrPCopy(FMsgHdr.Date_, Format('%2d %s %02d  %02d:%02d:%02d',
      [Written.Day, FidoMonths[Written.Month - 1], Written.Year mod 100,
       Written.Hour, Written.Minute, Written.Second]));

  Temp := FBasePath + StrPas(MsgIdx.FileName);
  try
    fs := TFileStream.Create(Temp, fmCreate);
    try
      fs.Write(FMsgHdr, SizeOf(FIDOMSG));

      cr := #13;
      nul := 0;
      pszText := PChar(MsgText.First);
      while pszText <> nil do
      begin
        fs.Write(pszText^, StrLen(pszText));
        fs.Write(cr, 1);
        pszText := PChar(MsgText.Next);
      end;
      fs.Write(nul, 1);

      FIndex.Add(@MsgIdx, SizeOf(TMSGINDEX));
      Inc(FTotalMsgs);
      Result := True;
    finally
      fs.Free;
    end;
  except
  end;
end;

procedure TFidoSdm.Close;
begin
  Id := 0;
  FIndex.Clear;
end;

function TFidoSdm.Delete(ulMsg: LongWord): Boolean;
var
  pIdx: PMSGINDEX;
  Temp: string;
begin
  Result := False;
  pIdx := PMSGINDEX(FIndex.First);
  while pIdx <> nil do
  begin
    if pIdx^.Number = ulMsg then
    begin
      Temp := FBasePath + StrPas(pIdx^.FileName);
      SysUtils.DeleteFile(Temp);
      FIndex.Remove;
      Dec(FTotalMsgs);
      Result := True;
      Exit;
    end;
    pIdx := PMSGINDEX(FIndex.Next);
  end;
end;

function TFidoSdm.GetHWM(var ulMsg: LongWord): Boolean;
var
  fs: TFileStream;
  Hdr: FIDOMSG;
  Temp: string;
begin
  ulMsg := 1;
  Temp := FBasePath + '1.msg';
  if FileExists(Temp) then
  begin
    try
      fs := TFileStream.Create(Temp, fmOpenRead or fmShareDenyNone);
      try
        fs.Read(Hdr, SizeOf(FIDOMSG));
        ulMsg := Hdr.Up;
      finally
        fs.Free;
      end;
    except
    end;
  end;
  Result := True;
end;

function TFidoSdm.Highest: LongWord;
var
  pIdx: PMSGINDEX;
begin
  Result := 0;
  pIdx := PMSGINDEX(FIndex.Last);
  if pIdx <> nil then
    Result := pIdx^.Number;
end;

function TFidoSdm.Lock(ulTimeout: LongWord): Boolean;
begin
  Result := True;
end;

function TFidoSdm.Lowest: LongWord;
var
  pIdx: PMSGINDEX;
begin
  Result := 0;
  pIdx := PMSGINDEX(FIndex.First);
  if pIdx <> nil then
    Result := pIdx^.Number;
end;

function TFidoSdm.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TFidoSdm.New;
begin
  From_[0] := #0;
  To_[0] := #0;
  Subject_[0] := #0;
  Crash := 0; Direct := 0; FileAttach := 0; FileRequest := 0;
  Hold := 0; Immediate := 0; Intransit := 0; KillSent := 0;
  Local_ := 0; Private_ := 0; ReceiptRequest := 0; Received := 0;
  Sent := 0;
  FillChar(Written, SizeOf(Written), 0);
  Written.Month := 1;
  FillChar(Arrived, SizeOf(Arrived), 0);
  Arrived.Month := 1;
  Original := 0;
  Reply := 0;
  Text.Clear;
end;

function TFidoSdm.Next(var ulMsg: LongWord): Boolean;
var
  pIdx: PMSGINDEX;
  Found: Boolean;
begin
  Result := False;
  Found := False;

  { First try: find current and return next }
  pIdx := PMSGINDEX(FIndex.First);
  while pIdx <> nil do
  begin
    if pIdx^.Number = ulMsg then
    begin
      Found := True;
      Break;
    end;
    pIdx := PMSGINDEX(FIndex.Next);
  end;

  if Found then
  begin
    pIdx := PMSGINDEX(FIndex.Next);
    if pIdx <> nil then
    begin
      ulMsg := pIdx^.Number;
      Result := True;
    end;
  end
  else
  begin
    { Find first message greater than ulMsg }
    pIdx := PMSGINDEX(FIndex.First);
    while pIdx <> nil do
    begin
      if pIdx^.Number > ulMsg then
      begin
        ulMsg := pIdx^.Number;
        Result := True;
        Break;
      end;
      pIdx := PMSGINDEX(FIndex.Next);
    end;
  end;
end;

function TFidoSdm.Number: LongWord;
begin
  Result := FTotalMsgs;
end;

function TFidoSdm.Open(const AName: string): Boolean;
var
  SR: TSearchRec;
  Dir: string;
  MsgIdx, CheckIdx: TMSGINDEX;
  pCheck: PMSGINDEX;
  Inserted: Boolean;
begin
  Result := False;
  FTotalMsgs := 0;
  FIndex.Clear;

  Dir := ExcludeTrailingPathDelimiter(AName);

  if FindFirst(Dir + PathDelim + '*.msg', faAnyFile, SR) = 0 then
  begin
    Result := True;
    repeat
      MsgIdx.Number := StrToIntDef(Copy(SR.Name, 1, Pos('.', SR.Name) - 1), 0);
      if MsgIdx.Number > 0 then
      begin
        StrPCopy(MsgIdx.FileName, SR.Name);

        { Sorted insert by message number }
        pCheck := PMSGINDEX(FIndex.First);
        if pCheck <> nil then
        begin
          if pCheck^.Number > MsgIdx.Number then
          begin
            FIndex.Insert(@MsgIdx, SizeOf(TMSGINDEX));
            FIndex.Insert(pCheck, SizeOf(TMSGINDEX));
            FIndex.First;
            FIndex.Remove;
          end
          else
          begin
            Inserted := False;
            pCheck := PMSGINDEX(FIndex.Next);
            while pCheck <> nil do
            begin
              if pCheck^.Number > MsgIdx.Number then
              begin
                FIndex.Previous;
                FIndex.Insert(@MsgIdx, SizeOf(TMSGINDEX));
                Inserted := True;
                Break;
              end;
              pCheck := PMSGINDEX(FIndex.Next);
            end;
            if not Inserted then
              FIndex.Add(@MsgIdx, SizeOf(TMSGINDEX));
          end;
        end
        else
          FIndex.Add(@MsgIdx, SizeOf(TMSGINDEX));

        Inc(FTotalMsgs);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  FBasePath := IncludeTrailingPathDelimiter(Dir);
end;

procedure TFidoSdm.Pack;
begin
  { FidoNet SDM doesn't need packing }
end;

function TFidoSdm.Previous(var ulMsg: LongWord): Boolean;
var
  pIdx: PMSGINDEX;
  Found: Boolean;
begin
  Result := False;
  Found := False;

  pIdx := PMSGINDEX(FIndex.First);
  while pIdx <> nil do
  begin
    if pIdx^.Number = ulMsg then
    begin
      Found := True;
      Break;
    end;
    pIdx := PMSGINDEX(FIndex.Next);
  end;

  if Found then
  begin
    pIdx := PMSGINDEX(FIndex.Previous);
    if pIdx <> nil then
    begin
      ulMsg := pIdx^.Number;
      Result := True;
    end;
  end
  else
  begin
    pIdx := PMSGINDEX(FIndex.Last);
    while pIdx <> nil do
    begin
      if pIdx^.Number < ulMsg then
      begin
        ulMsg := pIdx^.Number;
        Result := True;
        Break;
      end;
      pIdx := PMSGINDEX(FIndex.Previous);
    end;
  end;
end;

function TFidoSdm.ReadHeader(ulMsg: LongWord): Boolean;
var
  fs: TFileStream;
  pIdx: PMSGINDEX;
  NowDT: TDateTime;
  Y, M, D: Word;
begin
  Result := False;
  New;

  pIdx := PMSGINDEX(FIndex.First);
  while pIdx <> nil do
  begin
    if pIdx^.Number = ulMsg then
    begin
      FLastFile := FBasePath + StrPas(pIdx^.FileName);
      try
        fs := TFileStream.Create(FLastFile, fmOpenRead or fmShareDenyNone);
        try
          FillChar(FMsgHdr, SizeOf(FIDOMSG), 0);
          fs.Read(FMsgHdr, SizeOf(FIDOMSG));

          Current := ulMsg;
          StrPCopy(FromAddress, Format('%d/%d', [FMsgHdr.OrigNet, FMsgHdr.OrigNode]));
          StrPCopy(ToAddress, Format('%d/%d', [FMsgHdr.DestNet, FMsgHdr.DestNode]));

          ParseFidoDate(FMsgHdr.Date_, Written);

          { Set Arrived to current time }
          NowDT := Now;
          DecodeDate(NowDT, Y, M, D);
          Arrived.Day := D;
          Arrived.Month := M;
          Arrived.Year := Y;
          Arrived.Hour := HourOf(NowDT);
          Arrived.Minute := MinuteOf(NowDT);
          Arrived.Second := SecondOf(NowDT);

          Move(FMsgHdr.From_, From_, SizeOf(FMsgHdr.From_));
          Move(FMsgHdr.To_, To_, SizeOf(FMsgHdr.To_));
          Move(FMsgHdr.Subject_, Subject_, SizeOf(FMsgHdr.Subject_));

          SetFlagsFromAttr(FMsgHdr.Attrib);
          Original := FMsgHdr.Reply;
          Reply := FMsgHdr.Up;
          Result := True;
        finally
          fs.Free;
        end;
      except
      end;
      Break;
    end;
    pIdx := PMSGINDEX(FIndex.Next);
  end;
end;

function TFidoSdm.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function TFidoSdm.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  fs: TFileStream;
  pIdx: PMSGINDEX;
  NowDT: TDateTime;
  Y, M, D: Word;
  nReaded, i, nCol: Integer;
  SkipNext: Boolean;
  FromZone, ToZone, FromPoint, ToPoint: Word;
  IntlLine: string;
  tz, tn, t_o, fz, fn, f_o: Integer;
begin
  Result := False;
  New;
  MsgText.Clear;
  FromZone := 0; ToZone := 0; FromPoint := 0; ToPoint := 0;

  pIdx := PMSGINDEX(FIndex.First);
  while pIdx <> nil do
  begin
    if pIdx^.Number = ulMsg then
    begin
      FLastFile := FBasePath + StrPas(pIdx^.FileName);
      try
        fs := TFileStream.Create(FLastFile, fmOpenRead or fmShareDenyNone);
        try
          FillChar(FMsgHdr, SizeOf(FIDOMSG), 0);
          fs.Read(FMsgHdr, SizeOf(FIDOMSG));

          ParseFidoDate(FMsgHdr.Date_, Written);

          NowDT := Now;
          DecodeDate(NowDT, Y, M, D);
          Arrived.Day := D;
          Arrived.Month := M;
          Arrived.Year := Y;
          Arrived.Hour := HourOf(NowDT);
          Arrived.Minute := MinuteOf(NowDT);
          Arrived.Second := SecondOf(NowDT);

          Move(FMsgHdr.From_, From_, SizeOf(FMsgHdr.From_));
          Move(FMsgHdr.To_, To_, SizeOf(FMsgHdr.To_));
          Move(FMsgHdr.Subject_, Subject_, SizeOf(FMsgHdr.Subject_));
          SetFlagsFromAttr(FMsgHdr.Attrib);
          Original := FMsgHdr.Reply;
          Reply := FMsgHdr.Up;
          Current := ulMsg;

          { Read message text with word wrapping }
          pLine := @szLine[0];
          nCol := 0;
          SkipNext := False;

          repeat
            nReaded := fs.Read(szBuff, SizeOf(szBuff));
            pBuff := @szBuff[0];
            for i := 0 to nReaded - 1 do
            begin
              if pBuff^ = #0 then Break;
              if pBuff^ = #13 then
              begin
                pLine^ := #0;
                { Check for FMPT/TOPT/INTL/FLAGS kludges }
                if StrLComp(szLine, #1'FMPT ', 6) = 0 then
                  FromPoint := StrToIntDef(StrPas(@szLine[6]), 0)
                else if StrLComp(szLine, #1'TOPT ', 6) = 0 then
                  ToPoint := StrToIntDef(StrPas(@szLine[6]), 0)
                else if StrLComp(szLine, #1'INTL ', 6) = 0 then
                begin
                  IntlLine := StrPas(@szLine[6]);
                  if sscanf6D(IntlLine, tz, tn, t_o, fz, fn, f_o) then
                  begin
                    if (tn = FMsgHdr.DestNet) and (t_o = FMsgHdr.DestNode) then
                      ToZone := tz;
                    if (fn = FMsgHdr.OrigNet) and (f_o = FMsgHdr.OrigNode) then
                      FromZone := fz;
                  end;
                end
                else if StrLComp(szLine, #1'FLAGS ', 7) = 0 then
                begin
                  if Pos('DIR', StrPas(szLine)) > 0 then
                    Direct := 1;
                end;
                if (pLine > @szLine[0]) and SkipNext then
                begin
                  Dec(pLine);
                  while (pLine > @szLine[0]) and (pLine^ = ' ') do
                  begin
                    pLine^ := #0;
                    Dec(pLine);
                  end;
                  if pLine > @szLine[0] then
                    MsgText.Add(@szLine[0]);
                end
                else if not SkipNext then
                  MsgText.Add(@szLine[0]);
                SkipNext := False;
                pLine := @szLine[0];
                nCol := 0;
              end
              else if pBuff^ <> #10 then
              begin
                pLine^ := pBuff^;
                Inc(pLine);
                Inc(nCol);
                if nCol >= nWidth then
                begin
                  pLine^ := #0;
                  if StrScan(szLine, ' ') <> nil then
                  begin
                    while (nCol > 1) and (pLine^ <> ' ') do
                    begin
                      Dec(nCol);
                      Dec(pLine);
                    end;
                    if nCol > 0 then
                    begin
                      while pLine^ = ' ' do Inc(pLine);
                      StrCopy(szWrp, pLine);
                    end;
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
          until (nReaded = 0) or (i < nReaded);

          StrPCopy(FromAddress, Format('%u:%u/%u.%u', [FromZone, FMsgHdr.OrigNet, FMsgHdr.OrigNode, FromPoint]));
          StrPCopy(ToAddress, Format('%u:%u/%u.%u', [ToZone, FMsgHdr.DestNet, FMsgHdr.DestNode, ToPoint]));

          Result := True;
        finally
          fs.Free;
        end;
      except
      end;
      Break;
    end;
    pIdx := PMSGINDEX(FIndex.Next);
  end;
end;

procedure TFidoSdm.SetHWM(ulMsg: LongWord);
var
  fs: TFileStream;
  Hdr: FIDOMSG;
  Temp: string;
  NowDT: TDateTime;
  Y, M, D: Word;
  Body: string;
begin
  Temp := FBasePath + '1.msg';
  try
    fs := TFileStream.Create(Temp, fmCreate);
    try
      FillChar(Hdr, SizeOf(FIDOMSG), 0);
      StrCopy(Hdr.From_, 'MsgBase');
      StrCopy(Hdr.To_, 'Nobody in particular');
      StrCopy(Hdr.Subject_, 'Re: Whatsa high water mark?');

      NowDT := Now;
      DecodeDate(NowDT, Y, M, D);
      if (M >= 1) and (M <= 12) then
        StrPCopy(Hdr.Date_, Format('%2d %s %02d  %02d:%02d:%02d',
          [D, FidoMonths[M - 1], Y mod 100,
           HourOf(NowDT), MinuteOf(NowDT), SecondOf(NowDT)]));

      Hdr.Up := Word(ulMsg);
      Hdr.Attrib := MSGPRIVATE or MSGSENT or MSGREAD;
      fs.Write(Hdr, SizeOf(FIDOMSG));

      Body := #13#10'This message is used to store the high water mark'#13#10#0;
      fs.Write(Body[1], Length(Body));
    finally
      fs.Free;
    end;
  except
  end;
end;

function TFidoSdm.UidToMsgn(ulMsg: LongWord): LongWord;
var
  pIdx: PMSGINDEX;
  Num: LongWord;
begin
  Result := 0;
  Num := 0;
  pIdx := PMSGINDEX(FIndex.First);
  while pIdx <> nil do
  begin
    Inc(Num);
    if pIdx^.Number = ulMsg then
    begin
      Result := Num;
      Break;
    end;
    pIdx := PMSGINDEX(FIndex.Next);
  end;
end;

procedure TFidoSdm.UnLock;
begin
  { Nothing to do }
end;

function TFidoSdm.WriteHeader(ulMsg: LongWord): Boolean;
var
  fs: TFileStream;
  pIdx: PMSGINDEX;
begin
  Result := False;
  pIdx := PMSGINDEX(FIndex.First);
  while pIdx <> nil do
  begin
    if pIdx^.Number = ulMsg then
    begin
      FLastFile := FBasePath + StrPas(pIdx^.FileName);
      try
        fs := TFileStream.Create(FLastFile, fmOpenReadWrite or fmShareDenyNone);
        try
          FillChar(FMsgHdr, SizeOf(FIDOMSG), 0);
          fs.Read(FMsgHdr, SizeOf(FIDOMSG));
          FMsgHdr.Attrib := AttrFromFlags;
          FMsgHdr.Reply := Word(Original);
          FMsgHdr.Up := Word(Reply);
          fs.Position := 0;
          fs.Write(FMsgHdr, SizeOf(FIDOMSG));
          Result := True;
        finally
          fs.Free;
        end;
      except
      end;
      Break;
    end;
    pIdx := PMSGINDEX(FIndex.Next);
  end;
end;

{ Helper to parse INTL kludge "zone:net/node zone:net/node" }
function sscanf6D(const s: string; var tz, tn, t_o, fz, fn, f_o: Integer): Boolean;
var
  Parts: TStringList;
  DestPart, OrigPart: string;
  p: Integer;
begin
  Result := False;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ' ';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := s;
    if Parts.Count >= 2 then
    begin
      DestPart := Parts[0];
      OrigPart := Parts[1];

      p := Pos(':', DestPart);
      if p > 0 then
      begin
        tz := StrToIntDef(Copy(DestPart, 1, p - 1), 0);
        System.Delete(DestPart, 1, p);
      end;
      p := Pos('/', DestPart);
      if p > 0 then
      begin
        tn := StrToIntDef(Copy(DestPart, 1, p - 1), 0);
        t_o := StrToIntDef(Copy(DestPart, p + 1, Length(DestPart)), 0);
      end;

      p := Pos(':', OrigPart);
      if p > 0 then
      begin
        fz := StrToIntDef(Copy(OrigPart, 1, p - 1), 0);
        System.Delete(OrigPart, 1, p);
      end;
      p := Pos('/', OrigPart);
      if p > 0 then
      begin
        fn := StrToIntDef(Copy(OrigPart, 1, p - 1), 0);
        f_o := StrToIntDef(Copy(OrigPart, p + 1, Length(OrigPart)), 0);
      end;

      Result := True;
    end;
  finally
    Parts.Free;
  end;
end;

end.
