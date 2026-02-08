{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of jam.cpp
  JAM (Joaquim-Andrew-Mats) message base format
}

unit JamMsg;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, DateUtils, Collect, Jam, Struc299, MsgBase;

const
  JAM_MAX_TEXT = 2048;

type
  TJamMsg = class(TMsgBase)
  private
    FHdrStream: TFileStream;
    FTxtStream: TFileStream;
    FIdxStream: TFileStream;
    FSubfield: PByte;
    FBaseName: string;
    FHdrInfo: JAMHDRINFO;
    FJamHdr: JAMHDR;

    function OpenOrCreateFile(const FileName: string): TFileStream;
    function MDateToUnix(const D: MDATE): LongWord;
    procedure UnixToMDate(UnixTime: LongWord; var D: MDATE);
    function BuildAttributes: LongWord;
    procedure ParseAttributes(Attr: LongWord);
    function FindMsg(ulMsg: LongWord; var JamIdx: JAMIDXREC): Boolean;

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

function TJamMsg.OpenOrCreateFile(const FileName: string): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

function TJamMsg.MDateToUnix(const D: MDATE): LongWord;
var
  DT: TDateTime;
begin
  try
    DT := EncodeDateTime(D.Year, D.Month, D.Day, D.Hour, D.Minute, D.Second, 0);
    Result := DateTimeToUnix(DT);
  except
    Result := 0;
  end;
end;

procedure TJamMsg.UnixToMDate(UnixTime: LongWord; var D: MDATE);
var
  DT: TDateTime;
  Y, M, Day: Word;
  H, Mi, S, MS: Word;
begin
  DT := UnixToDateTime(UnixTime);
  DecodeDate(DT, Y, M, Day);
  DecodeTime(DT, H, Mi, S, MS);
  D.Day := Day;
  D.Month := M;
  if (D.Month < 1) or (D.Month > 12) then D.Month := 1;
  D.Year := Y;
  D.Hour := H;
  D.Minute := Mi;
  D.Second := S;
end;

function TJamMsg.BuildAttributes: LongWord;
begin
  Result := 0;
  if Crash <> 0 then Result := Result or MSG_CRASH;
  if Direct <> 0 then Result := Result or MSG_DIRECT;
  if FileAttach <> 0 then Result := Result or MSG_FILEATTACH;
  if FileRequest <> 0 then Result := Result or MSG_FILEREQUEST;
  if Hold <> 0 then Result := Result or MSG_HOLD;
  if Immediate <> 0 then Result := Result or MSG_IMMEDIATE;
  if Intransit <> 0 then Result := Result or MSG_INTRANSIT;
  if KillSent <> 0 then Result := Result or MSG_KILLSENT;
  if Local_ <> 0 then Result := Result or MSG_LOCAL;
  if Private_ <> 0 then Result := Result or MSG_PRIVATE;
  if ReceiptRequest <> 0 then Result := Result or MSG_RECEIPTREQ;
  if Received <> 0 then Result := Result or MSG_READ;
  if Sent <> 0 then Result := Result or MSG_SENT;
end;

procedure TJamMsg.ParseAttributes(Attr: LongWord);
begin
  Crash := Ord(Attr and MSG_CRASH <> 0);
  Direct := Ord(Attr and MSG_DIRECT <> 0);
  FileAttach := Ord(Attr and MSG_FILEATTACH <> 0);
  FileRequest := Ord(Attr and MSG_FILEREQUEST <> 0);
  Hold := Ord(Attr and MSG_HOLD <> 0);
  Immediate := Ord(Attr and MSG_IMMEDIATE <> 0);
  Intransit := Ord(Attr and MSG_INTRANSIT <> 0);
  KillSent := Ord(Attr and MSG_KILLSENT <> 0);
  Local_ := Ord(Attr and MSG_LOCAL <> 0);
  Private_ := Ord(Attr and MSG_PRIVATE <> 0);
  ReceiptRequest := Ord(Attr and MSG_RECEIPTREQ <> 0);
  Received := Ord(Attr and MSG_READ <> 0);
  Sent := Ord(Attr and MSG_SENT <> 0);
end;

function TJamMsg.FindMsg(ulMsg: LongWord; var JamIdx: JAMIDXREC): Boolean;
begin
  Result := False;
  if FIdxStream = nil then Exit;

  { Try optimistic: re-read last index }
  if (Id = ulMsg) and (FIdxStream.Position >= SizeOf(JAMIDXREC)) then
  begin
    FIdxStream.Position := FIdxStream.Position - SizeOf(JAMIDXREC);
    if FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) then
    begin
      FHdrStream.Position := JamIdx.HdrOffset;
      FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
      if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum = ulMsg) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

  { Scan from beginning }
  Id := 0;
  FIdxStream.Position := 0;
  while FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) do
  begin
    FHdrStream.Position := JamIdx.HdrOffset;
    FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
    if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum = ulMsg) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

constructor TJamMsg.Create;
begin
  inherited Create;
  FHdrStream := nil;
  FTxtStream := nil;
  FIdxStream := nil;
  FSubfield := nil;
end;

constructor TJamMsg.CreateOpen(const AName: string);
begin
  Create;
  Open(AName);
end;

destructor TJamMsg.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TJamMsg.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TJamMsg.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Result := AddText(AMsgBase.Text);
end;

function TJamMsg.AddText(var MsgText: TCollection): Boolean;
var
  ulMsg: LongWord;
  JamIdx: JAMIDXREC;
  JamSub: JAMBINSUBFIELD;
  pszText: PChar;
begin
  Result := False;
  if (FHdrStream = nil) or (FTxtStream = nil) or (FIdxStream = nil) then Exit;

  ulMsg := Highest + 1;

  FillChar(FJamHdr, SizeOf(JAMHDR), 0);
  FJamHdr.Signature[0] := 'J';
  FJamHdr.Signature[1] := 'A';
  FJamHdr.Signature[2] := 'M';
  FJamHdr.Signature[3] := #0;
  FJamHdr.Revision := CURRENTREVLEV;
  FJamHdr.MsgNum := ulMsg;
  FJamHdr.DateWritten := MDateToUnix(Written);
  FJamHdr.DateProcessed := MDateToUnix(Arrived);
  FJamHdr.Attribute := BuildAttributes;
  FJamHdr.ReplyTo := Original;
  FJamHdr.ReplyNext := Reply;

  { Write header at end }
  FHdrStream.Position := FHdrStream.Size;
  JamIdx.UserCRC := 0;
  JamIdx.HdrOffset := FHdrStream.Position;

  { Write index }
  FIdxStream.Position := FIdxStream.Size;
  FIdxStream.Write(JamIdx, SizeOf(JAMIDXREC));

  { Write initial header }
  FHdrStream.Write(FJamHdr, SizeOf(JAMHDR));

  { Write subfields }
  JamSub.HiID := 0;
  JamSub.LoID := JAMSFLD_SENDERNAME;
  JamSub.DatLen := StrLen(From_) + 1;
  FJamHdr.SubfieldLen := FJamHdr.SubfieldLen + JamSub.DatLen + SizeOf(JAMBINSUBFIELD);
  FHdrStream.Write(JamSub, SizeOf(JAMBINSUBFIELD));
  FHdrStream.Write(From_, StrLen(From_) + 1);

  if To_[0] <> #0 then
  begin
    JamSub.LoID := JAMSFLD_RECVRNAME;
    JamSub.DatLen := StrLen(To_) + 1;
    FJamHdr.SubfieldLen := FJamHdr.SubfieldLen + JamSub.DatLen + SizeOf(JAMBINSUBFIELD);
    FHdrStream.Write(JamSub, SizeOf(JAMBINSUBFIELD));
    FHdrStream.Write(To_, StrLen(To_) + 1);
  end;

  JamSub.LoID := JAMSFLD_SUBJECT;
  JamSub.DatLen := StrLen(Subject_) + 1;
  FJamHdr.SubfieldLen := FJamHdr.SubfieldLen + JamSub.DatLen + SizeOf(JAMBINSUBFIELD);
  FHdrStream.Write(JamSub, SizeOf(JAMBINSUBFIELD));
  FHdrStream.Write(Subject_, StrLen(Subject_) + 1);

  if FromAddress[0] <> #0 then
  begin
    JamSub.LoID := JAMSFLD_OADDRESS;
    JamSub.DatLen := StrLen(FromAddress) + 1;
    FJamHdr.SubfieldLen := FJamHdr.SubfieldLen + JamSub.DatLen + SizeOf(JAMBINSUBFIELD);
    FHdrStream.Write(JamSub, SizeOf(JAMBINSUBFIELD));
    FHdrStream.Write(FromAddress, StrLen(FromAddress) + 1);
  end;

  if ToAddress[0] <> #0 then
  begin
    JamSub.LoID := JAMSFLD_DADDRESS;
    JamSub.DatLen := StrLen(ToAddress) + 1;
    FJamHdr.SubfieldLen := FJamHdr.SubfieldLen + JamSub.DatLen + SizeOf(JAMBINSUBFIELD);
    FHdrStream.Write(JamSub, SizeOf(JAMBINSUBFIELD));
    FHdrStream.Write(ToAddress, StrLen(ToAddress) + 1);
  end;

  { Update header info }
  FHdrStream.Position := 0;
  FHdrStream.Read(FHdrInfo, SizeOf(JAMHDRINFO));
  Inc(FHdrInfo.ActiveMsgs);
  FHdrStream.Position := 0;
  FHdrStream.Write(FHdrInfo, SizeOf(JAMHDRINFO));

  { Rewrite header with updated SubfieldLen }
  FHdrStream.Position := JamIdx.HdrOffset;
  FHdrStream.Write(FJamHdr, SizeOf(JAMHDR));

  { Write message text }
  Id := FJamHdr.MsgNum;
  FTxtStream.Position := FTxtStream.Size;
  FJamHdr.TxtOffset := FTxtStream.Position;
  FJamHdr.TxtLen := 0;

  pszText := PChar(MsgText.First);
  while pszText <> nil do
  begin
    FTxtStream.Write(pszText^, StrLen(pszText));
    FJamHdr.TxtLen := FJamHdr.TxtLen + StrLen(pszText);
    FTxtStream.Write(PChar(#13#10)^, 2);
    FJamHdr.TxtLen := FJamHdr.TxtLen + 2;
    pszText := PChar(MsgText.Next);
  end;

  { Rewrite header with text offset/length }
  FHdrStream.Position := JamIdx.HdrOffset;
  FHdrStream.Write(FJamHdr, SizeOf(JAMHDR));

  WriteHeader(ulMsg);
  Result := True;
end;

procedure TJamMsg.Close;
begin
  FreeAndNil(FIdxStream);
  FreeAndNil(FTxtStream);
  FreeAndNil(FHdrStream);
  if FSubfield <> nil then
  begin
    FreeMem(FSubfield);
    FSubfield := nil;
  end;
  Id := 0;
end;

function TJamMsg.Delete(ulMsg: LongWord): Boolean;
var
  JamIdx: JAMIDXREC;
begin
  Result := False;
  if ReadHeader(ulMsg) then
  begin
    FJamHdr.Attribute := FJamHdr.Attribute or MSG_DELETED;
    { Re-read the index to get position }
    FIdxStream.Position := FIdxStream.Position - SizeOf(JAMIDXREC);
    if FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) then
    begin
      FHdrStream.Position := JamIdx.HdrOffset;
      FHdrStream.Write(FJamHdr, SizeOf(JAMHDR));

      FHdrStream.Position := 0;
      FHdrStream.Read(FHdrInfo, SizeOf(JAMHDRINFO));
      Dec(FHdrInfo.ActiveMsgs);
      FHdrStream.Position := 0;
      FHdrStream.Write(FHdrInfo, SizeOf(JAMHDRINFO));
      Result := True;
    end;
  end;
end;

function TJamMsg.GetHWM(var ulMsg: LongWord): Boolean;
begin
  ulMsg := 0;
  Result := False;
end;

function TJamMsg.Highest: LongWord;
var
  JamIdx: JAMIDXREC;
begin
  Result := 0;
  if (FIdxStream = nil) or (FHdrStream = nil) then Exit;
  if FHdrInfo.ActiveMsgs = 0 then Exit;

  if FIdxStream.Size >= SizeOf(JAMIDXREC) then
  begin
    FIdxStream.Position := FIdxStream.Size - SizeOf(JAMIDXREC);
    if FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) then
    begin
      FHdrStream.Position := JamIdx.HdrOffset;
      FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
      Result := FJamHdr.MsgNum;
    end;
  end;
  Id := Result;
end;

function TJamMsg.Lock(ulTimeout: LongWord): Boolean;
begin
  Result := True;
end;

function TJamMsg.Lowest: LongWord;
var
  JamIdx: JAMIDXREC;
begin
  Result := 0;
  if (FIdxStream = nil) or (FHdrStream = nil) then Exit;
  if FHdrInfo.ActiveMsgs = 0 then Exit;

  FIdxStream.Position := 0;
  if FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) then
  begin
    FHdrStream.Position := JamIdx.HdrOffset;
    FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
    Result := FJamHdr.MsgNum;
  end;
  Id := Result;
end;

function TJamMsg.MsgnToUid(ulMsg: LongWord): LongWord;
var
  i: LongWord;
  JamIdx: JAMIDXREC;
begin
  Result := ulMsg;
  if (FIdxStream = nil) or (FHdrStream = nil) then Exit;
  if (ulMsg = 0) or (ulMsg > FHdrInfo.ActiveMsgs) then
  begin
    if FHdrInfo.ActiveMsgs = 0 then Result := 0;
    Exit;
  end;

  i := 1;
  FIdxStream.Position := 0;
  while FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) do
  begin
    FHdrStream.Position := JamIdx.HdrOffset;
    FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
    if (FJamHdr.Attribute and MSG_DELETED) = 0 then
    begin
      if i = ulMsg then
      begin
        Result := FJamHdr.MsgNum;
        Break;
      end;
      Inc(i);
    end;
  end;

  if FHdrInfo.ActiveMsgs = 0 then Result := 0;
end;

procedure TJamMsg.New;
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

function TJamMsg.Next(var ulMsg: LongWord): Boolean;
var
  MayBeNext: Boolean;
  JamIdx: JAMIDXREC;
begin
  Result := False;
  if (FIdxStream = nil) or (FHdrStream = nil) then Exit;
  if FHdrInfo.ActiveMsgs = 0 then Exit;

  { Try optimistic: pointer should be after current }
  if FIdxStream.Position >= SizeOf(JAMIDXREC) then
  begin
    FIdxStream.Position := FIdxStream.Position - SizeOf(JAMIDXREC);
    while FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) do
    begin
      FHdrStream.Position := JamIdx.HdrOffset;
      FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
      if MayBeNext then
      begin
        if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum > ulMsg) then
        begin
          ulMsg := FJamHdr.MsgNum;
          Result := True;
          Break;
        end;
      end;
      if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum = ulMsg) then
        MayBeNext := True;
    end;
  end;

  if not Result and not MayBeNext then
  begin
    { Scan from beginning }
    FIdxStream.Position := 0;
    while FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) do
    begin
      FHdrStream.Position := JamIdx.HdrOffset;
      FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
      if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum > ulMsg) then
      begin
        ulMsg := FJamHdr.MsgNum;
        Result := True;
        Break;
      end;
    end;
  end;

  Id := 0;
  if Result then Id := ulMsg;
end;

function TJamMsg.Number: LongWord;
begin
  Result := FHdrInfo.ActiveMsgs;
end;

function TJamMsg.Open(const AName: string): Boolean;
var
  Sig: array[0..3] of Char;
begin
  Result := False;

  try
    FHdrStream := OpenOrCreateFile(AName + EXT_HDRFILE);

    if FHdrStream.Read(FHdrInfo, SizeOf(JAMHDRINFO)) <> SizeOf(JAMHDRINFO) then
    begin
      { Initialize new header info }
      FillChar(FHdrInfo, SizeOf(JAMHDRINFO), 0);
      FHdrInfo.Signature[0] := 'J';
      FHdrInfo.Signature[1] := 'A';
      FHdrInfo.Signature[2] := 'M';
      FHdrInfo.Signature[3] := #0;
      FHdrInfo.DateCreated := DateTimeToUnix(Now);
      FHdrInfo.BaseMsgNum := 1;
      FHdrStream.Position := 0;
      FHdrStream.Write(FHdrInfo, SizeOf(JAMHDRINFO));
    end;

    { Verify signature }
    Sig[0] := 'J'; Sig[1] := 'A'; Sig[2] := 'M'; Sig[3] := #0;
    if (FHdrInfo.Signature[0] = Sig[0]) and (FHdrInfo.Signature[1] = Sig[1]) and
       (FHdrInfo.Signature[2] = Sig[2]) and (FHdrInfo.Signature[3] = Sig[3]) then
    begin
      FTxtStream := OpenOrCreateFile(AName + EXT_TXTFILE);
      FIdxStream := OpenOrCreateFile(AName + EXT_IDXFILE);
      FBaseName := AName;
      Id := 0;
      Result := True;
    end
    else
    begin
      FreeAndNil(FHdrStream);
      FillChar(FHdrInfo, SizeOf(JAMHDRINFO), 0);
    end;
  except
    Close;
  end;
end;

procedure TJamMsg.Pack;
var
  fsHdrNew, fsIdxNew, fsTxtNew: TFileStream;
  JamIdx: JAMIDXREC;
  SubfieldBuf, TempBuf: PByte;
  ToRead, Readed: Integer;
begin
  if FHdrStream = nil then Exit;

  fsHdrNew := nil; fsIdxNew := nil; fsTxtNew := nil;
  try
    fsHdrNew := TFileStream.Create(FBaseName + '.$dr', fmCreate);
    fsTxtNew := TFileStream.Create(FBaseName + '.$dt', fmCreate);
    fsIdxNew := TFileStream.Create(FBaseName + '.$dx', fmCreate);

    FHdrStream.Position := 0;
    FHdrStream.Read(FHdrInfo, SizeOf(JAMHDRINFO));
    fsHdrNew.Write(FHdrInfo, SizeOf(JAMHDRINFO));

    while FHdrStream.Read(FJamHdr, SizeOf(JAMHDR)) = SizeOf(JAMHDR) do
    begin
      if (FJamHdr.Attribute and MSG_DELETED) <> 0 then
      begin
        if FJamHdr.SubfieldLen > 0 then
          FHdrStream.Position := FHdrStream.Position + Int64(FJamHdr.SubfieldLen);
      end
      else
      begin
        JamIdx.UserCRC := 0;
        JamIdx.HdrOffset := fsHdrNew.Position;
        fsIdxNew.Write(JamIdx, SizeOf(JAMIDXREC));

        FTxtStream.Position := FJamHdr.TxtOffset;
        FJamHdr.TxtOffset := fsTxtNew.Position;
        fsHdrNew.Write(FJamHdr, SizeOf(JAMHDR));

        { Copy subfields }
        if FJamHdr.SubfieldLen > 0 then
        begin
          SubfieldBuf := GetMem(FJamHdr.SubfieldLen + 1);
          try
            FHdrStream.Read(SubfieldBuf^, FJamHdr.SubfieldLen);
            fsHdrNew.Write(SubfieldBuf^, FJamHdr.SubfieldLen);
          finally
            FreeMem(SubfieldBuf);
          end;
        end;

        { Copy text }
        TempBuf := GetMem(JAM_MAX_TEXT);
        try
          while FJamHdr.TxtLen > 0 do
          begin
            ToRead := JAM_MAX_TEXT;
            if LongWord(ToRead) > FJamHdr.TxtLen then ToRead := FJamHdr.TxtLen;
            Readed := FTxtStream.Read(TempBuf^, ToRead);
            fsTxtNew.Write(TempBuf^, Readed);
            FJamHdr.TxtLen := FJamHdr.TxtLen - LongWord(Readed);
          end;
        finally
          FreeMem(TempBuf);
        end;
      end;
    end;

    FreeAndNil(fsHdrNew);
    FreeAndNil(fsTxtNew);
    FreeAndNil(fsIdxNew);
    FreeAndNil(FHdrStream);
    FreeAndNil(FTxtStream);
    FreeAndNil(FIdxStream);

    { Replace files }
    SysUtils.DeleteFile(FBaseName + EXT_HDRFILE);
    RenameFile(FBaseName + '.$dr', FBaseName + EXT_HDRFILE);
    SysUtils.DeleteFile(FBaseName + EXT_TXTFILE);
    RenameFile(FBaseName + '.$dt', FBaseName + EXT_TXTFILE);
    SysUtils.DeleteFile(FBaseName + EXT_IDXFILE);
    RenameFile(FBaseName + '.$dx', FBaseName + EXT_IDXFILE);

    Open(FBaseName);
  except
    FreeAndNil(fsHdrNew);
    FreeAndNil(fsTxtNew);
    FreeAndNil(fsIdxNew);
    SysUtils.DeleteFile(FBaseName + '.$dr');
    SysUtils.DeleteFile(FBaseName + '.$dt');
    SysUtils.DeleteFile(FBaseName + '.$dx');
  end;
end;

function TJamMsg.Previous(var ulMsg: LongWord): Boolean;
var
  MayBeNext: Boolean;
  Pos: Int64;
  JamIdx: JAMIDXREC;
begin
  Result := False;
  if (FIdxStream = nil) or (FHdrStream = nil) then Exit;
  if FHdrInfo.ActiveMsgs = 0 then Exit;

  MayBeNext := False;

  { Try optimistic backwards scan }
  if FIdxStream.Position >= SizeOf(JAMIDXREC) then
  begin
    Pos := FIdxStream.Position - SizeOf(JAMIDXREC);
    while Pos >= 0 do
    begin
      FIdxStream.Position := Pos;
      if FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) then
      begin
        FHdrStream.Position := JamIdx.HdrOffset;
        FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
        if MayBeNext then
        begin
          if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum < ulMsg) then
          begin
            ulMsg := FJamHdr.MsgNum;
            Result := True;
            Break;
          end;
        end;
        if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum = ulMsg) then
          MayBeNext := True;
      end;
      Pos := Pos - SizeOf(JAMIDXREC);
    end;
  end;

  if not Result and not MayBeNext then
  begin
    { Scan from end backwards }
    if FIdxStream.Size >= SizeOf(JAMIDXREC) then
    begin
      Pos := FIdxStream.Size - SizeOf(JAMIDXREC);
      while Pos >= 0 do
      begin
        FIdxStream.Position := Pos;
        if FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) then
        begin
          FHdrStream.Position := JamIdx.HdrOffset;
          FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
          if ((FJamHdr.Attribute and MSG_DELETED) = 0) and (FJamHdr.MsgNum < ulMsg) then
          begin
            ulMsg := FJamHdr.MsgNum;
            Result := True;
            Break;
          end;
        end;
        Pos := Pos - SizeOf(JAMIDXREC);
      end;
    end;
  end;

  Id := 0;
  if Result then Id := ulMsg;
end;

function TJamMsg.ReadHeader(ulMsg: LongWord): Boolean;
var
  JamIdx: JAMIDXREC;
  pPos: PByte;
  ulSubfieldLen: LongWord;
  pSub: PJAMBINSUBFIELD;
begin
  New;
  Result := FindMsg(ulMsg, JamIdx);

  if Result then
  begin
    Current := ulMsg;
    Id := ulMsg;
    ParseAttributes(FJamHdr.Attribute);
    UnixToMDate(FJamHdr.DateWritten, Written);
    UnixToMDate(FJamHdr.DateProcessed, Arrived);
    Original := FJamHdr.ReplyTo;
    Reply := FJamHdr.ReplyNext;

    { Free old subfield data }
    if FSubfield <> nil then begin FreeMem(FSubfield); FSubfield := nil; end;

    { Read subfields }
    if FJamHdr.SubfieldLen > 0 then
    begin
      ulSubfieldLen := FJamHdr.SubfieldLen;
      FSubfield := GetMem(ulSubfieldLen + 1);
      if FSubfield = nil then begin Result := False; Exit; end;

      FHdrStream.Read(FSubfield^, ulSubfieldLen);
      pPos := FSubfield;

      while ulSubfieldLen > 0 do
      begin
        pSub := PJAMBINSUBFIELD(pPos);
        Inc(pPos, SizeOf(JAMBINSUBFIELD));

        case pSub^.LoID of
          JAMSFLD_SENDERNAME: begin Move(pPos^, From_, pSub^.DatLen); From_[pSub^.DatLen] := #0; end;
          JAMSFLD_RECVRNAME:  begin Move(pPos^, To_, pSub^.DatLen); To_[pSub^.DatLen] := #0; end;
          JAMSFLD_SUBJECT:    begin Move(pPos^, Subject_, pSub^.DatLen); Subject_[pSub^.DatLen] := #0; end;
          JAMSFLD_OADDRESS:   begin Move(pPos^, FromAddress, pSub^.DatLen); FromAddress[pSub^.DatLen] := #0; end;
          JAMSFLD_DADDRESS:   begin Move(pPos^, ToAddress, pSub^.DatLen); ToAddress[pSub^.DatLen] := #0; end;
        end;

        ulSubfieldLen := ulSubfieldLen - SizeOf(JAMBINSUBFIELD) - pSub^.DatLen;
        if ulSubfieldLen > 0 then
          Inc(pPos, pSub^.DatLen);
      end;
    end;
  end;
end;

function TJamMsg.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function TJamMsg.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  JamIdx: JAMIDXREC;
  pPos: PByte;
  ulSubfieldLen, ulTxtLen: LongWord;
  pSub: PJAMBINSUBFIELD;
  nReaded, nCol, nRead, i: Integer;
  SkipNext: Boolean;
  p: PChar;
  Bottom: TCollection;
begin
  Result := False;
  MsgText.Clear;

  if not ReadHeader(ulMsg) then Exit;

  { Re-read index to get header offset for subfield reading }
  FIdxStream.Position := FIdxStream.Position - SizeOf(JAMIDXREC);
  FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC));
  FHdrStream.Position := JamIdx.HdrOffset;
  FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));

  { Add FMPT/TOPT kludges }
  p := StrScan(FromAddress, '.');
  if p <> nil then
  begin
    Inc(p);
    if StrToIntDef(StrPas(p), 0) <> 0 then
    begin
      StrPCopy(szLine, Format(#1'FMPT %s', [StrPas(p)]));
      MsgText.Add(@szLine[0], StrLen(szLine) + 1);
    end;
  end;
  p := StrScan(ToAddress, '.');
  if p <> nil then
  begin
    Inc(p);
    if StrToIntDef(StrPas(p), 0) <> 0 then
    begin
      StrPCopy(szLine, Format(#1'TOPT %s', [StrPas(p)]));
      MsgText.Add(@szLine[0], StrLen(szLine) + 1);
    end;
  end;

  { Free and re-read subfields for kludge lines }
  if FSubfield <> nil then begin FreeMem(FSubfield); FSubfield := nil; end;

  Bottom := TCollection.Create;
  try
    if FJamHdr.SubfieldLen > 0 then
    begin
      ulSubfieldLen := FJamHdr.SubfieldLen;
      FSubfield := GetMem(ulSubfieldLen + 1);
      FHdrStream.Read(FSubfield^, ulSubfieldLen);
      pPos := FSubfield;

      while ulSubfieldLen > 0 do
      begin
        pSub := PJAMBINSUBFIELD(pPos);
        Inc(pPos, SizeOf(JAMBINSUBFIELD));

        case pSub^.LoID of
          JAMSFLD_MSGID: begin
            Move(pPos^, szBuff, pSub^.DatLen); szBuff[pSub^.DatLen] := #0;
            StrPCopy(szLine, Format(#1'MSGID: %s', [StrPas(szBuff)]));
            MsgText.Add(@szLine[0]);
          end;
          JAMSFLD_REPLYID: begin
            Move(pPos^, szBuff, pSub^.DatLen); szBuff[pSub^.DatLen] := #0;
            StrPCopy(szLine, Format(#1'REPLYID: %s', [StrPas(szBuff)]));
            MsgText.Add(@szLine[0]);
          end;
          JAMSFLD_PID: begin
            Move(pPos^, szBuff, pSub^.DatLen); szBuff[pSub^.DatLen] := #0;
            StrPCopy(szLine, Format(#1'PID: %s', [StrPas(szBuff)]));
            MsgText.Add(@szLine[0]);
          end;
          JAMSFLD_SEENBY2D: begin
            Move(pPos^, szBuff, pSub^.DatLen); szBuff[pSub^.DatLen] := #0;
            StrPCopy(szLine, Format('SEEN-BY: %s', [StrPas(szBuff)]));
            Bottom.Add(@szLine[0]);
          end;
          JAMSFLD_PATH2D: begin
            Move(pPos^, szBuff, pSub^.DatLen); szBuff[pSub^.DatLen] := #0;
            StrPCopy(szLine, Format(#1'PATH: %s', [StrPas(szBuff)]));
            Bottom.Add(@szLine[0]);
          end;
        end;

        ulSubfieldLen := ulSubfieldLen - SizeOf(JAMBINSUBFIELD) - pSub^.DatLen;
        if ulSubfieldLen > 0 then
          Inc(pPos, pSub^.DatLen);
      end;
    end;

    { Read message text with word wrapping }
    FTxtStream.Position := FJamHdr.TxtOffset;
    ulTxtLen := FJamHdr.TxtLen;
    pLine := @szLine[0];
    nCol := 0;
    SkipNext := False;

    while ulTxtLen > 0 do
    begin
      nRead := SizeOf(szBuff);
      if LongWord(nRead) > ulTxtLen then nRead := ulTxtLen;
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
            while (pLine > @szLine[0]) and (pLine^ = ' ') do begin pLine^ := #0; Dec(pLine); end;
            if pLine > @szLine[0] then
              MsgText.Add(@szLine[0], StrLen(szLine) + 1);
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
              if nCol > 0 then begin while pLine^ = ' ' do Inc(pLine); StrCopy(szWrp, pLine); end;
              pLine^ := #0;
            end
            else szWrp[0] := #0;
            MsgText.Add(@szLine[0]);
            StrCopy(szLine, szWrp);
            pLine := StrEnd(szLine);
            nCol := StrLen(szLine);
            SkipNext := True;
          end;
        end;
        Inc(pBuff);
      end;

      ulTxtLen := ulTxtLen - LongWord(nRead);
    end;

    { Append SEEN-BY and PATH lines }
    p := PChar(Bottom.First);
    while p <> nil do
    begin
      MsgText.Add(p);
      p := PChar(Bottom.Next);
    end;
  finally
    Bottom.Free;
  end;

  Result := True;
end;

procedure TJamMsg.SetHWM(ulMsg: LongWord);
begin
  { Not supported in JAM }
end;

function TJamMsg.UidToMsgn(ulMsg: LongWord): LongWord;
var
  i: LongWord;
  JamIdx: JAMIDXREC;
begin
  Result := 0;
  if (FIdxStream = nil) or (FHdrStream = nil) then Exit;

  i := 1;
  FIdxStream.Position := 0;
  while FIdxStream.Read(JamIdx, SizeOf(JAMIDXREC)) = SizeOf(JAMIDXREC) do
  begin
    FHdrStream.Position := JamIdx.HdrOffset;
    FHdrStream.Read(FJamHdr, SizeOf(JAMHDR));
    if (FJamHdr.Attribute and MSG_DELETED) = 0 then
    begin
      if FJamHdr.MsgNum = ulMsg then
      begin
        Result := i;
        Break;
      end;
      Inc(i);
    end;
  end;

  if FHdrInfo.ActiveMsgs = 0 then Result := 0;
end;

procedure TJamMsg.UnLock;
begin
  { Nothing to do }
end;

function TJamMsg.WriteHeader(ulMsg: LongWord): Boolean;
var
  JamIdx: JAMIDXREC;
begin
  Result := FindMsg(ulMsg, JamIdx);

  if Result then
  begin
    Id := FJamHdr.MsgNum;
    FJamHdr.Attribute := FJamHdr.Attribute and MSG_DELETED; { preserve deleted flag }
    FJamHdr.Attribute := FJamHdr.Attribute or BuildAttributes;
    FJamHdr.ReplyTo := Original;
    FJamHdr.ReplyNext := Reply;

    FHdrStream.Position := JamIdx.HdrOffset;
    FHdrStream.Write(FJamHdr, SizeOf(JAMHDR));
  end;
end;

end.
