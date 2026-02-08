{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of hudson.cpp
  Hudson (QuickBBS/RA) message base format
}

unit Hudson;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect, Struc299, MsgBase;

type
  THudson = class(TMsgBase)
  private
    FBaseName: string;
    FBoardNum: Byte;
    FTotalMsgs: LongWord;
    FLocked: Boolean;
    FMsgInfo: HMSGINFO;
    FMsgIdx: array of HMSGIDX;
    FMsgHdr: HMSGHDR;
    FHdrStream: TFileStream;
    FTxtStream: TFileStream;
    FToIdxStream: TFileStream;

    procedure Pascal2C(const strp: PChar; strc: PChar);
    procedure C2Pascal(strp: PChar; const strc: PChar);
    procedure ReadMsgInfo;
    procedure WriteMsgInfo;
    procedure ReadAllIdx;
    function FindIdxPosition(ulMsg: LongWord): Integer;
    function OpenOrCreateFile(const FileName: string): TFileStream;
    procedure SetMsgAttrFlags;
    procedure GetMsgAttrFlags;

  public
    constructor Create; overload;
    constructor CreateOpen(const AName: string; Board: Byte);
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
    function Open(const AName: string; Board: Byte): Boolean;
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

procedure THudson.Pascal2C(const strp: PChar; strc: PChar);
var
  Len: Byte;
begin
  Len := Byte(strp[0]);
  Move(strp[1], strc^, Len);
  strc[Len] := #0;
end;

procedure THudson.C2Pascal(strp: PChar; const strc: PChar);
var
  Len: Integer;
begin
  Len := StrLen(strc);
  Move(strc^, strp[1], Len);
  strp[0] := Char(Len);
end;

procedure THudson.ReadMsgInfo;
var
  fs: TFileStream;
begin
  FillChar(FMsgInfo, SizeOf(HMSGINFO), 0);
  if FileExists(FBaseName + 'msginfo.bbs') then
  begin
    try
      fs := TFileStream.Create(FBaseName + 'msginfo.bbs', fmOpenRead or fmShareDenyNone);
      try
        fs.Read(FMsgInfo, SizeOf(HMSGINFO));
      finally
        fs.Free;
      end;
    except
    end;
  end;
end;

procedure THudson.WriteMsgInfo;
var
  fs: TFileStream;
begin
  try
    fs := OpenOrCreateFile(FBaseName + 'msginfo.bbs');
    try
      fs.Position := 0;
      fs.Write(FMsgInfo, SizeOf(HMSGINFO));
    finally
      fs.Free;
    end;
  except
  end;
end;

procedure THudson.ReadAllIdx;
var
  fs: TFileStream;
  Count: Integer;
begin
  SetLength(FMsgIdx, 0);
  if FileExists(FBaseName + 'msgidx.bbs') then
  begin
    try
      fs := TFileStream.Create(FBaseName + 'msgidx.bbs', fmOpenRead or fmShareDenyNone);
      try
        Count := fs.Size div SizeOf(HMSGIDX);
        if Count > 0 then
        begin
          SetLength(FMsgIdx, Count);
          fs.Read(FMsgIdx[0], Count * SizeOf(HMSGIDX));
        end;
      finally
        fs.Free;
      end;
    except
    end;
  end;
end;

function THudson.FindIdxPosition(ulMsg: LongWord): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Length(FMsgIdx) - 1 do
    if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum = ulMsg) and (FMsgIdx[i].MsgNum <> $FFFF) then
    begin
      Result := i;
      Exit;
    end;
end;

function THudson.OpenOrCreateFile(const FileName: string): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

procedure THudson.SetMsgAttrFlags;
begin
  FMsgHdr.MsgAttr := 0;
  FMsgHdr.NetAttr := 0;
  if Local_ <> 0 then FMsgHdr.MsgAttr := FMsgHdr.MsgAttr or HUD_LOCAL;
  if Private_ <> 0 then FMsgHdr.MsgAttr := FMsgHdr.MsgAttr or HUD_PRIVATE;
  if Received <> 0 then FMsgHdr.MsgAttr := FMsgHdr.MsgAttr or HUD_RECEIVED;
  if Crash <> 0 then FMsgHdr.NetAttr := FMsgHdr.NetAttr or HUD_CRASH;
  if KillSent <> 0 then FMsgHdr.NetAttr := FMsgHdr.NetAttr or HUD_KILL;
  if Sent <> 0 then FMsgHdr.NetAttr := FMsgHdr.NetAttr or HUD_SENT;
  if FileAttach <> 0 then FMsgHdr.NetAttr := FMsgHdr.NetAttr or HUD_FILE;
  if FileRequest <> 0 then FMsgHdr.NetAttr := FMsgHdr.NetAttr or HUD_FRQ;
end;

procedure THudson.GetMsgAttrFlags;
begin
  Local_ := Ord((FMsgHdr.MsgAttr and HUD_LOCAL) = HUD_LOCAL);
  Private_ := Ord(FMsgHdr.MsgAttr and HUD_PRIVATE <> 0);
  Received := Ord(FMsgHdr.MsgAttr and HUD_RECEIVED <> 0);
  Crash := Ord(FMsgHdr.NetAttr and HUD_CRASH <> 0);
  KillSent := Ord(FMsgHdr.NetAttr and HUD_KILL <> 0);
  Sent := Ord(FMsgHdr.NetAttr and HUD_SENT <> 0);
  FileAttach := Ord(FMsgHdr.NetAttr and HUD_FILE <> 0);
  FileRequest := Ord(FMsgHdr.NetAttr and HUD_FRQ <> 0);
end;

constructor THudson.Create;
begin
  inherited Create;
  FHdrStream := nil;
  FTxtStream := nil;
  FToIdxStream := nil;
  FLocked := False;
  FTotalMsgs := 0;
end;

constructor THudson.CreateOpen(const AName: string; Board: Byte);
begin
  Create;
  Open(AName, Board);
end;

destructor THudson.Destroy;
begin
  Close;
  inherited Destroy;
end;

function THudson.Add: Boolean;
begin
  Result := AddText(Text);
end;

function THudson.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Result := AddText(AMsgBase.Text);
end;

function THudson.AddText(var MsgText: TCollection): Boolean;
var
  fs: TFileStream;
  MsgToIdx: HMSGTOIDX;
  HMsgIdx: HMSGIDX;
  pAddr: string;
  p: Integer;
  pszText: PChar;
  InBlock, Len, CopyLen: Integer;
  Temp: string;
begin
  Result := False;

  if not FLocked then
    ReadMsgInfo;

  { Build header }
  FillChar(FMsgHdr, SizeOf(HMSGHDR), 0);
  Inc(FMsgInfo.HighMsg);
  FMsgHdr.MsgNum := FMsgInfo.HighMsg;
  FMsgHdr.PrevReply := Word(Original);
  FMsgHdr.NextReply := Word(Reply);

  if FMsgInfo.LowMsg = 0 then
    FMsgInfo.LowMsg := FMsgInfo.HighMsg;
  Inc(FMsgInfo.TotalMsgs);
  Inc(FMsgInfo.TotalOnBoard[FBoardNum - 1]);
  FTotalMsgs := FMsgInfo.TotalOnBoard[FBoardNum - 1];

  { Parse addresses }
  pAddr := StrPas(FromAddress);
  p := Pos(':', pAddr);
  if p > 0 then begin FMsgHdr.OrigZone := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  p := Pos('/', pAddr);
  if p > 0 then begin FMsgHdr.OrigNet := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  FMsgHdr.OrigNode := StrToIntDef(pAddr, 0);

  pAddr := StrPas(ToAddress);
  p := Pos(':', pAddr);
  if p > 0 then begin FMsgHdr.DestZone := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  p := Pos('/', pAddr);
  if p > 0 then begin FMsgHdr.DestNet := StrToIntDef(Copy(pAddr, 1, p-1), 0); System.Delete(pAddr, 1, p); end;
  FMsgHdr.DestNode := StrToIntDef(pAddr, 0);

  FMsgHdr.Board := FBoardNum;
  Temp := Format('%02d:%02d', [Written.Hour, Written.Minute]);
  C2Pascal(FMsgHdr.Time_, PChar(Temp));
  Temp := Format('%02d-%02d-%02d', [Written.Month, Written.Day, Written.Year mod 100]);
  C2Pascal(FMsgHdr.Date_, PChar(Temp));
  C2Pascal(FMsgHdr.WhoFrom, From_);
  C2Pascal(FMsgHdr.WhoTo, To_);
  C2Pascal(FMsgHdr.Subject_, Subject_);

  SetMsgAttrFlags;

  { Write msgtoidx.bbs }
  FillChar(MsgToIdx, SizeOf(HMSGTOIDX), 0);
  C2Pascal(MsgToIdx.String_, To_);
  try
    if not FLocked then
      FToIdxStream := OpenOrCreateFile(FBaseName + 'msgtoidx.bbs');
    if FToIdxStream <> nil then
    begin
      FToIdxStream.Position := FToIdxStream.Size;
      FToIdxStream.Write(MsgToIdx, SizeOf(HMSGTOIDX));
    end;
    if not FLocked then FreeAndNil(FToIdxStream);
  except
  end;

  { Write msgidx.bbs }
  FillChar(HMsgIdx, SizeOf(HMSGIDX), 0);
  HMsgIdx.MsgNum := FMsgHdr.MsgNum;
  HMsgIdx.Board := FMsgHdr.Board;
  if not FLocked then
  begin
    try
      fs := OpenOrCreateFile(FBaseName + 'msgidx.bbs');
      try
        fs.Position := fs.Size;
        fs.Write(HMsgIdx, SizeOf(HMSGIDX));
      finally
        fs.Free;
      end;
    except
    end;
  end
  else
  begin
    if FMsgInfo.TotalMsgs <= Length(FMsgIdx) then
      SetLength(FMsgIdx, Length(FMsgIdx) + 5000);
    FMsgIdx[FMsgInfo.TotalMsgs - 1].MsgNum := HMsgIdx.MsgNum;
    FMsgIdx[FMsgInfo.TotalMsgs - 1].Board := HMsgIdx.Board;
  end;

  { Write msgtxt.bbs - Hudson 256-byte block format }
  try
    if not FLocked then
      FTxtStream := OpenOrCreateFile(FBaseName + 'msgtxt.bbs');
    if FTxtStream <> nil then
    begin
      FTxtStream.Position := FTxtStream.Size;
      FMsgHdr.StartBlock := FTxtStream.Position div 256;
      InBlock := 0;

      pszText := PChar(MsgText.First);
      while pszText <> nil do
      begin
        Len := StrLen(pszText);
        while Len > 0 do
        begin
          if InBlock + Len <= 255 then
          begin
            Move(pszText^, szBuff[1 + InBlock], Len);
            InBlock := InBlock + Len;
            Len := 0;
          end
          else
          begin
            CopyLen := 255 - InBlock;
            Move(pszText^, szBuff[1 + InBlock], CopyLen);
            szBuff[0] := #255;
            FTxtStream.Write(szBuff, 256);
            Inc(FMsgHdr.NumBlocks);
            Inc(pszText, CopyLen);
            Len := Len - CopyLen;
            InBlock := 0;
          end;
        end;

        if InBlock >= 255 then
        begin
          szBuff[0] := #255;
          FTxtStream.Write(szBuff, 256);
          Inc(FMsgHdr.NumBlocks);
          InBlock := 0;
        end;
        szBuff[1 + InBlock] := #13;
        Inc(InBlock);

        if InBlock >= 255 then
        begin
          szBuff[0] := #255;
          FTxtStream.Write(szBuff, 256);
          Inc(FMsgHdr.NumBlocks);
          InBlock := 0;
        end;
        szBuff[1 + InBlock] := #10;
        Inc(InBlock);

        pszText := PChar(MsgText.Next);
      end;

      if InBlock > 0 then
      begin
        szBuff[0] := Char(InBlock);
        FTxtStream.Write(szBuff, 256);
        Inc(FMsgHdr.NumBlocks);
      end;
    end;
    if not FLocked then FreeAndNil(FTxtStream);
  except
  end;

  { Write msghdr.bbs }
  try
    if not FLocked then
      FHdrStream := OpenOrCreateFile(FBaseName + 'msghdr.bbs');
    if FHdrStream <> nil then
    begin
      FHdrStream.Position := FHdrStream.Size;
      FHdrStream.Write(FMsgHdr, SizeOf(HMSGHDR));
    end;
    if not FLocked then FreeAndNil(FHdrStream);
  except
  end;

  { Update msginfo and idx }
  if not FLocked then
  begin
    SetLength(FMsgIdx, 0);
    ReadAllIdx;
    WriteMsgInfo;
  end;

  Result := True;
end;

procedure THudson.Close;
begin
  UnLock;
  SetLength(FMsgIdx, 0);
  FreeAndNil(FHdrStream);
  FreeAndNil(FTxtStream);
  FreeAndNil(FToIdxStream);
  Id := 0;
end;

function THudson.Delete(ulMsg: LongWord): Boolean;
var
  i: Integer;
  fs: TFileStream;
begin
  Result := False;

  if not FLocked then
  begin
    ReadMsgInfo;
    FTotalMsgs := FMsgInfo.TotalOnBoard[FBoardNum - 1];
    ReadAllIdx;
  end;

  for i := 0 to FMsgInfo.TotalMsgs - 1 do
  begin
    if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum = ulMsg) then
    begin
      FMsgIdx[i].MsgNum := $FFFF;
      if not FLocked then
      begin
        try
          fs := OpenOrCreateFile(FBaseName + 'msgidx.bbs');
          try
            fs.Position := 0;
            fs.Write(FMsgIdx[0], Length(FMsgIdx) * SizeOf(HMSGIDX));
          finally
            fs.Free;
          end;
        except
        end;
      end;
      Result := True;
      Break;
    end;
  end;

  if Result then
  begin
    Dec(FMsgInfo.TotalMsgs);
    Dec(FMsgInfo.TotalOnBoard[FBoardNum - 1]);
    FTotalMsgs := FMsgInfo.TotalOnBoard[FBoardNum - 1];
    if not FLocked then WriteMsgInfo;
  end;
end;

function THudson.GetHWM(var ulMsg: LongWord): Boolean;
begin
  ulMsg := 0;
  Result := False;
end;

function THudson.Highest: LongWord;
var
  i: Integer;
begin
  Result := 0;
  if (Length(FMsgIdx) > 0) and (FTotalMsgs > 0) then
    for i := FMsgInfo.TotalMsgs - 1 downto 0 do
      if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum <> $FFFF) then
      begin
        Result := FMsgIdx[i].MsgNum;
        Break;
      end;
end;

function THudson.Lock(ulTimeout: LongWord): Boolean;
begin
  if not FLocked then
  begin
    ReadMsgInfo;
    FTotalMsgs := FMsgInfo.TotalOnBoard[FBoardNum - 1];
    ReadAllIdx;
    { Extend idx buffer for new messages }
    SetLength(FMsgIdx, Length(FMsgIdx) + 5000);

    FTxtStream := OpenOrCreateFile(FBaseName + 'msgtxt.bbs');
    FHdrStream := OpenOrCreateFile(FBaseName + 'msghdr.bbs');
    FToIdxStream := OpenOrCreateFile(FBaseName + 'msgtoidx.bbs');
    FLocked := True;
  end;
  Result := True;
end;

function THudson.Lowest: LongWord;
var
  i: Integer;
begin
  Result := 0;
  if (Length(FMsgIdx) > 0) and (FTotalMsgs > 0) then
    for i := 0 to FMsgInfo.TotalMsgs - 1 do
      if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum <> $FFFF) then
      begin
        Result := FMsgIdx[i].MsgNum;
        Break;
      end;
end;

function THudson.MsgnToUid(ulMsg: LongWord): LongWord;
var
  i: Integer;
  Num: LongWord;
begin
  Result := ulMsg;
  if (Length(FMsgIdx) = 0) or (FTotalMsgs = 0) then Exit;

  Num := 1;
  for i := 0 to FMsgInfo.TotalMsgs - 1 do
    if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum <> $FFFF) then
    begin
      if Num = ulMsg then
      begin
        Result := FMsgIdx[i].MsgNum;
        Exit;
      end;
      Inc(Num);
    end;
end;

procedure THudson.New;
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

function THudson.Next(var ulMsg: LongWord): Boolean;
var
  i: Integer;
begin
  Result := False;
  if (Length(FMsgIdx) = 0) or (FTotalMsgs = 0) then Exit;

  for i := 0 to FMsgInfo.TotalMsgs - 1 do
    if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum > ulMsg) and (FMsgIdx[i].MsgNum <> $FFFF) then
    begin
      ulMsg := FMsgIdx[i].MsgNum;
      Result := True;
      Break;
    end;
end;

function THudson.Number: LongWord;
begin
  Result := FTotalMsgs;
end;

function THudson.Open(const AName: string; Board: Byte): Boolean;
begin
  Close;
  FBaseName := AName;
  FBoardNum := Board;

  ReadMsgInfo;
  FTotalMsgs := FMsgInfo.TotalOnBoard[FBoardNum - 1];
  ReadAllIdx;
  Result := True;
end;

procedure THudson.Pack;
{ TODO: Hudson pack is complex - stub for now }
begin
end;

function THudson.Previous(var ulMsg: LongWord): Boolean;
var
  i: Integer;
begin
  Result := False;
  if (Length(FMsgIdx) = 0) or (FTotalMsgs = 0) then Exit;

  for i := FMsgInfo.TotalMsgs - 1 downto 0 do
    if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum < ulMsg) and (FMsgIdx[i].MsgNum <> $FFFF) then
    begin
      ulMsg := FMsgIdx[i].MsgNum;
      Result := True;
      Break;
    end;
end;

function THudson.ReadHeader(ulMsg: LongWord): Boolean;
var
  i: Integer;
  fs: TFileStream;
  FromZone, ToZone, FromPoint, ToPoint: Word;
  nReaded, nCol: Integer;
  yy: Integer;
begin
  Result := False;
  FromPoint := 0; ToPoint := 0; FromZone := 0; ToZone := 0;

  i := FindIdxPosition(ulMsg);
  if i < 0 then Exit;

  Current := ulMsg;
  Id := ulMsg;

  { Read header }
  try
    if not FLocked then
      FHdrStream := OpenOrCreateFile(FBaseName + 'msghdr.bbs');
    FHdrStream.Position := Int64(i) * SizeOf(HMSGHDR);
    FHdrStream.Read(FMsgHdr, SizeOf(HMSGHDR));
    if not FLocked then FreeAndNil(FHdrStream);
  except
    if not FLocked then FreeAndNil(FHdrStream);
    Exit;
  end;

  Pascal2C(FMsgHdr.WhoFrom, From_);
  Pascal2C(FMsgHdr.WhoTo, To_);
  Pascal2C(FMsgHdr.Subject_, Subject_);

  StrPCopy(FromAddress, Format('%d:%d/%d', [FMsgHdr.OrigZone, FMsgHdr.OrigNet, FMsgHdr.OrigNode]));
  StrPCopy(ToAddress, Format('%d:%d/%d', [FMsgHdr.DestZone, FMsgHdr.DestNet, FMsgHdr.DestNode]));

  Original := FMsgHdr.PrevReply;
  Reply := FMsgHdr.NextReply;

  { Parse date (Pascal string format: "MM-DD-YY") }
  Written.Day := (Byte(FMsgHdr.Date_[4]) - Byte('0')) * 10 + (Byte(FMsgHdr.Date_[5]) - Byte('0'));
  Written.Month := (Byte(FMsgHdr.Date_[1]) - Byte('0')) * 10 + (Byte(FMsgHdr.Date_[2]) - Byte('0'));
  yy := (Byte(FMsgHdr.Date_[7]) - Byte('0')) * 10 + (Byte(FMsgHdr.Date_[8]) - Byte('0'));
  if yy < 90 then Written.Year := yy + 2000 else Written.Year := yy + 1900;

  { Parse time (Pascal string format: "HH:MM") }
  Written.Hour := (Byte(FMsgHdr.Time_[1]) - Byte('0')) * 10 + (Byte(FMsgHdr.Time_[2]) - Byte('0'));
  Written.Minute := (Byte(FMsgHdr.Time_[4]) - Byte('0')) * 10 + (Byte(FMsgHdr.Time_[5]) - Byte('0'));
  Written.Second := 0;
  Arrived := Written;

  GetMsgAttrFlags;

  { Read first text block for kludges }
  try
    if not FLocked then
      FTxtStream := OpenOrCreateFile(FBaseName + 'msgtxt.bbs');
    FTxtStream.Position := Int64(FMsgHdr.StartBlock) * 256;
    FTxtStream.Read(szBuff, 256);
    nReaded := Byte(szBuff[0]);

    pLine := @szLine[0];
    nCol := 0;
    FromZone := FMsgHdr.OrigZone;
    ToZone := FMsgHdr.DestZone;

    pBuff := @szBuff[1];
    for i := 0 to nReaded - 1 do
    begin
      if pBuff^ = #13 then
      begin
        pLine^ := #0;
        if StrLComp(szLine, #1'FMPT ', 6) = 0 then
          FromPoint := StrToIntDef(StrPas(@szLine[6]), 0)
        else if StrLComp(szLine, #1'TOPT ', 6) = 0 then
          ToPoint := StrToIntDef(StrPas(@szLine[6]), 0)
        else if StrLComp(szLine, #1'FLAGS ', 7) = 0 then
        begin
          if Pos('DIR', StrPas(szLine)) > 0 then Direct := 1;
        end;
        pLine := @szLine[0];
        nCol := 0;
      end
      else if pBuff^ <> #10 then
      begin
        pLine^ := pBuff^;
        Inc(pLine);
        Inc(nCol);
        if nCol >= 80 then begin pLine := @szLine[0]; nCol := 0; end;
      end;
      Inc(pBuff);
    end;

    StrPCopy(FromAddress, Format('%u:%u/%u.%u', [FromZone, FMsgHdr.OrigNet, FMsgHdr.OrigNode, FromPoint]));
    StrPCopy(ToAddress, Format('%u:%u/%u.%u', [ToZone, FMsgHdr.DestNet, FMsgHdr.DestNode, ToPoint]));

    if not FLocked then FreeAndNil(FTxtStream);
  except
    if not FLocked then FreeAndNil(FTxtStream);
  end;

  Result := True;
end;

function THudson.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function THudson.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  m, i, nReaded, nCol: Integer;
  SkipNext: Boolean;
  FromZone, ToZone, FromPoint, ToPoint: Word;
begin
  MsgText.Clear;
  FromPoint := 0; ToPoint := 0; FromZone := 0; ToZone := 0;

  Result := ReadHeader(ulMsg);
  if not Result then Exit;

  try
    if not FLocked then
      FTxtStream := OpenOrCreateFile(FBaseName + 'msgtxt.bbs');
    FTxtStream.Position := Int64(FMsgHdr.StartBlock) * 256;

    pLine := @szLine[0];
    nCol := 0;
    SkipNext := False;

    for m := 0 to FMsgHdr.NumBlocks - 1 do
    begin
      FTxtStream.Read(szBuff, 256);
      nReaded := Byte(szBuff[0]);

      pBuff := @szBuff[1];
      for i := 0 to nReaded - 1 do
      begin
        if pBuff^ = #13 then
        begin
          pLine^ := #0;
          { Process kludge lines }
          if StrLComp(szLine, #1'FMPT ', 6) = 0 then
            FromPoint := StrToIntDef(StrPas(@szLine[6]), 0)
          else if StrLComp(szLine, #1'TOPT ', 6) = 0 then
            ToPoint := StrToIntDef(StrPas(@szLine[6]), 0)
          else if StrLComp(szLine, #1'FLAGS ', 7) = 0 then
          begin
            if Pos('DIR', StrPas(szLine)) > 0 then Direct := 1;
          end;

          if (pLine > @szLine[0]) and SkipNext then
          begin
            Dec(pLine);
            while (pLine > @szLine[0]) and (pLine^ = ' ') do begin pLine^ := #0; Dec(pLine); end;
            if pLine > @szLine[0] then
              MsgText.Add(@szLine[0], StrLen(szLine) + 1);
          end
          else if not SkipNext then
            MsgText.Add(@szLine[0], StrLen(szLine) + 1);
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
            MsgText.Add(@szLine[0], StrLen(szLine) + 1);
            StrCopy(szLine, szWrp);
            pLine := StrEnd(szLine);
            nCol := StrLen(szLine);
            SkipNext := True;
          end;
        end;
        Inc(pBuff);
      end;
    end;

    StrPCopy(FromAddress, Format('%u:%u/%u.%u', [FromZone, FMsgHdr.OrigNet, FMsgHdr.OrigNode, FromPoint]));
    StrPCopy(ToAddress, Format('%u:%u/%u.%u', [ToZone, FMsgHdr.DestNet, FMsgHdr.DestNode, ToPoint]));

    if not FLocked then FreeAndNil(FTxtStream);
  except
    if not FLocked then FreeAndNil(FTxtStream);
  end;
end;

procedure THudson.SetHWM(ulMsg: LongWord);
begin
  { Not supported }
end;

function THudson.UidToMsgn(ulMsg: LongWord): LongWord;
var
  i: Integer;
  Num: LongWord;
begin
  Result := ulMsg;
  if (Length(FMsgIdx) = 0) or (FTotalMsgs = 0) then Exit;

  Num := 1;
  for i := 0 to FMsgInfo.TotalMsgs - 1 do
    if (FMsgIdx[i].Board = FBoardNum) and (FMsgIdx[i].MsgNum <> $FFFF) then
    begin
      if FMsgIdx[i].MsgNum = ulMsg then
      begin
        Result := Num;
        Exit;
      end;
      Inc(Num);
    end;
end;

procedure THudson.UnLock;
var
  fs: TFileStream;
begin
  if FLocked then
  begin
    WriteMsgInfo;

    { Write back index }
    try
      fs := OpenOrCreateFile(FBaseName + 'msgidx.bbs');
      try
        fs.Position := 0;
        if FMsgInfo.TotalMsgs > 0 then
          fs.Write(FMsgIdx[0], FMsgInfo.TotalMsgs * SizeOf(HMSGIDX));
      finally
        fs.Free;
      end;
    except
    end;

    FreeAndNil(FHdrStream);
    FreeAndNil(FTxtStream);
    FreeAndNil(FToIdxStream);
    FLocked := False;
  end;
end;

function THudson.WriteHeader(ulMsg: LongWord): Boolean;
var
  i: Integer;
begin
  Result := False;
  i := FindIdxPosition(ulMsg);
  if i < 0 then Exit;

  try
    if not FLocked then
      FHdrStream := OpenOrCreateFile(FBaseName + 'msghdr.bbs');
    FHdrStream.Position := Int64(i) * SizeOf(HMSGHDR);
    FHdrStream.Read(FMsgHdr, SizeOf(HMSGHDR));
    SetMsgAttrFlags;
    FHdrStream.Position := Int64(i) * SizeOf(HMSGHDR);
    FHdrStream.Write(FMsgHdr, SizeOf(HMSGHDR));
    if not FLocked then FreeAndNil(FHdrStream);
    Result := True;
  except
    if not FLocked then FreeAndNil(FHdrStream);
  end;
end;

end.
