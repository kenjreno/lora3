{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of squish.cpp
  Squish message base format (.SQD/.SQI)
}

unit Squish;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Math, Collect, Struc299, MsgBase;

type
  TSquish = class(TMsgBase)
  private
    fpDat: TFileStream;
    fpIdx: TFileStream;
    FLocked: Boolean;
    FSqBase: SQBASE;
    FSqIdx: SQIDX;
    FSqHdr: SQHDR;
    FXMsg: XMSG;
    pFSqIdx: array of SQIDX;

    function Hash(f: PChar): LongWord;
    procedure EnsureIndex;
    procedure OpenDatFile;
    procedure OpenIdxFile(const Mode: string);

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

function TSquish.Hash(f: PChar): LongWord;
var
  p: PChar;
  h, g: LongWord;
begin
  h := 0;
  p := f;
  while p^ <> #0 do
  begin
    h := (h shl 4) + LongWord(Ord(LowerCase(p^)));
    g := h and $F0000000;
    if g <> 0 then
    begin
      h := h or (g shr 24);
      h := h or g;
    end;
    Inc(p);
  end;
  Result := h and $7FFFFFFF;
end;

procedure TSquish.EnsureIndex;
var
  FileName: string;
begin
  if Length(pFSqIdx) > 0 then Exit;

  { Re-read FSqBase }
  FileName := StrPas(FSqBase.Base) + '.sqd';
  try
    fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
    try
      fpDat.Read(FSqBase, SizeOf(SQBASE));
    finally
      FreeAndNil(fpDat);
    end;
  except
  end;

  if FSqBase.NumMsg > 0 then
  begin
    FileName := StrPas(FSqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        SetLength(pFSqIdx, FSqBase.NumMsg);
        fpIdx.Read(pFSqIdx[0], SizeOf(SQIDX) * FSqBase.NumMsg);
      finally
        FreeAndNil(fpIdx);
      end;
    except
    end;
  end;
end;

procedure TSquish.OpenDatFile;
var
  FileName: string;
begin
  if fpDat <> nil then Exit;
  FileName := StrPas(FSqBase.Base) + '.sqd';
  try
    fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
  except
    fpDat := nil;
  end;
end;

procedure TSquish.OpenIdxFile(const Mode: string);
var
  FileName: string;
begin
  FileName := StrPas(FSqBase.Base) + '.sqi';
  try
    if Mode = 'ab' then
    begin
      if FileExists(FileName) then
        fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
      else
        fpIdx := TFileStream.Create(FileName, fmCreate);
      fpIdx.Position := fpIdx.Size;
    end
    else if Mode = 'wb' then
    begin
      fpIdx := TFileStream.Create(FileName, fmCreate);
    end
    else
    begin
      fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
    end;
  except
    fpIdx := nil;
  end;
end;

constructor TSquish.Create;
begin
  inherited Create;
  fpDat := nil;
  fpIdx := nil;
  FLocked := False;
  FillChar(FSqBase, SizeOf(SQBASE), 0);
end;

constructor TSquish.CreateOpen(const AName: string);
begin
  Create;
  Open(AName);
end;

destructor TSquish.Destroy;
begin
  if FLocked then
    UnLock;
  Close;
  inherited Destroy;
end;

function TSquish.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TSquish.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  Move(AMsgBase.FromAddress, FromAddress, SizeOf(FromAddress));
  Move(AMsgBase.ToAddress, ToAddress, SizeOf(ToAddress));
  Result := AddText(AMsgBase.Text);
end;

function TSquish.AddText(var MsgText: TCollection): Boolean;
var
  FileName: string;
  NoMore: Boolean;
  pText: PChar;
  EndFrame: Int64;
  LocalFSqHdr, LinkHdr: SQHDR;
  LocalFSqIdx: SQIDX;
  LocalFXMsg: XMSG;
  fz, fn, fnd, fp: Word;
  tz, tn, tnd, tp: Word;
  pAddr: string;
  idx, atIdx: Integer;
  NullByte: Byte;
  CrByte: Byte;
begin
  Result := True;
  NullByte := 0;
  CrByte := Ord(#13);

  if not FLocked then
  begin
    OpenDatFile;
    if fpDat <> nil then
      fpDat.Read(FSqBase, SizeOf(SQBASE));
  end;

  if (not FLocked) or (fpIdx = nil) then
    OpenIdxFile('ab');

  if fpDat = nil then Exit;

  { Build frame header }
  FillChar(LocalFSqHdr, SizeOf(SQHDR), 0);
  LocalFSqHdr.Id := SQHDRID;
  LocalFSqHdr.FrameType := FRAME_NORMAL;
  LocalFSqHdr.PrevFrame := FSqBase.LastFrame;
  LocalFSqHdr.NextFrame := 0;

  { Calculate control and message lengths }
  NoMore := False;
  LocalFSqHdr.CLen := 1;
  pText := PChar(MsgText.First);
  while pText <> nil do
  begin
    if (pText[0] = #1) and (not NoMore) then
      LocalFSqHdr.CLen := LocalFSqHdr.CLen + LongWord(StrLen(pText))
    else
    begin
      LocalFSqHdr.MsgLength := LocalFSqHdr.MsgLength + LongWord(StrLen(pText)) + 1;
      NoMore := True;
    end;
    pText := PChar(MsgText.Next);
  end;

  if LocalFSqHdr.CLen = 1 then
    Inc(LocalFSqHdr.CLen);

  LocalFSqHdr.FrameLength := LocalFSqHdr.CLen + LocalFSqHdr.MsgLength + SizeOf(XMSG);
  LocalFSqHdr.MsgLength := LocalFSqHdr.FrameLength;

  fpDat.Position := FSqBase.EndFrame;
  fpDat.Write(LocalFSqHdr, SizeOf(SQHDR));

  { Build XMSG }
  FillChar(LocalFXMsg, SizeOf(XMSG), 0);
  StrCopy(LocalFXMsg.From_, From_);
  StrCopy(LocalFXMsg.To_, To_);
  StrCopy(LocalFXMsg.Subject_, Subject_);
  LocalFXMsg.MsgId := FSqBase.Uid;

  { Parse from address }
  fz := 0; fn := 0; fnd := 0; fp := 0;
  pAddr := StrPas(FromAddress);
  idx := Pos(':', pAddr);
  if idx > 0 then begin fz := StrToIntDef(Copy(pAddr, 1, idx-1), 0); System.Delete(pAddr, 1, idx); end;
  idx := Pos('/', pAddr);
  if idx > 0 then begin fn := StrToIntDef(Copy(pAddr, 1, idx-1), 0); System.Delete(pAddr, 1, idx); end;
  atIdx := Pos('@', pAddr);
  if atIdx > 0 then pAddr := Copy(pAddr, 1, atIdx - 1);
  idx := Pos('.', pAddr);
  if idx > 0 then begin fnd := StrToIntDef(Copy(pAddr, 1, idx-1), 0); fp := StrToIntDef(Copy(pAddr, idx+1, Length(pAddr)), 0); end
  else fnd := StrToIntDef(pAddr, 0);
  LocalFXMsg.Orig.Zone := fz; LocalFXMsg.Orig.Net := fn; LocalFXMsg.Orig.Node := fnd; LocalFXMsg.Orig.Point := fp;

  { Parse to address }
  tz := 0; tn := 0; tnd := 0; tp := 0;
  pAddr := StrPas(ToAddress);
  idx := Pos(':', pAddr);
  if idx > 0 then begin tz := StrToIntDef(Copy(pAddr, 1, idx-1), 0); System.Delete(pAddr, 1, idx); end;
  idx := Pos('/', pAddr);
  if idx > 0 then begin tn := StrToIntDef(Copy(pAddr, 1, idx-1), 0); System.Delete(pAddr, 1, idx); end;
  atIdx := Pos('@', pAddr);
  if atIdx > 0 then pAddr := Copy(pAddr, 1, atIdx - 1);
  idx := Pos('.', pAddr);
  if idx > 0 then begin tnd := StrToIntDef(Copy(pAddr, 1, idx-1), 0); tp := StrToIntDef(Copy(pAddr, idx+1, Length(pAddr)), 0); end
  else tnd := StrToIntDef(pAddr, 0);
  LocalFXMsg.Dest.Zone := tz; LocalFXMsg.Dest.Net := tn; LocalFXMsg.Dest.Node := tnd; LocalFXMsg.Dest.Point := tp;

  { Encode dates }
  LocalFXMsg.DateWritten := Written.Day and $1F;
  LocalFXMsg.DateWritten := LocalFXMsg.DateWritten or (LongWord(Written.Month) shl 5);
  LocalFXMsg.DateWritten := LocalFXMsg.DateWritten or (LongWord(Written.Year - 1980) shl 9);
  LocalFXMsg.DateWritten := LocalFXMsg.DateWritten or (LongWord(Written.Second div 2) shl 16);
  LocalFXMsg.DateWritten := LocalFXMsg.DateWritten or (LongWord(Written.Minute) shl 21);
  LocalFXMsg.DateWritten := LocalFXMsg.DateWritten or (LongWord(Written.Hour) shl 27);

  LocalFXMsg.DateArrived := Arrived.Day and $1F;
  LocalFXMsg.DateArrived := LocalFXMsg.DateArrived or (LongWord(Arrived.Month) shl 5);
  LocalFXMsg.DateArrived := LocalFXMsg.DateArrived or (LongWord(Arrived.Year - 1980) shl 9);
  LocalFXMsg.DateArrived := LocalFXMsg.DateArrived or (LongWord(Arrived.Second div 2) shl 16);
  LocalFXMsg.DateArrived := LocalFXMsg.DateArrived or (LongWord(Arrived.Minute) shl 21);
  LocalFXMsg.DateArrived := LocalFXMsg.DateArrived or (LongWord(Arrived.Hour) shl 27);

  { Set attributes }
  LocalFXMsg.Attr := MSGUID;
  if Crash <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGCRASH;
  if FileAttach <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGFILE;
  if FileRequest <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGFRQ;
  if Hold <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGHOLD;
  if KillSent <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGKILL;
  if Local_ <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGLOCAL;
  if Private_ <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGPRIVATE;
  if ReceiptRequest <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGRRQ;
  if Received <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGREAD;
  if Sent <> 0 then LocalFXMsg.Attr := LocalFXMsg.Attr or MSGSENT;

  LocalFXMsg.ReplyTo := Original;
  LocalFXMsg.Replies[0] := Reply;

  fpDat.Write(LocalFXMsg, SizeOf(XMSG));

  { Write control info (kludge lines starting with ^A) }
  if LocalFSqHdr.CLen > 2 then
  begin
    pText := PChar(MsgText.First);
    while pText <> nil do
    begin
      if pText[0] = #1 then
        fpDat.Write(pText^, StrLen(pText))
      else
        Break;
      pText := PChar(MsgText.Next);
    end;
  end
  else if LocalFSqHdr.CLen = 2 then
    fpDat.Write(PChar(#1)^, 1);
  fpDat.Write(NullByte, 1);

  { Write message body (non-kludge lines) }
  NoMore := False;
  pText := PChar(MsgText.First);
  while pText <> nil do
  begin
    if (pText[0] <> #1) or NoMore then
    begin
      fpDat.Write(pText^, StrLen(pText));
      fpDat.Write(CrByte, 1);
      NoMore := True;
    end;
    pText := PChar(MsgText.Next);
  end;

  EndFrame := fpDat.Position;

  { Link new frame into chain }
  if FSqBase.LastFrame <> 0 then
  begin
    fpDat.Position := FSqBase.LastFrame;
    fpDat.Read(LinkHdr, SizeOf(SQHDR));
    LinkHdr.NextFrame := FSqBase.EndFrame;
    fpDat.Position := FSqBase.LastFrame;
    fpDat.Write(LinkHdr, SizeOf(SQHDR));
  end;
  FSqBase.LastFrame := FSqBase.EndFrame;
  FSqBase.EndFrame := EndFrame;
  if FSqBase.BeginFrame = 0 then
    FSqBase.BeginFrame := FSqBase.LastFrame;

  Inc(FSqBase.Uid);
  Inc(FSqBase.NumMsg);
  Inc(FSqBase.HighMsg);

  if not FLocked then
  begin
    fpDat.Position := 0;
    fpDat.Write(FSqBase, SizeOf(SQBASE));
  end;

  { Write index entry }
  if fpIdx <> nil then
  begin
    if not FLocked then
    begin
      FillChar(LocalFSqIdx, SizeOf(SQIDX), 0);
      LocalFSqIdx.Ofs := FSqBase.LastFrame;
      LocalFSqIdx.MsgId := FSqBase.Uid - 1;
      LocalFSqIdx.Hash := Hash(To_);
      fpIdx.Write(LocalFSqIdx, SizeOf(SQIDX));
    end
    else
    begin
      pFSqIdx[FSqBase.NumMsg - 1].Ofs := FSqBase.LastFrame;
      pFSqIdx[FSqBase.NumMsg - 1].MsgId := FSqBase.Uid - 1;
      pFSqIdx[FSqBase.NumMsg - 1].Hash := Hash(To_);
    end;
  end;

  if not FLocked then
  begin
    FreeAndNil(fpDat);
    FreeAndNil(fpIdx);

    { Re-read state }
    FileName := StrPas(FSqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        fpDat.Read(FSqBase, SizeOf(SQBASE));
      finally
        FreeAndNil(fpDat);
      end;
    except
    end;

    SetLength(pFSqIdx, 0);
    if FSqBase.NumMsg > 0 then
    begin
      FileName := StrPas(FSqBase.Base) + '.sqi';
      try
        fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
        try
          SetLength(pFSqIdx, FSqBase.NumMsg);
          fpIdx.Read(pFSqIdx[0], SizeOf(SQIDX) * FSqBase.NumMsg);
        finally
          FreeAndNil(fpIdx);
        end;
      except
      end;
    end;
  end;
end;

procedure TSquish.Close;
begin
  FreeAndNil(fpIdx);
  FreeAndNil(fpDat);
  SetLength(pFSqIdx, 0);
  Id := 0;
  FLocked := False;
end;

function TSquish.Delete(ulMsg: LongWord): Boolean;
var
  i: Integer;
  FileName: string;
  Position: LongWord;
  LocalFSqHdr, FSqHdrPrev, FSqHdrNext: SQHDR;
begin
  Result := False;
  Position := 0;

  if not FLocked then
  begin
    OpenDatFile;
    if fpDat <> nil then
      fpDat.Read(FSqBase, SizeOf(SQBASE));

    SetLength(pFSqIdx, 0);
    FileName := StrPas(FSqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        SetLength(pFSqIdx, 4500);
        if FSqBase.NumMsg > 0 then
          fpIdx.Read(pFSqIdx[0], Min(Int64(fpIdx.Size), Int64(4500 * SizeOf(SQIDX))));
      finally
        FreeAndNil(fpIdx);
      end;
    except
    end;
  end;

  if Length(pFSqIdx) > 0 then
  begin
    for i := 0 to Integer(FSqBase.NumMsg) - 1 do
    begin
      if pFSqIdx[i].MsgId = ulMsg then
      begin
        Position := pFSqIdx[i].Ofs;
        if (i + 1) < Integer(FSqBase.NumMsg) then
          Move(pFSqIdx[i + 1], pFSqIdx[i], (Integer(FSqBase.NumMsg) - i - 1) * SizeOf(SQIDX));
        Result := True;
        Break;
      end;
    end;
  end;

  if Result and (fpDat <> nil) then
  begin
    fpDat.Position := Position;
    fpDat.Read(LocalFSqHdr, SizeOf(SQHDR));
    LocalFSqHdr.FrameType := FRAME_FREE;

    if LocalFSqHdr.PrevFrame <> 0 then
    begin
      fpDat.Position := LocalFSqHdr.PrevFrame;
      fpDat.Read(FSqHdrPrev, SizeOf(SQHDR));
      FSqHdrPrev.NextFrame := LocalFSqHdr.NextFrame;
      fpDat.Position := LocalFSqHdr.PrevFrame;
      fpDat.Write(FSqHdrPrev, SizeOf(SQHDR));
    end;
    if LocalFSqHdr.NextFrame <> 0 then
    begin
      fpDat.Position := LocalFSqHdr.NextFrame;
      fpDat.Read(FSqHdrNext, SizeOf(SQHDR));
      FSqHdrNext.PrevFrame := LocalFSqHdr.PrevFrame;
      fpDat.Position := LocalFSqHdr.NextFrame;
      fpDat.Write(FSqHdrNext, SizeOf(SQHDR));
    end;

    LocalFSqHdr.NextFrame := 0;
    Dec(FSqBase.NumMsg);
    Dec(FSqBase.HighMsg);

    if FSqBase.FreeFrame = 0 then
      FSqBase.FreeFrame := Position;
    if FSqBase.LastFreeFrame = 0 then
    begin
      FSqBase.LastFreeFrame := Position;
      LocalFSqHdr.PrevFrame := 0;
    end
    else
    begin
      LocalFSqHdr.PrevFrame := FSqBase.LastFreeFrame;
      fpDat.Position := FSqBase.LastFreeFrame;
      fpDat.Read(FSqHdrNext, SizeOf(SQHDR));
      FSqHdrNext.NextFrame := Position;
      fpDat.Position := FSqBase.LastFreeFrame;
      fpDat.Write(FSqHdrNext, SizeOf(SQHDR));
      FSqBase.LastFreeFrame := Position;
    end;

    fpDat.Position := Position;
    fpDat.Write(LocalFSqHdr, SizeOf(SQHDR));

    fpDat.Position := 0;
    fpDat.Write(FSqBase, SizeOf(SQBASE));
  end;

  if not FLocked then
  begin
    FileName := StrPas(FSqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmCreate);
      try
        if FSqBase.NumMsg > 0 then
          fpIdx.Write(pFSqIdx[0], Integer(FSqBase.NumMsg) * SizeOf(SQIDX));
      finally
        FreeAndNil(fpIdx);
      end;
    except
    end;

    { Re-read index }
    SetLength(pFSqIdx, 0);
    if FSqBase.NumMsg > 0 then
    begin
      try
        fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
        try
          SetLength(pFSqIdx, FSqBase.NumMsg);
          fpIdx.Read(pFSqIdx[0], SizeOf(SQIDX) * FSqBase.NumMsg);
        finally
          FreeAndNil(fpIdx);
        end;
      except
      end;
    end;

    FreeAndNil(fpDat);
  end;
end;

function TSquish.GetHWM(var ulMsg: LongWord): Boolean;
var
  FileName: string;
begin
  if not FLocked then
  begin
    FileName := StrPas(FSqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        fpDat.Read(FSqBase, SizeOf(SQBASE));
      finally
        FreeAndNil(fpDat);
      end;
    except
    end;
  end;

  ulMsg := FSqBase.HighWater;
  Result := True;
end;

function TSquish.Highest: LongWord;
begin
  EnsureIndex;
  Result := 0;
  if (FSqBase.NumMsg > 0) and (Length(pFSqIdx) > 0) then
    Result := pFSqIdx[Integer(FSqBase.NumMsg) - 1].MsgId;
end;

function TSquish.Lock(ulTimeout: LongWord): Boolean;
var
  FileName: string;
begin
  if FLocked then
  begin
    SetLength(pFSqIdx, 0);
    FreeAndNil(fpDat);
    FreeAndNil(fpIdx);
  end;

  FileName := StrPas(FSqBase.Base) + '.sqd';
  try
    fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
    fpDat.Read(FSqBase, SizeOf(SQBASE));

    FileName := StrPas(FSqBase.Base) + '.sqi';
    fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
    SetLength(pFSqIdx, 4500);
    FSqBase.NumMsg := fpIdx.Read(pFSqIdx[0], 4500 * SizeOf(SQIDX)) div SizeOf(SQIDX);
    FSqBase.HighMsg := FSqBase.NumMsg;
    fpIdx.Position := fpIdx.Size;
    FLocked := True;
  except
  end;

  Result := True;
end;

function TSquish.Lowest: LongWord;
var
  i: Integer;
begin
  EnsureIndex;
  Result := 0;
  if (FSqBase.NumMsg > 0) and (Length(pFSqIdx) > 0) then
  begin
    i := 0;
    while (i < Integer(FSqBase.NumMsg)) and (pFSqIdx[i].MsgId = $FFFFFFFF) do
      Inc(i);
    if (i < Integer(FSqBase.NumMsg)) and (pFSqIdx[0].MsgId <> $FFFFFFFF) then
      Result := pFSqIdx[0].MsgId;
  end;
end;

function TSquish.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  EnsureIndex;
  Result := 0;
  if (FSqBase.NumMsg > 0) and (Length(pFSqIdx) > 0) then
  begin
    if (ulMsg > 0) and (ulMsg <= FSqBase.NumMsg) then
      Result := pFSqIdx[ulMsg - 1].MsgId;
  end;
  if FSqBase.NumMsg = 0 then
    Result := 0;
end;

procedure TSquish.New;
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

function TSquish.Next(var ulMsg: LongWord): Boolean;
var
  i: Integer;
begin
  Result := False;
  EnsureIndex;

  if (FSqBase.NumMsg > 0) and (Length(pFSqIdx) > 0) then
  begin
    if (pFSqIdx[0].MsgId <> $FFFFFFFF) and (ulMsg < pFSqIdx[0].MsgId) then
    begin
      ulMsg := pFSqIdx[0].MsgId;
      Result := True;
    end
    else
    begin
      for i := 0 to Integer(FSqBase.NumMsg) - 1 do
      begin
        if (pFSqIdx[i].MsgId <> $FFFFFFFF) and (pFSqIdx[i].MsgId >= ulMsg) then
        begin
          if pFSqIdx[i].MsgId = ulMsg then
          begin
            while (i < Integer(FSqBase.NumMsg)) and (pFSqIdx[i].MsgId = ulMsg) do
              Inc(i);
          end;
          if i < Integer(FSqBase.NumMsg) then
          begin
            ulMsg := pFSqIdx[i].MsgId;
            Result := True;
          end;
          Break;
        end;
      end;
    end;
  end;
end;

function TSquish.Number: LongWord;
begin
  Result := FSqBase.NumMsg;
end;

function TSquish.Open(const AName: string): Boolean;
var
  FileName: string;
  fd: TFileStream;
  {$IFDEF UNIX}
  p: Integer;
  BaseName: string;
  {$ENDIF}
begin
  Result := False;

  FileName := AName + '.sqd';
  {$IFDEF UNIX}
  FileName := StringReplace(FileName, '\', '/', [rfReplaceAll]);
  {$ENDIF}

  FillChar(FSqBase, SizeOf(SQBASE), 0);
  StrPCopy(FSqBase.Base, AName);

  try
    if FileExists(FileName) then
      fd := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
    else
      fd := TFileStream.Create(FileName, fmCreate);
    try
      if fd.Read(FSqBase, SizeOf(SQBASE)) < SizeOf(SQBASE) then
      begin
        FillChar(FSqBase, SizeOf(SQBASE), 0);
        FSqBase.Len := SizeOf(SQBASE);
        FSqBase.Uid := 1;
        StrPCopy(FSqBase.Base, AName);
        FSqBase.EndFrame := SizeOf(SQBASE);
        FSqBase.SzSqhdr := SizeOf(SQHDR);
      end;

      StrPCopy(FSqBase.Base, AName);
      {$IFDEF UNIX}
      BaseName := StrPas(FSqBase.Base);
      BaseName := StringReplace(BaseName, '\', '/', [rfReplaceAll]);
      StrPCopy(FSqBase.Base, BaseName);
      {$ENDIF}

      fd.Position := 0;
      fd.Write(FSqBase, SizeOf(SQBASE));
    finally
      fd.Free;
    end;
  except
    Exit;
  end;

  { Create/touch the .sqi file }
  FileName := StrPas(FSqBase.Base) + '.sqi';
  try
    if not FileExists(FileName) then
    begin
      fd := TFileStream.Create(FileName, fmCreate);
      fd.Free;
    end;
  except
  end;

  { Read index if messages exist }
  SetLength(pFSqIdx, 0);
  if FSqBase.NumMsg > 0 then
  begin
    try
      fd := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        SetLength(pFSqIdx, FSqBase.NumMsg);
        fd.Read(pFSqIdx[0], SizeOf(SQIDX) * FSqBase.NumMsg);
      finally
        fd.Free;
      end;
    except
    end;
  end;

  Id := 0;
end;

procedure TSquish.Pack;
var
  fdHdr, fdNewDat: TFileStream;
  fdIdx, fdNewIdx: TFileStream;
  FileName, NewFile: string;
  LocalFSqIdx: SQIDX;
  LocalFSqHdr, FSqHdr2: SQHDR;
  Buffer: array[0..2047] of Byte;
  BytesToRead: LongWord;
begin
  if FLocked then
    UnLock;
  SetLength(pFSqIdx, 0);

  fdHdr := nil; fdNewDat := nil; fdIdx := nil; fdNewIdx := nil;
  try
    FileName := StrPas(FSqBase.Base) + '.sqd';
    if FileExists(FileName) then
      fdHdr := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
    else
      fdHdr := TFileStream.Create(FileName, fmCreate);

    FileName := StrPas(FSqBase.Base) + '.sqi';
    if FileExists(FileName) then
      fdIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
    else
      fdIdx := TFileStream.Create(FileName, fmCreate);

    FileName := StrPas(FSqBase.Base) + '._qd';
    fdNewDat := TFileStream.Create(FileName, fmCreate);

    FileName := StrPas(FSqBase.Base) + '._qi';
    fdNewIdx := TFileStream.Create(FileName, fmCreate);

    fdHdr.Position := 0;
    fdHdr.Read(FSqBase, SizeOf(SQBASE));
    FSqBase.NumMsg := 0;
    FSqBase.HighMsg := 0;
    FSqBase.BeginFrame := SizeOf(SQBASE);
    FSqBase.LastFrame := 0;
    FSqBase.FreeFrame := 0;
    FSqBase.LastFreeFrame := 0;
    FSqBase.EndFrame := 0;
    fdNewDat.Write(FSqBase, SizeOf(SQBASE));

    fdIdx.Position := 0;
    while fdIdx.Read(LocalFSqIdx, SizeOf(SQIDX)) = SizeOf(SQIDX) do
    begin
      fdHdr.Position := LocalFSqIdx.Ofs;
      fdHdr.Read(LocalFSqHdr, SizeOf(SQHDR));
      if (LocalFSqHdr.FrameType = FRAME_NORMAL) and (LocalFSqHdr.Id = SQHDRID) then
      begin
        Inc(FSqBase.NumMsg);
        Inc(FSqBase.HighMsg);

        LocalFSqHdr.PrevFrame := FSqBase.LastFrame;
        LocalFSqHdr.NextFrame := 0;
        LocalFSqHdr.FrameLength := LocalFSqHdr.MsgLength;
        if FSqBase.LastFrame <> 0 then
        begin
          fdNewDat.Position := FSqBase.LastFrame;
          fdNewDat.Read(FSqHdr2, SizeOf(SQHDR));
          FSqHdr2.NextFrame := fdNewDat.Size;
          fdNewDat.Position := FSqBase.LastFrame;
          fdNewDat.Write(FSqHdr2, SizeOf(SQHDR));
        end;
        fdNewDat.Position := fdNewDat.Size;
        FSqBase.LastFrame := fdNewDat.Size;

        LocalFSqIdx.Ofs := fdNewDat.Size;
        fdNewIdx.Write(LocalFSqIdx, SizeOf(SQIDX));
        fdNewDat.Write(LocalFSqHdr, SizeOf(SQHDR));

        { Copy message data }
        while LocalFSqHdr.FrameLength > 0 do
        begin
          BytesToRead := Min(LongWord(SizeOf(Buffer)), LocalFSqHdr.FrameLength);
          fdHdr.Read(Buffer, BytesToRead);
          fdNewDat.Write(Buffer, BytesToRead);
          Dec(LocalFSqHdr.FrameLength, BytesToRead);
        end;
      end;
    end;

    fdNewDat.Position := 0;
    FSqBase.EndFrame := fdNewDat.Size;
    fdNewDat.Write(FSqBase, SizeOf(SQBASE));

  finally
    FreeAndNil(fdNewDat);
    FreeAndNil(fdHdr);
    FreeAndNil(fdNewIdx);
    FreeAndNil(fdIdx);
  end;

  { Rename temp files }
  FileName := StrPas(FSqBase.Base) + '._qd';
  NewFile := StrPas(FSqBase.Base) + '.sqd';
  SysUtils.DeleteFile(NewFile);
  RenameFile(FileName, NewFile);

  FileName := StrPas(FSqBase.Base) + '._qi';
  NewFile := StrPas(FSqBase.Base) + '.sqi';
  SysUtils.DeleteFile(NewFile);
  RenameFile(FileName, NewFile);

  { Clean up temp files if they still exist }
  SysUtils.DeleteFile(StrPas(FSqBase.Base) + '._qd');
  SysUtils.DeleteFile(StrPas(FSqBase.Base) + '._qi');
end;

function TSquish.Previous(var ulMsg: LongWord): Boolean;
var
  i: Integer;
begin
  Result := False;
  EnsureIndex;

  if (FSqBase.NumMsg > 0) and (Length(pFSqIdx) > 0) then
  begin
    if (pFSqIdx[Integer(FSqBase.NumMsg) - 1].MsgId <> $FFFFFFFF) and
       (ulMsg > pFSqIdx[Integer(FSqBase.NumMsg) - 1].MsgId) then
    begin
      ulMsg := pFSqIdx[Integer(FSqBase.NumMsg) - 1].MsgId;
      Result := True;
    end
    else
    begin
      for i := Integer(FSqBase.NumMsg) - 1 downto 0 do
      begin
        if (pFSqIdx[i].MsgId <> $FFFFFFFF) and (pFSqIdx[i].MsgId <= ulMsg) then
        begin
          if pFSqIdx[i].MsgId = ulMsg then
            Dec(i);
          if i >= 0 then
          begin
            ulMsg := pFSqIdx[i].MsgId;
            Result := True;
          end;
          Break;
        end;
      end;
    end;
  end;
end;

function TSquish.ReadHeader(ulMsg: LongWord): Boolean;
var
  i: Integer;
  FileName: string;
  Position: LongWord;
begin
  Result := False;
  New;
  Position := 0;

  EnsureIndex;

  if (Length(pFSqIdx) > 0) and (FSqBase.NumMsg > 0) then
  begin
    for i := 0 to Integer(FSqBase.NumMsg) - 1 do
    begin
      if (pFSqIdx[i].MsgId <> $FFFFFFFF) and (pFSqIdx[i].MsgId = ulMsg) then
      begin
        Result := True;
        Position := pFSqIdx[i].Ofs;
        FSqIdx := pFSqIdx[i];
        Break;
      end;
    end;
  end;

  if Result then
  begin
    if (not FLocked) or (fpDat = nil) then
    begin
      FileName := StrPas(FSqBase.Base) + '.sqd';
      try
        fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      except
        fpDat := nil;
        Result := False;
        Exit;
      end;
    end;

    if (not FLocked) or (fpDat.Position <> Int64(Position)) then
      fpDat.Position := Position;
    fpDat.Read(FSqHdr, SizeOf(SQHDR));

    if (FSqHdr.Id = SQHDRID) and (FSqHdr.FrameType = FRAME_NORMAL) then
    begin
      Current := ulMsg;
      Id := ulMsg;
      fpDat.Read(FXMsg, SizeOf(XMSG));
      StrCopy(From_, FXMsg.From_);
      StrCopy(To_, FXMsg.To_);
      StrCopy(Subject_, FXMsg.Subject_);

      StrPCopy(FromAddress, Format('%u:%u/%u.%u', [FXMsg.Orig.Zone, FXMsg.Orig.Net, FXMsg.Orig.Node, FXMsg.Orig.Point]));
      StrPCopy(ToAddress, Format('%u:%u/%u.%u', [FXMsg.Dest.Zone, FXMsg.Dest.Net, FXMsg.Dest.Node, FXMsg.Dest.Point]));

      Written.Day := FXMsg.DateWritten and $001F;
      Written.Month := (FXMsg.DateWritten and $01E0) shr 5;
      if (Written.Month < 1) or (Written.Month > 12) then Written.Month := 1;
      Written.Year := ((FXMsg.DateWritten and $FE00) shr 9) + 1980;
      Written.Second := ((FXMsg.DateWritten and $001F0000) shr 16) * 2;
      Written.Minute := (FXMsg.DateWritten and $07E00000) shr 21;
      Written.Hour := (FXMsg.DateWritten and $F8000000) shr 27;

      Arrived.Day := FXMsg.DateArrived and $001F;
      Arrived.Month := (FXMsg.DateArrived and $01E0) shr 5;
      if (Arrived.Month < 1) or (Arrived.Month > 12) then Arrived.Month := 1;
      Arrived.Year := ((FXMsg.DateArrived and $FE00) shr 9) + 1980;
      Arrived.Second := ((FXMsg.DateArrived and $001F0000) shr 16) * 2;
      Arrived.Minute := (FXMsg.DateArrived and $07E00000) shr 21;
      Arrived.Hour := (FXMsg.DateArrived and $F8000000) shr 27;

      Original := FXMsg.ReplyTo;
      Reply := FXMsg.Replies[0];

      Crash := Ord((FXMsg.Attr and MSGCRASH) <> 0);
      FileAttach := Ord((FXMsg.Attr and MSGFILE) <> 0);
      FileRequest := Ord((FXMsg.Attr and MSGFRQ) <> 0);
      Hold := Ord((FXMsg.Attr and MSGHOLD) <> 0);
      KillSent := Ord((FXMsg.Attr and MSGKILL) <> 0);
      Local_ := Ord((FXMsg.Attr and MSGLOCAL) <> 0);
      Private_ := Ord((FXMsg.Attr and MSGPRIVATE) <> 0);
      ReceiptRequest := Ord((FXMsg.Attr and MSGRRQ) <> 0);
      Received := Ord((FXMsg.Attr and MSGREAD) <> 0);
      Sent := Ord((FXMsg.Attr and MSGSENT) <> 0);
    end
    else
      Result := False;

    if (not FLocked) and (fpDat <> nil) then
      FreeAndNil(fpDat);
  end;
end;

function TSquish.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function TSquish.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
var
  SkipNext: Boolean;
  i, nReaded, nCol, nRead: SmallInt;
  FileName: string;
  TxtLen: LongInt;
begin
  MsgText.Clear;
  Result := False;

  if not ReadHeader(ulMsg) then Exit;

  if (not FLocked) or (fpDat = nil) then
  begin
    FileName := StrPas(FSqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      fpDat.Position := Int64(FSqIdx.Ofs) + SizeOf(SQHDR) + SizeOf(XMSG);
    except
      fpDat := nil;
      Exit;
    end;
  end;

  { Read control info }
  if (FSqHdr.CLen > 2) and (fpDat <> nil) then
  begin
    TxtLen := LongInt(FSqHdr.CLen);
    pLine := @szLine[0];
    nCol := 0;

    while TxtLen > 0 do
    begin
      nRead := SizeOf(szBuff);
      if nRead > TxtLen then nRead := TxtLen;
      nReaded := fpDat.Read(szBuff, nRead);

      pBuff := @szBuff[0];
      for i := 0 to nReaded - 1 do
      begin
        if (pBuff^ = #13) or (pBuff^ = #1) or ((pBuff^ = #0) and (pLine <> @szLine[0])) then
        begin
          pLine^ := #0;
          if szLine[0] = #1 then
            MsgText.Add(@szLine[0], StrLen(szLine) + 1);
          pLine := @szLine[0];
          nCol := 0;
          if pBuff^ = #1 then
          begin
            pLine^ := #1;
            Inc(pLine);
          end;
        end
        else if (pBuff^ <> #10) and (pBuff^ <> #13) and (pBuff^ <> #0) then
        begin
          pLine^ := pBuff^;
          Inc(pLine);
          Inc(nCol);
          if nCol >= nWidth then
          begin
            pLine^ := #0;
            MsgText.Add(@szLine[0], StrLen(szLine) + 1);
            pLine := @szLine[0];
            pLine^ := #1;
            Inc(pLine);
            nCol := 1;
          end;
        end;
        Inc(pBuff);
      end;

      Dec(TxtLen, nReaded);
    end;
  end
  else if fpDat <> nil then
    fpDat.Read(szBuff, FSqHdr.CLen);

  { Read message body }
  TxtLen := LongInt(FSqHdr.MsgLength - SizeOf(XMSG) - FSqHdr.CLen);
  pLine := @szLine[0];
  nCol := 0;
  SkipNext := False;
  szWrp[0] := #0;

  if (TxtLen > 0) and (fpDat <> nil) then
  begin
    while TxtLen > 0 do
    begin
      nRead := SizeOf(szBuff);
      if nRead > TxtLen then nRead := TxtLen;
      nReaded := fpDat.Read(szBuff, nRead);

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
            begin
              pLine^ := #0;
              Dec(pLine);
            end;
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
            else
              szWrp[0] := #0;
            MsgText.Add(@szLine[0], StrLen(szLine) + 1);
            StrCopy(szLine, szWrp);
            pLine := StrEnd(szLine);
            nCol := StrLen(szLine);
            SkipNext := True;
          end;
        end;
        Inc(pBuff);
      end;

      Dec(TxtLen, nReaded);
    end;
  end;

  if (not FLocked) and (fpDat <> nil) then
    FreeAndNil(fpDat);

  Result := True;
end;

procedure TSquish.SetHWM(ulMsg: LongWord);
var
  FileName: string;
begin
  if not FLocked then
  begin
    FileName := StrPas(FSqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      fpDat.Read(FSqBase, SizeOf(SQBASE));
    except
      fpDat := nil;
    end;
  end;

  FSqBase.HighWater := ulMsg;

  if fpDat <> nil then
  begin
    fpDat.Position := 0;
    fpDat.Write(FSqBase, SizeOf(SQBASE));

    if not FLocked then
      FreeAndNil(fpDat);
  end;
end;

function TSquish.UidToMsgn(ulMsg: LongWord): LongWord;
var
  i: Integer;
begin
  EnsureIndex;
  Result := 0;

  if (FSqBase.NumMsg > 0) and (Length(pFSqIdx) > 0) then
  begin
    for i := 0 to Integer(FSqBase.NumMsg) - 1 do
    begin
      if pFSqIdx[i].MsgId = ulMsg then
      begin
        Result := LongWord(i + 1);
        Break;
      end;
    end;
  end;

  if FSqBase.NumMsg = 0 then
    Result := 0;
end;

procedure TSquish.UnLock;
var
  FileName: string;
begin
  if FLocked and (Length(pFSqIdx) > 0) then
  begin
    FreeAndNil(fpIdx);

    FileName := StrPas(FSqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmCreate);
      if FSqBase.NumMsg > 0 then
        fpIdx.Write(pFSqIdx[0], Integer(FSqBase.NumMsg) * SizeOf(SQIDX));
      FreeAndNil(fpIdx);
    except
      FreeAndNil(fpIdx);
    end;

    if fpDat <> nil then
    begin
      fpDat.Position := 0;
      fpDat.Write(FSqBase, SizeOf(SQBASE));
      FreeAndNil(fpDat);
    end;

    SetLength(pFSqIdx, 0);
    FLocked := False;
  end;
end;

function TSquish.WriteHeader(ulMsg: LongWord): Boolean;
var
  i: Integer;
  FileName: string;
  Position: LongWord;
begin
  Result := False;
  Position := 0;

  EnsureIndex;

  if (FSqBase.NumMsg > 0) and (Length(pFSqIdx) > 0) then
  begin
    for i := 0 to Integer(FSqBase.NumMsg) - 1 do
    begin
      if pFSqIdx[i].MsgId = ulMsg then
      begin
        Result := True;
        Position := pFSqIdx[i].Ofs;
        Break;
      end;
    end;
  end;

  if Result then
  begin
    if (not FLocked) or (fpDat = nil) then
    begin
      FileName := StrPas(FSqBase.Base) + '.sqd';
      try
        fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      except
        fpDat := nil;
        Result := False;
        Exit;
      end;
    end;

    Position := Position + SizeOf(SQHDR);
    if (not FLocked) or (fpDat.Position <> Int64(Position)) then
      fpDat.Position := Position;

    if FSqHdr.FrameType = FRAME_NORMAL then
    begin
      fpDat.Read(FXMsg, SizeOf(XMSG));

      FXMsg.Attr := 0;
      if Crash <> 0 then FXMsg.Attr := FXMsg.Attr or MSGCRASH;
      if FileAttach <> 0 then FXMsg.Attr := FXMsg.Attr or MSGFILE;
      if FileRequest <> 0 then FXMsg.Attr := FXMsg.Attr or MSGFRQ;
      if Hold <> 0 then FXMsg.Attr := FXMsg.Attr or MSGHOLD;
      if KillSent <> 0 then FXMsg.Attr := FXMsg.Attr or MSGKILL;
      if Local_ <> 0 then FXMsg.Attr := FXMsg.Attr or MSGLOCAL;
      if Private_ <> 0 then FXMsg.Attr := FXMsg.Attr or MSGPRIVATE;
      if ReceiptRequest <> 0 then FXMsg.Attr := FXMsg.Attr or MSGRRQ;
      if Received <> 0 then FXMsg.Attr := FXMsg.Attr or MSGREAD;
      if Sent <> 0 then FXMsg.Attr := FXMsg.Attr or MSGSENT;

      FXMsg.ReplyTo := Original;
      FXMsg.Replies[0] := Reply;

      fpDat.Position := Position;
      fpDat.Write(FXMsg, SizeOf(XMSG));
    end;

    if (not FLocked) and (fpDat <> nil) then
      FreeAndNil(fpDat);
  end;
end;

end.
