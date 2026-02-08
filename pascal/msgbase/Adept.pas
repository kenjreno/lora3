{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of adept.cpp
  Adept message base format
}

unit Adept;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect, Struc299, MsgBase;

type
  TAdept = class(TMsgBase)
  private
    FHdrStream: TFileStream;
    FIdxStream: TFileStream;
    FTxtStream: TFileStream;
    FBaseName: string;
    FTotalMsgs: LongWord;
    FData: ADEPTDATA;

    procedure ParseAdeptDate(const DateStr: PChar; var D: MDATE);
    function AdeptFlagsFromMsg: Word;
    procedure MsgFromAdeptFlags(AFlags: Word);
    function OpenOrCreateFile(const FileName: string): TFileStream;

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

const
  AdeptMonths: array[0..11] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  );

procedure TAdept.ParseAdeptDate(const DateStr: PChar; var D: MDATE);
var
  s: string;
  dd, yy, hr, mn, sc, i: Integer;
  mm: string;
begin
  s := StrPas(DateStr);
  s := StringReplace(s, '  ', ' ', [rfReplaceAll]);
  dd := 0; yy := 0; hr := 0; mn := 0; sc := 0; mm := '';

  { Parse "dd Mon yy hh:mm:ss" }
  i := Pos(' ', s);
  if i > 0 then begin dd := StrToIntDef(Copy(s, 1, i-1), 0); System.Delete(s, 1, i); end;
  i := Pos(' ', s);
  if i > 0 then begin mm := Copy(s, 1, i-1); System.Delete(s, 1, i); end;
  i := Pos(' ', s);
  if i > 0 then begin yy := StrToIntDef(Copy(s, 1, i-1), 0); System.Delete(s, 1, i); end;

  { Parse time }
  hr := StrToIntDef(Copy(s, 1, 2), 0);
  mn := StrToIntDef(Copy(s, 4, 2), 0);
  if Length(s) >= 8 then sc := StrToIntDef(Copy(s, 7, 2), 0);

  D.Day := dd;
  D.Month := 1;
  for i := 0 to 11 do
    if SameText(AdeptMonths[i], Copy(mm, 1, 3)) then
    begin
      D.Month := i + 1;
      Break;
    end;
  if (D.Month < 1) or (D.Month > 12) then D.Month := 1;
  D.Year := yy + 1900;
  if D.Year < 1980 then D.Year := D.Year + 100;
  D.Hour := hr;
  D.Minute := mn;
  D.Second := sc;
end;

function TAdept.AdeptFlagsFromMsg: Word;
begin
  Result := 0;
  if Sent <> 0 then Result := Result or MSGSENT;
  if Crash <> 0 then Result := Result or MSGCRASH;
  if Received <> 0 then Result := Result or MSGREAD;
  if Private_ <> 0 then Result := Result or MSGPRIVATE;
  if KillSent <> 0 then Result := Result or MSGKILL;
  if Local_ <> 0 then Result := Result or MSGLOCAL;
  if FileRequest <> 0 then Result := Result or MSGFRQ;
end;

procedure TAdept.MsgFromAdeptFlags(AFlags: Word);
begin
  Sent := Ord(AFlags and MSGSENT <> 0);
  Crash := Ord(AFlags and MSGCRASH <> 0);
  Received := Ord(AFlags and MSGREAD <> 0);
  Private_ := Ord(AFlags and MSGPRIVATE <> 0);
  KillSent := Ord(AFlags and MSGKILL <> 0);
  Local_ := Ord(AFlags and MSGLOCAL <> 0);
  FileRequest := Ord(AFlags and MSGFRQ <> 0);
end;

function TAdept.OpenOrCreateFile(const FileName: string): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

constructor TAdept.Create;
begin
  inherited Create;
  FHdrStream := nil;
  FIdxStream := nil;
  FTxtStream := nil;
  FTotalMsgs := 0;
end;

constructor TAdept.CreateOpen(const AName: string);
begin
  Create;
  Open(AName);
end;

destructor TAdept.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TAdept.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TAdept.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Result := AddText(AMsgBase.Text);
end;

function TAdept.AddText(var MsgText: TCollection): Boolean;
var
  Idx: ADEPTINDEXES;
  pText: PChar;
  pAddr: string;
  cr: Char;
  p: Integer;
begin
  Result := False;
  if (FHdrStream = nil) or (FIdxStream = nil) or (FTxtStream = nil) then
    Exit;

  { Build index checksums }
  FillChar(Idx, SizeOf(Idx), 0);
  pText := To_;
  while pText^ <> #0 do begin Idx.to_ := Idx.to_ + SmallInt(Byte(pText^)); Inc(pText); end;
  pText := From_;
  while pText^ <> #0 do begin Idx.from_ := Idx.from_ + SmallInt(Byte(pText^)); Inc(pText); end;
  pText := Subject_;
  while pText^ <> #0 do begin Idx.subj := Idx.subj + SmallInt(Byte(pText^)); Inc(pText); end;

  Idx.msgidserialno := Highest + 1;
  FIdxStream.Position := FIdxStream.Size;
  FIdxStream.Write(Idx, SizeOf(ADEPTINDEXES));

  { Build data record }
  FillChar(FData, SizeOf(FData), 0);
  FData.StructLen := SizeOf(ADEPTDATA);
  Move(From_, FData.from_, SizeOf(FData.from_));
  Move(To_, FData.to_, SizeOf(FData.to_));
  Move(Subject_, FData.subj, SizeOf(FData.subj));
  FData.msgnum := Idx.msgidserialno;

  { Parse FromAddress }
  pAddr := StrPas(FromAddress);
  p := Pos(':', pAddr);
  if p > 0 then begin FData.o_zone := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  p := Pos('/', pAddr);
  if p > 0 then begin FData.o_net := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  p := Pos('@', pAddr);
  if p > 0 then System.Delete(pAddr, p, Length(pAddr));
  p := Pos('.', pAddr);
  if p > 0 then begin FData.o_node := StrToIntDef(Copy(pAddr, 1, p-1), 0); FData.o_point := StrToIntDef(Copy(pAddr, p+1, Length(pAddr)), 0); end
  else FData.o_node := StrToIntDef(pAddr, 0);

  { Parse ToAddress }
  pAddr := StrPas(ToAddress);
  p := Pos(':', pAddr);
  if p > 0 then begin FData.d_zone := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  p := Pos('/', pAddr);
  if p > 0 then begin FData.d_net := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  p := Pos('@', pAddr);
  if p > 0 then System.Delete(pAddr, p, Length(pAddr));
  p := Pos('.', pAddr);
  if p > 0 then begin FData.d_node := StrToIntDef(Copy(pAddr, 1, p-1), 0); FData.d_point := StrToIntDef(Copy(pAddr, p+1, Length(pAddr)), 0); end
  else FData.d_node := StrToIntDef(pAddr, 0);

  { Format date }
  if Written.Month = 0 then Written.Month := 1;
  if (Written.Month >= 1) and (Written.Month <= 12) then
    StrPCopy(FData.date_, Format('%2d %s %02d  %02d:%02d:%02d',
      [Written.Day, AdeptMonths[Written.Month - 1], Written.Year mod 100,
       Written.Hour, Written.Minute, Written.Second]));

  FData.fflags := AdeptFlagsFromMsg;

  { Write text }
  FTxtStream.Position := FTxtStream.Size;
  FData.start := FTxtStream.Position;
  FData.length_ := 0;

  cr := #13;
  pText := PChar(MsgText.First);
  while pText <> nil do
  begin
    FData.length_ := FData.length_ + LongWord(StrLen(pText)) + 1;
    FTxtStream.Write(pText^, StrLen(pText));
    FTxtStream.Write(cr, 1);
    pText := PChar(MsgText.Next);
  end;

  { Write header record }
  FHdrStream.Position := FHdrStream.Size;
  FHdrStream.Write(FData, SizeOf(ADEPTDATA));

  Inc(FTotalMsgs);
  Result := True;
end;

procedure TAdept.Close;
begin
  FreeAndNil(FHdrStream);
  FreeAndNil(FIdxStream);
  FreeAndNil(FTxtStream);
  Id := 0;
end;

function TAdept.Delete(ulMsg: LongWord): Boolean;
begin
  Result := False;
  if ReadHeader(ulMsg) then
  begin
    FData.xflags := FData.xflags or MSGDELETED;
    FHdrStream.Position := FHdrStream.Position - SizeOf(ADEPTDATA);
    FHdrStream.Write(FData, SizeOf(ADEPTDATA));
    Dec(FTotalMsgs);
    Result := True;
  end;
end;

function TAdept.GetHWM(var ulMsg: LongWord): Boolean;
begin
  ulMsg := 0;
  Result := False;
end;

function TAdept.Highest: LongWord;
var
  SavePos: Int64;
  Pos: Int64;
begin
  Result := 0;
  if FHdrStream = nil then Exit;
  if FHdrStream.Size < SizeOf(ADEPTDATA) then Exit;

  SavePos := FHdrStream.Position;
  Pos := FHdrStream.Size - SizeOf(ADEPTDATA);
  while Pos >= 0 do
  begin
    FHdrStream.Position := Pos;
    if FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) then
    begin
      if (FData.xflags and MSGDELETED) = 0 then
      begin
        Result := FData.msgnum;
        Break;
      end;
    end;
    Pos := Pos - SizeOf(ADEPTDATA);
  end;
  FHdrStream.Position := SavePos;
end;

function TAdept.Lock(ulTimeout: LongWord): Boolean;
begin
  Result := True;
end;

function TAdept.Lowest: LongWord;
var
  SavePos: Int64;
begin
  Result := 0;
  if FHdrStream = nil then Exit;

  SavePos := FHdrStream.Position;
  FHdrStream.Position := 0;
  while FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) do
  begin
    if (FData.xflags and MSGDELETED) = 0 then
    begin
      Result := FData.msgnum;
      Break;
    end;
  end;
  FHdrStream.Position := SavePos;
end;

function TAdept.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TAdept.New;
begin
  From_[0] := #0; To_[0] := #0; Subject_[0] := #0;
  Crash := 0; Direct := 0; FileAttach := 0; FileRequest := 0;
  Hold := 0; Immediate := 0; Intransit := 0; KillSent := 0;
  Local_ := 0; Private_ := 0; ReceiptRequest := 0; Received := 0;
  Sent := 0;
  FillChar(Written, SizeOf(Written), 0);
  FillChar(Arrived, SizeOf(Arrived), 0);
  FromAddress[0] := #0; ToAddress[0] := #0;
  Original := 0; Reply := 0;
  Text.Clear;
end;

function TAdept.Next(var ulMsg: LongWord): Boolean;
var
  MayBeNext: Boolean;
begin
  Result := False;
  if FHdrStream = nil then Exit;

  { Try optimistic: current position should be right after last read }
  if FHdrStream.Position >= SizeOf(ADEPTDATA) then
  begin
    FHdrStream.Position := FHdrStream.Position - SizeOf(ADEPTDATA);
    FHdrStream.Read(FData, SizeOf(ADEPTDATA));
    if FData.msgnum = ulMsg then
    begin
      while FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) do
      begin
        if (FData.xflags and MSGDELETED) = 0 then
        begin
          ulMsg := FData.msgnum;
          Result := True;
          Id := ulMsg;
          Exit;
        end;
      end;
    end;
  end;

  { Fall back: scan from beginning }
  FHdrStream.Position := 0;
  MayBeNext := False;
  while FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) do
  begin
    if (FData.xflags and MSGDELETED) = 0 then
    begin
      if MayBeNext then
      begin
        ulMsg := FData.msgnum;
        Result := True;
        Break;
      end
      else if ulMsg = FData.msgnum then
        MayBeNext := True
      else if ulMsg < FData.msgnum then
      begin
        ulMsg := FData.msgnum;
        Result := True;
        Break;
      end;
    end;
  end;

  Id := ulMsg;
end;

function TAdept.Number: LongWord;
begin
  Result := FTotalMsgs;
end;

function TAdept.Open(const AName: string): Boolean;
begin
  Result := False;
  FTotalMsgs := 0;

  try
    FHdrStream := OpenOrCreateFile(AName + '.Data');
    FIdxStream := OpenOrCreateFile(AName + '.Index');
    FTxtStream := OpenOrCreateFile(AName + '.Text');

    { Count non-deleted messages }
    while FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) do
      if (FData.xflags and MSGDELETED) = 0 then
        Inc(FTotalMsgs);

    FBaseName := AName;
    Current := 0;
    Id := 0;
    Result := True;
  except
    Close;
  end;
end;

procedure TAdept.Pack;
var
  fsHdrNew, fsTxtNew, fsIdxNew: TFileStream;
  Idx: ADEPTINDEXES;
  TextBuf: array[0..2047] of Byte;
  Max: Integer;
  TxtLen: LongWord;
begin
  if FHdrStream = nil then Exit;

  fsHdrNew := nil; fsTxtNew := nil; fsIdxNew := nil;
  try
    fsHdrNew := TFileStream.Create(FBaseName + '.NewData', fmCreate);
    fsIdxNew := TFileStream.Create(FBaseName + '.NewIndex', fmCreate);
    fsTxtNew := TFileStream.Create(FBaseName + '.NewText', fmCreate);

    FHdrStream.Position := 0;
    FIdxStream.Position := 0;

    while FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) do
    begin
      FIdxStream.Read(Idx, SizeOf(ADEPTINDEXES));
      if (FData.xflags and MSGDELETED) = 0 then
      begin
        FTxtStream.Position := FData.start;
        FData.start := fsTxtNew.Position;
        fsHdrNew.Write(FData, SizeOf(ADEPTDATA));

        TxtLen := FData.length_;
        while TxtLen > 0 do
        begin
          Max := 2048;
          if LongWord(Max) > TxtLen then Max := TxtLen;
          FTxtStream.Read(TextBuf, Max);
          fsTxtNew.Write(TextBuf, Max);
          TxtLen := TxtLen - LongWord(Max);
        end;

        fsIdxNew.Write(Idx, SizeOf(ADEPTINDEXES));
      end;
    end;

    FreeAndNil(fsHdrNew);
    FreeAndNil(fsTxtNew);
    FreeAndNil(fsIdxNew);
    FreeAndNil(FHdrStream);
    FreeAndNil(FTxtStream);
    FreeAndNil(FIdxStream);

    { Replace old files with new }
    SysUtils.DeleteFile(FBaseName + '.Data');
    RenameFile(FBaseName + '.NewData', FBaseName + '.Data');
    SysUtils.DeleteFile(FBaseName + '.Index');
    RenameFile(FBaseName + '.NewIndex', FBaseName + '.Index');
    SysUtils.DeleteFile(FBaseName + '.Text');
    RenameFile(FBaseName + '.NewText', FBaseName + '.Text');

    { Reopen }
    FHdrStream := OpenOrCreateFile(FBaseName + '.Data');
    FIdxStream := OpenOrCreateFile(FBaseName + '.Index');
    FTxtStream := OpenOrCreateFile(FBaseName + '.Text');
  except
    FreeAndNil(fsHdrNew);
    FreeAndNil(fsTxtNew);
    FreeAndNil(fsIdxNew);
    SysUtils.DeleteFile(FBaseName + '.NewData');
    SysUtils.DeleteFile(FBaseName + '.NewIndex');
    SysUtils.DeleteFile(FBaseName + '.NewText');
  end;
end;

function TAdept.Previous(var ulMsg: LongWord): Boolean;
var
  MayBeNext: Boolean;
  Pos: Int64;
begin
  Result := False;
  if FHdrStream = nil then Exit;

  { Try optimistic: position after last read, go backwards }
  if FHdrStream.Position >= SizeOf(ADEPTDATA) then
  begin
    FHdrStream.Position := FHdrStream.Position - SizeOf(ADEPTDATA);
    FHdrStream.Read(FData, SizeOf(ADEPTDATA));
    if FData.msgnum = ulMsg then
    begin
      Pos := FHdrStream.Position - SizeOf(ADEPTDATA);
      while Pos >= SizeOf(ADEPTDATA) do
      begin
        Pos := Pos - SizeOf(ADEPTDATA);
        FHdrStream.Position := Pos;
        FHdrStream.Read(FData, SizeOf(ADEPTDATA));
        if (FData.xflags and MSGDELETED) = 0 then
        begin
          ulMsg := FData.msgnum;
          Result := True;
          Id := ulMsg;
          Exit;
        end;
      end;
    end;
  end;

  { Fall back: scan from end backwards }
  if FHdrStream.Size >= SizeOf(ADEPTDATA) then
  begin
    Pos := FHdrStream.Size - SizeOf(ADEPTDATA);
    MayBeNext := False;

    FHdrStream.Position := Pos;
    FHdrStream.Read(FData, SizeOf(ADEPTDATA));
    if (FData.xflags and MSGDELETED) = 0 then
    begin
      if ulMsg = FData.msgnum then
        MayBeNext := True
      else if ulMsg > FData.msgnum then
      begin
        ulMsg := FData.msgnum;
        Result := True;
        Id := ulMsg;
        Exit;
      end;
    end;

    while Pos >= SizeOf(ADEPTDATA) do
    begin
      Pos := Pos - SizeOf(ADEPTDATA);
      FHdrStream.Position := Pos;
      FHdrStream.Read(FData, SizeOf(ADEPTDATA));
      if (FData.xflags and MSGDELETED) = 0 then
      begin
        if MayBeNext then
        begin
          ulMsg := FData.msgnum;
          Result := True;
          Break;
        end
        else if ulMsg = FData.msgnum then
          MayBeNext := True
        else if ulMsg > FData.msgnum then
        begin
          ulMsg := FData.msgnum;
          Result := True;
          Break;
        end;
      end;
    end;
  end;

  Id := ulMsg;
end;

function TAdept.ReadHeader(ulMsg: LongWord): Boolean;
begin
  Result := False;
  if FHdrStream = nil then Exit;

  New;

  { Try optimistic read }
  if Id = ulMsg then
  begin
    if FHdrStream.Position >= SizeOf(ADEPTDATA) then
    begin
      FHdrStream.Position := FHdrStream.Position - SizeOf(ADEPTDATA);
      if FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) then
        if FData.msgnum = ulMsg then
          Result := True;
    end;
  end;

  { Scan from beginning }
  if not Result then
  begin
    FHdrStream.Position := 0;
    while FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) do
    begin
      if ((FData.xflags and MSGDELETED) = 0) and (ulMsg = FData.msgnum) then
      begin
        Result := True;
        Break;
      end;
    end;
  end;

  if Result then
  begin
    Current := ulMsg;
    Id := ulMsg;
    Move(FData.from_, From_, SizeOf(FData.from_));
    Move(FData.to_, To_, SizeOf(FData.to_));
    Move(FData.subj, Subject_, SizeOf(FData.subj));

    StrPCopy(FromAddress, Format('%u:%u/%u.%u', [FData.o_zone, FData.o_net, FData.o_node, FData.o_point]));
    StrPCopy(ToAddress, Format('%u:%u/%u.%u', [FData.d_zone, FData.d_net, FData.d_node, FData.d_point]));

    ParseAdeptDate(FData.date_, Written);
    Arrived := Written;

    MsgFromAdeptFlags(FData.fflags);
  end;
end;

function TAdept.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function TAdept.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  nReaded, nCol, nRead, i: Integer;
  TxtLen: LongInt;
  SkipNext: Boolean;
begin
  Result := False;
  MsgText.Clear;

  if not ReadHeader(ulMsg) then Exit;

  FTxtStream.Position := FData.start;
  TxtLen := FData.length_;
  pLine := @szLine[0];
  nCol := 0;
  SkipNext := False;

  if TxtLen > 0 then
  repeat
    nRead := SizeOf(szBuff);
    if nRead > TxtLen then nRead := TxtLen;
    nReaded := FTxtStream.Read(szBuff, nRead);

    pBuff := @szBuff[0];
    for i := 0 to nReaded - 1 do
    begin
      if pBuff^ = #13 then
      begin
        pLine^ := #0;
        if (pLine > @szLine[0]) and SkipNext then
        begin
          Dec(pLine);
          while (pLine > @szLine[0]) and (pLine^ = ' ') do
          begin pLine^ := #0; Dec(pLine); end;
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
            while (nCol > 1) and (pLine^ <> ' ') do begin Dec(nCol); Dec(pLine); end;
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

    TxtLen := TxtLen - nReaded;
  until TxtLen <= 0;

  Result := True;
end;

procedure TAdept.SetHWM(ulMsg: LongWord);
begin
  { Not supported }
end;

function TAdept.UidToMsgn(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TAdept.UnLock;
begin
  { Nothing to do }
end;

function TAdept.WriteHeader(ulMsg: LongWord): Boolean;
begin
  Result := False;
  if FHdrStream = nil then Exit;

  { Find the record }
  if Id = ulMsg then
  begin
    if FHdrStream.Position >= SizeOf(ADEPTDATA) then
    begin
      FHdrStream.Position := FHdrStream.Position - SizeOf(ADEPTDATA);
      if FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) then
        if FData.msgnum = ulMsg then
          Result := True;
    end;
  end;

  if not Result then
  begin
    FHdrStream.Position := 0;
    while FHdrStream.Read(FData, SizeOf(ADEPTDATA)) = SizeOf(ADEPTDATA) do
    begin
      if ((FData.xflags and MSGDELETED) = 0) and (ulMsg = FData.msgnum) then
      begin
        Result := True;
        Break;
      end;
    end;
  end;

  if Result then
  begin
    FData.fflags := AdeptFlagsFromMsg;
    FHdrStream.Position := FHdrStream.Position - SizeOf(ADEPTDATA);
    FHdrStream.Write(FData, SizeOf(ADEPTDATA));
  end;
end;

end.
