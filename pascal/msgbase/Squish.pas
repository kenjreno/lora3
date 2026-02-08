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
    SqBase: SQBASE;
    SqIdx: SQIDX;
    SqHdr: SQHDR;
    XMsg: XMSG;
    pSqIdx: array of SQIDX;

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
  if Length(pSqIdx) > 0 then Exit;

  { Re-read SqBase }
  FileName := StrPas(SqBase.Base) + '.sqd';
  try
    fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
    try
      fpDat.Read(SqBase, SizeOf(SQBASE));
    finally
      FreeAndNil(fpDat);
    end;
  except
  end;

  if SqBase.NumMsg > 0 then
  begin
    FileName := StrPas(SqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        SetLength(pSqIdx, SqBase.NumMsg);
        fpIdx.Read(pSqIdx[0], SizeOf(SQIDX) * SqBase.NumMsg);
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
  FileName := StrPas(SqBase.Base) + '.sqd';
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
  FileName := StrPas(SqBase.Base) + '.sqi';
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
  FillChar(SqBase, SizeOf(SQBASE), 0);
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
  LocalSqHdr, LinkHdr: SQHDR;
  LocalSqIdx: SQIDX;
  LocalXMsg: XMSG;
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
      fpDat.Read(SqBase, SizeOf(SQBASE));
  end;

  if (not FLocked) or (fpIdx = nil) then
    OpenIdxFile('ab');

  if fpDat = nil then Exit;

  { Build frame header }
  FillChar(LocalSqHdr, SizeOf(SQHDR), 0);
  LocalSqHdr.Id := SQHDRID;
  LocalSqHdr.FrameType := FRAME_NORMAL;
  LocalSqHdr.PrevFrame := SqBase.LastFrame;
  LocalSqHdr.NextFrame := 0;

  { Calculate control and message lengths }
  NoMore := False;
  LocalSqHdr.CLen := 1;
  pText := PChar(MsgText.First);
  while pText <> nil do
  begin
    if (pText[0] = #1) and (not NoMore) then
      LocalSqHdr.CLen := LocalSqHdr.CLen + LongWord(StrLen(pText))
    else
    begin
      LocalSqHdr.MsgLength := LocalSqHdr.MsgLength + LongWord(StrLen(pText)) + 1;
      NoMore := True;
    end;
    pText := PChar(MsgText.Next);
  end;

  if LocalSqHdr.CLen = 1 then
    Inc(LocalSqHdr.CLen);

  LocalSqHdr.FrameLength := LocalSqHdr.CLen + LocalSqHdr.MsgLength + SizeOf(XMSG);
  LocalSqHdr.MsgLength := LocalSqHdr.FrameLength;

  fpDat.Position := SqBase.EndFrame;
  fpDat.Write(LocalSqHdr, SizeOf(SQHDR));

  { Build XMSG }
  FillChar(LocalXMsg, SizeOf(XMSG), 0);
  StrCopy(LocalXMsg.From_, From_);
  StrCopy(LocalXMsg.To_, To_);
  StrCopy(LocalXMsg.Subject_, Subject_);
  LocalXMsg.MsgId := SqBase.Uid;

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
  LocalXMsg.Orig.Zone := fz; LocalXMsg.Orig.Net := fn; LocalXMsg.Orig.Node := fnd; LocalXMsg.Orig.Point := fp;

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
  LocalXMsg.Dest.Zone := tz; LocalXMsg.Dest.Net := tn; LocalXMsg.Dest.Node := tnd; LocalXMsg.Dest.Point := tp;

  { Encode dates }
  LocalXMsg.DateWritten := Written.Day and $1F;
  LocalXMsg.DateWritten := LocalXMsg.DateWritten or (LongWord(Written.Month) shl 5);
  LocalXMsg.DateWritten := LocalXMsg.DateWritten or (LongWord(Written.Year - 1980) shl 9);
  LocalXMsg.DateWritten := LocalXMsg.DateWritten or (LongWord(Written.Second div 2) shl 16);
  LocalXMsg.DateWritten := LocalXMsg.DateWritten or (LongWord(Written.Minute) shl 21);
  LocalXMsg.DateWritten := LocalXMsg.DateWritten or (LongWord(Written.Hour) shl 27);

  LocalXMsg.DateArrived := Arrived.Day and $1F;
  LocalXMsg.DateArrived := LocalXMsg.DateArrived or (LongWord(Arrived.Month) shl 5);
  LocalXMsg.DateArrived := LocalXMsg.DateArrived or (LongWord(Arrived.Year - 1980) shl 9);
  LocalXMsg.DateArrived := LocalXMsg.DateArrived or (LongWord(Arrived.Second div 2) shl 16);
  LocalXMsg.DateArrived := LocalXMsg.DateArrived or (LongWord(Arrived.Minute) shl 21);
  LocalXMsg.DateArrived := LocalXMsg.DateArrived or (LongWord(Arrived.Hour) shl 27);

  { Set attributes }
  LocalXMsg.Attr := MSGUID;
  if Crash <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGCRASH;
  if FileAttach <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGFILE;
  if FileRequest <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGFRQ;
  if Hold <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGHOLD;
  if KillSent <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGKILL;
  if Local_ <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGLOCAL;
  if Private_ <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGPRIVATE;
  if ReceiptRequest <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGRRQ;
  if Received <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGREAD;
  if Sent <> 0 then LocalXMsg.Attr := LocalXMsg.Attr or MSGSENT;

  LocalXMsg.ReplyTo := Original;
  LocalXMsg.Replies[0] := Reply;

  fpDat.Write(LocalXMsg, SizeOf(XMSG));

  { Write control info (kludge lines starting with ^A) }
  if LocalSqHdr.CLen > 2 then
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
  else if LocalSqHdr.CLen = 2 then
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
  if SqBase.LastFrame <> 0 then
  begin
    fpDat.Position := SqBase.LastFrame;
    fpDat.Read(LinkHdr, SizeOf(SQHDR));
    LinkHdr.NextFrame := SqBase.EndFrame;
    fpDat.Position := SqBase.LastFrame;
    fpDat.Write(LinkHdr, SizeOf(SQHDR));
  end;
  SqBase.LastFrame := SqBase.EndFrame;
  SqBase.EndFrame := EndFrame;
  if SqBase.BeginFrame = 0 then
    SqBase.BeginFrame := SqBase.LastFrame;

  Inc(SqBase.Uid);
  Inc(SqBase.NumMsg);
  Inc(SqBase.HighMsg);

  if not FLocked then
  begin
    fpDat.Position := 0;
    fpDat.Write(SqBase, SizeOf(SQBASE));
  end;

  { Write index entry }
  if fpIdx <> nil then
  begin
    if not FLocked then
    begin
      FillChar(LocalSqIdx, SizeOf(SQIDX), 0);
      LocalSqIdx.Ofs := SqBase.LastFrame;
      LocalSqIdx.MsgId := SqBase.Uid - 1;
      LocalSqIdx.Hash := Hash(To_);
      fpIdx.Write(LocalSqIdx, SizeOf(SQIDX));
    end
    else
    begin
      pSqIdx[SqBase.NumMsg - 1].Ofs := SqBase.LastFrame;
      pSqIdx[SqBase.NumMsg - 1].MsgId := SqBase.Uid - 1;
      pSqIdx[SqBase.NumMsg - 1].Hash := Hash(To_);
    end;
  end;

  if not FLocked then
  begin
    FreeAndNil(fpDat);
    FreeAndNil(fpIdx);

    { Re-read state }
    FileName := StrPas(SqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        fpDat.Read(SqBase, SizeOf(SQBASE));
      finally
        FreeAndNil(fpDat);
      end;
    except
    end;

    SetLength(pSqIdx, 0);
    if SqBase.NumMsg > 0 then
    begin
      FileName := StrPas(SqBase.Base) + '.sqi';
      try
        fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
        try
          SetLength(pSqIdx, SqBase.NumMsg);
          fpIdx.Read(pSqIdx[0], SizeOf(SQIDX) * SqBase.NumMsg);
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
  SetLength(pSqIdx, 0);
  Id := 0;
  FLocked := False;
end;

function TSquish.Delete(ulMsg: LongWord): Boolean;
var
  i: Integer;
  FileName: string;
  Position: LongWord;
  LocalSqHdr, SqHdrPrev, SqHdrNext: SQHDR;
begin
  Result := False;
  Position := 0;

  if not FLocked then
  begin
    OpenDatFile;
    if fpDat <> nil then
      fpDat.Read(SqBase, SizeOf(SQBASE));

    SetLength(pSqIdx, 0);
    FileName := StrPas(SqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        SetLength(pSqIdx, 4500);
        if SqBase.NumMsg > 0 then
          fpIdx.Read(pSqIdx[0], Min(Int64(fpIdx.Size), Int64(4500 * SizeOf(SQIDX))));
      finally
        FreeAndNil(fpIdx);
      end;
    except
    end;
  end;

  if Length(pSqIdx) > 0 then
  begin
    for i := 0 to Integer(SqBase.NumMsg) - 1 do
    begin
      if pSqIdx[i].MsgId = ulMsg then
      begin
        Position := pSqIdx[i].Ofs;
        if (i + 1) < Integer(SqBase.NumMsg) then
          Move(pSqIdx[i + 1], pSqIdx[i], (Integer(SqBase.NumMsg) - i - 1) * SizeOf(SQIDX));
        Result := True;
        Break;
      end;
    end;
  end;

  if Result and (fpDat <> nil) then
  begin
    fpDat.Position := Position;
    fpDat.Read(LocalSqHdr, SizeOf(SQHDR));
    LocalSqHdr.FrameType := FRAME_FREE;

    if LocalSqHdr.PrevFrame <> 0 then
    begin
      fpDat.Position := LocalSqHdr.PrevFrame;
      fpDat.Read(SqHdrPrev, SizeOf(SQHDR));
      SqHdrPrev.NextFrame := LocalSqHdr.NextFrame;
      fpDat.Position := LocalSqHdr.PrevFrame;
      fpDat.Write(SqHdrPrev, SizeOf(SQHDR));
    end;
    if LocalSqHdr.NextFrame <> 0 then
    begin
      fpDat.Position := LocalSqHdr.NextFrame;
      fpDat.Read(SqHdrNext, SizeOf(SQHDR));
      SqHdrNext.PrevFrame := LocalSqHdr.PrevFrame;
      fpDat.Position := LocalSqHdr.NextFrame;
      fpDat.Write(SqHdrNext, SizeOf(SQHDR));
    end;

    LocalSqHdr.NextFrame := 0;
    Dec(SqBase.NumMsg);
    Dec(SqBase.HighMsg);

    if SqBase.FreeFrame = 0 then
      SqBase.FreeFrame := Position;
    if SqBase.LastFreeFrame = 0 then
    begin
      SqBase.LastFreeFrame := Position;
      LocalSqHdr.PrevFrame := 0;
    end
    else
    begin
      LocalSqHdr.PrevFrame := SqBase.LastFreeFrame;
      fpDat.Position := SqBase.LastFreeFrame;
      fpDat.Read(SqHdrNext, SizeOf(SQHDR));
      SqHdrNext.NextFrame := Position;
      fpDat.Position := SqBase.LastFreeFrame;
      fpDat.Write(SqHdrNext, SizeOf(SQHDR));
      SqBase.LastFreeFrame := Position;
    end;

    fpDat.Position := Position;
    fpDat.Write(LocalSqHdr, SizeOf(SQHDR));

    fpDat.Position := 0;
    fpDat.Write(SqBase, SizeOf(SQBASE));
  end;

  if not FLocked then
  begin
    FileName := StrPas(SqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmCreate);
      try
        if SqBase.NumMsg > 0 then
          fpIdx.Write(pSqIdx[0], Integer(SqBase.NumMsg) * SizeOf(SQIDX));
      finally
        FreeAndNil(fpIdx);
      end;
    except
    end;

    { Re-read index }
    SetLength(pSqIdx, 0);
    if SqBase.NumMsg > 0 then
    begin
      try
        fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
        try
          SetLength(pSqIdx, SqBase.NumMsg);
          fpIdx.Read(pSqIdx[0], SizeOf(SQIDX) * SqBase.NumMsg);
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
    FileName := StrPas(SqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        fpDat.Read(SqBase, SizeOf(SQBASE));
      finally
        FreeAndNil(fpDat);
      end;
    except
    end;
  end;

  ulMsg := SqBase.HighWater;
  Result := True;
end;

function TSquish.Highest: LongWord;
begin
  EnsureIndex;
  Result := 0;
  if (SqBase.NumMsg > 0) and (Length(pSqIdx) > 0) then
    Result := pSqIdx[Integer(SqBase.NumMsg) - 1].MsgId;
end;

function TSquish.Lock(ulTimeout: LongWord): Boolean;
var
  FileName: string;
begin
  if FLocked then
  begin
    SetLength(pSqIdx, 0);
    FreeAndNil(fpDat);
    FreeAndNil(fpIdx);
  end;

  FileName := StrPas(SqBase.Base) + '.sqd';
  try
    fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
    fpDat.Read(SqBase, SizeOf(SQBASE));

    FileName := StrPas(SqBase.Base) + '.sqi';
    fpIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
    SetLength(pSqIdx, 4500);
    SqBase.NumMsg := fpIdx.Read(pSqIdx[0], 4500 * SizeOf(SQIDX)) div SizeOf(SQIDX);
    SqBase.HighMsg := SqBase.NumMsg;
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
  if (SqBase.NumMsg > 0) and (Length(pSqIdx) > 0) then
  begin
    i := 0;
    while (i < Integer(SqBase.NumMsg)) and (pSqIdx[i].MsgId = $FFFFFFFF) do
      Inc(i);
    if (i < Integer(SqBase.NumMsg)) and (pSqIdx[0].MsgId <> $FFFFFFFF) then
      Result := pSqIdx[0].MsgId;
  end;
end;

function TSquish.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  EnsureIndex;
  Result := 0;
  if (SqBase.NumMsg > 0) and (Length(pSqIdx) > 0) then
  begin
    if (ulMsg > 0) and (ulMsg <= SqBase.NumMsg) then
      Result := pSqIdx[ulMsg - 1].MsgId;
  end;
  if SqBase.NumMsg = 0 then
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

  if (SqBase.NumMsg > 0) and (Length(pSqIdx) > 0) then
  begin
    if (pSqIdx[0].MsgId <> $FFFFFFFF) and (ulMsg < pSqIdx[0].MsgId) then
    begin
      ulMsg := pSqIdx[0].MsgId;
      Result := True;
    end
    else
    begin
      for i := 0 to Integer(SqBase.NumMsg) - 1 do
      begin
        if (pSqIdx[i].MsgId <> $FFFFFFFF) and (pSqIdx[i].MsgId >= ulMsg) then
        begin
          if pSqIdx[i].MsgId = ulMsg then
          begin
            while (i < Integer(SqBase.NumMsg)) and (pSqIdx[i].MsgId = ulMsg) do
              Inc(i);
          end;
          if i < Integer(SqBase.NumMsg) then
          begin
            ulMsg := pSqIdx[i].MsgId;
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
  Result := SqBase.NumMsg;
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

  FillChar(SqBase, SizeOf(SQBASE), 0);
  StrPCopy(SqBase.Base, AName);

  try
    if FileExists(FileName) then
      fd := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
    else
      fd := TFileStream.Create(FileName, fmCreate);
    try
      if fd.Read(SqBase, SizeOf(SQBASE)) < SizeOf(SQBASE) then
      begin
        FillChar(SqBase, SizeOf(SQBASE), 0);
        SqBase.Len := SizeOf(SQBASE);
        SqBase.Uid := 1;
        StrPCopy(SqBase.Base, AName);
        SqBase.EndFrame := SizeOf(SQBASE);
        SqBase.SzSqhdr := SizeOf(SQHDR);
      end;

      StrPCopy(SqBase.Base, AName);
      {$IFDEF UNIX}
      BaseName := StrPas(SqBase.Base);
      BaseName := StringReplace(BaseName, '\', '/', [rfReplaceAll]);
      StrPCopy(SqBase.Base, BaseName);
      {$ENDIF}

      fd.Position := 0;
      fd.Write(SqBase, SizeOf(SQBASE));
    finally
      fd.Free;
    end;
  except
    Exit;
  end;

  { Create/touch the .sqi file }
  FileName := StrPas(SqBase.Base) + '.sqi';
  try
    if not FileExists(FileName) then
    begin
      fd := TFileStream.Create(FileName, fmCreate);
      fd.Free;
    end;
  except
  end;

  { Read index if messages exist }
  SetLength(pSqIdx, 0);
  if SqBase.NumMsg > 0 then
  begin
    try
      fd := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      try
        SetLength(pSqIdx, SqBase.NumMsg);
        fd.Read(pSqIdx[0], SizeOf(SQIDX) * SqBase.NumMsg);
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
  LocalSqIdx: SQIDX;
  LocalSqHdr, SqHdr2: SQHDR;
  Buffer: array[0..2047] of Byte;
  BytesToRead: LongWord;
begin
  if FLocked then
    UnLock;
  SetLength(pSqIdx, 0);

  fdHdr := nil; fdNewDat := nil; fdIdx := nil; fdNewIdx := nil;
  try
    FileName := StrPas(SqBase.Base) + '.sqd';
    if FileExists(FileName) then
      fdHdr := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
    else
      fdHdr := TFileStream.Create(FileName, fmCreate);

    FileName := StrPas(SqBase.Base) + '.sqi';
    if FileExists(FileName) then
      fdIdx := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
    else
      fdIdx := TFileStream.Create(FileName, fmCreate);

    FileName := StrPas(SqBase.Base) + '._qd';
    fdNewDat := TFileStream.Create(FileName, fmCreate);

    FileName := StrPas(SqBase.Base) + '._qi';
    fdNewIdx := TFileStream.Create(FileName, fmCreate);

    fdHdr.Position := 0;
    fdHdr.Read(SqBase, SizeOf(SQBASE));
    SqBase.NumMsg := 0;
    SqBase.HighMsg := 0;
    SqBase.BeginFrame := SizeOf(SQBASE);
    SqBase.LastFrame := 0;
    SqBase.FreeFrame := 0;
    SqBase.LastFreeFrame := 0;
    SqBase.EndFrame := 0;
    fdNewDat.Write(SqBase, SizeOf(SQBASE));

    fdIdx.Position := 0;
    while fdIdx.Read(LocalSqIdx, SizeOf(SQIDX)) = SizeOf(SQIDX) do
    begin
      fdHdr.Position := LocalSqIdx.Ofs;
      fdHdr.Read(LocalSqHdr, SizeOf(SQHDR));
      if (LocalSqHdr.FrameType = FRAME_NORMAL) and (LocalSqHdr.Id = SQHDRID) then
      begin
        Inc(SqBase.NumMsg);
        Inc(SqBase.HighMsg);

        LocalSqHdr.PrevFrame := SqBase.LastFrame;
        LocalSqHdr.NextFrame := 0;
        LocalSqHdr.FrameLength := LocalSqHdr.MsgLength;
        if SqBase.LastFrame <> 0 then
        begin
          fdNewDat.Position := SqBase.LastFrame;
          fdNewDat.Read(SqHdr2, SizeOf(SQHDR));
          SqHdr2.NextFrame := fdNewDat.Size;
          fdNewDat.Position := SqBase.LastFrame;
          fdNewDat.Write(SqHdr2, SizeOf(SQHDR));
        end;
        fdNewDat.Position := fdNewDat.Size;
        SqBase.LastFrame := fdNewDat.Size;

        LocalSqIdx.Ofs := fdNewDat.Size;
        fdNewIdx.Write(LocalSqIdx, SizeOf(SQIDX));
        fdNewDat.Write(LocalSqHdr, SizeOf(SQHDR));

        { Copy message data }
        while LocalSqHdr.FrameLength > 0 do
        begin
          BytesToRead := Min(LongWord(SizeOf(Buffer)), LocalSqHdr.FrameLength);
          fdHdr.Read(Buffer, BytesToRead);
          fdNewDat.Write(Buffer, BytesToRead);
          Dec(LocalSqHdr.FrameLength, BytesToRead);
        end;
      end;
    end;

    fdNewDat.Position := 0;
    SqBase.EndFrame := fdNewDat.Size;
    fdNewDat.Write(SqBase, SizeOf(SQBASE));

  finally
    FreeAndNil(fdNewDat);
    FreeAndNil(fdHdr);
    FreeAndNil(fdNewIdx);
    FreeAndNil(fdIdx);
  end;

  { Rename temp files }
  FileName := StrPas(SqBase.Base) + '._qd';
  NewFile := StrPas(SqBase.Base) + '.sqd';
  SysUtils.DeleteFile(NewFile);
  RenameFile(FileName, NewFile);

  FileName := StrPas(SqBase.Base) + '._qi';
  NewFile := StrPas(SqBase.Base) + '.sqi';
  SysUtils.DeleteFile(NewFile);
  RenameFile(FileName, NewFile);

  { Clean up temp files if they still exist }
  SysUtils.DeleteFile(StrPas(SqBase.Base) + '._qd');
  SysUtils.DeleteFile(StrPas(SqBase.Base) + '._qi');
end;

function TSquish.Previous(var ulMsg: LongWord): Boolean;
var
  i: Integer;
begin
  Result := False;
  EnsureIndex;

  if (SqBase.NumMsg > 0) and (Length(pSqIdx) > 0) then
  begin
    if (pSqIdx[Integer(SqBase.NumMsg) - 1].MsgId <> $FFFFFFFF) and
       (ulMsg > pSqIdx[Integer(SqBase.NumMsg) - 1].MsgId) then
    begin
      ulMsg := pSqIdx[Integer(SqBase.NumMsg) - 1].MsgId;
      Result := True;
    end
    else
    begin
      for i := Integer(SqBase.NumMsg) - 1 downto 0 do
      begin
        if (pSqIdx[i].MsgId <> $FFFFFFFF) and (pSqIdx[i].MsgId <= ulMsg) then
        begin
          if pSqIdx[i].MsgId = ulMsg then
            Dec(i);
          if i >= 0 then
          begin
            ulMsg := pSqIdx[i].MsgId;
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

  if (Length(pSqIdx) > 0) and (SqBase.NumMsg > 0) then
  begin
    for i := 0 to Integer(SqBase.NumMsg) - 1 do
    begin
      if (pSqIdx[i].MsgId <> $FFFFFFFF) and (pSqIdx[i].MsgId = ulMsg) then
      begin
        Result := True;
        Position := pSqIdx[i].Ofs;
        SqIdx := pSqIdx[i];
        Break;
      end;
    end;
  end;

  if Result then
  begin
    if (not FLocked) or (fpDat = nil) then
    begin
      FileName := StrPas(SqBase.Base) + '.sqd';
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
    fpDat.Read(SqHdr, SizeOf(SQHDR));

    if (SqHdr.Id = SQHDRID) and (SqHdr.FrameType = FRAME_NORMAL) then
    begin
      Current := ulMsg;
      Id := ulMsg;
      fpDat.Read(XMsg, SizeOf(XMSG));
      StrCopy(From_, XMsg.From_);
      StrCopy(To_, XMsg.To_);
      StrCopy(Subject_, XMsg.Subject_);

      StrPCopy(FromAddress, Format('%u:%u/%u.%u', [XMsg.Orig.Zone, XMsg.Orig.Net, XMsg.Orig.Node, XMsg.Orig.Point]));
      StrPCopy(ToAddress, Format('%u:%u/%u.%u', [XMsg.Dest.Zone, XMsg.Dest.Net, XMsg.Dest.Node, XMsg.Dest.Point]));

      Written.Day := XMsg.DateWritten and $001F;
      Written.Month := (XMsg.DateWritten and $01E0) shr 5;
      if (Written.Month < 1) or (Written.Month > 12) then Written.Month := 1;
      Written.Year := ((XMsg.DateWritten and $FE00) shr 9) + 1980;
      Written.Second := ((XMsg.DateWritten and $001F0000) shr 16) * 2;
      Written.Minute := (XMsg.DateWritten and $07E00000) shr 21;
      Written.Hour := (XMsg.DateWritten and $F8000000) shr 27;

      Arrived.Day := XMsg.DateArrived and $001F;
      Arrived.Month := (XMsg.DateArrived and $01E0) shr 5;
      if (Arrived.Month < 1) or (Arrived.Month > 12) then Arrived.Month := 1;
      Arrived.Year := ((XMsg.DateArrived and $FE00) shr 9) + 1980;
      Arrived.Second := ((XMsg.DateArrived and $001F0000) shr 16) * 2;
      Arrived.Minute := (XMsg.DateArrived and $07E00000) shr 21;
      Arrived.Hour := (XMsg.DateArrived and $F8000000) shr 27;

      Original := XMsg.ReplyTo;
      Reply := XMsg.Replies[0];

      Crash := Ord((XMsg.Attr and MSGCRASH) <> 0);
      FileAttach := Ord((XMsg.Attr and MSGFILE) <> 0);
      FileRequest := Ord((XMsg.Attr and MSGFRQ) <> 0);
      Hold := Ord((XMsg.Attr and MSGHOLD) <> 0);
      KillSent := Ord((XMsg.Attr and MSGKILL) <> 0);
      Local_ := Ord((XMsg.Attr and MSGLOCAL) <> 0);
      Private_ := Ord((XMsg.Attr and MSGPRIVATE) <> 0);
      ReceiptRequest := Ord((XMsg.Attr and MSGRRQ) <> 0);
      Received := Ord((XMsg.Attr and MSGREAD) <> 0);
      Sent := Ord((XMsg.Attr and MSGSENT) <> 0);
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
    FileName := StrPas(SqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      fpDat.Position := Int64(SqIdx.Ofs) + SizeOf(SQHDR) + SizeOf(XMSG);
    except
      fpDat := nil;
      Exit;
    end;
  end;

  { Read control info }
  if (SqHdr.CLen > 2) and (fpDat <> nil) then
  begin
    TxtLen := LongInt(SqHdr.CLen);
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
    fpDat.Read(szBuff, SqHdr.CLen);

  { Read message body }
  TxtLen := LongInt(SqHdr.MsgLength - SizeOf(XMSG) - SqHdr.CLen);
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
    FileName := StrPas(SqBase.Base) + '.sqd';
    try
      fpDat := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone);
      fpDat.Read(SqBase, SizeOf(SQBASE));
    except
      fpDat := nil;
    end;
  end;

  SqBase.HighWater := ulMsg;

  if fpDat <> nil then
  begin
    fpDat.Position := 0;
    fpDat.Write(SqBase, SizeOf(SQBASE));

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

  if (SqBase.NumMsg > 0) and (Length(pSqIdx) > 0) then
  begin
    for i := 0 to Integer(SqBase.NumMsg) - 1 do
    begin
      if pSqIdx[i].MsgId = ulMsg then
      begin
        Result := LongWord(i + 1);
        Break;
      end;
    end;
  end;

  if SqBase.NumMsg = 0 then
    Result := 0;
end;

procedure TSquish.UnLock;
var
  FileName: string;
begin
  if FLocked and (Length(pSqIdx) > 0) then
  begin
    FreeAndNil(fpIdx);

    FileName := StrPas(SqBase.Base) + '.sqi';
    try
      fpIdx := TFileStream.Create(FileName, fmCreate);
      if SqBase.NumMsg > 0 then
        fpIdx.Write(pSqIdx[0], Integer(SqBase.NumMsg) * SizeOf(SQIDX));
      FreeAndNil(fpIdx);
    except
      FreeAndNil(fpIdx);
    end;

    if fpDat <> nil then
    begin
      fpDat.Position := 0;
      fpDat.Write(SqBase, SizeOf(SQBASE));
      FreeAndNil(fpDat);
    end;

    SetLength(pSqIdx, 0);
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

  if (SqBase.NumMsg > 0) and (Length(pSqIdx) > 0) then
  begin
    for i := 0 to Integer(SqBase.NumMsg) - 1 do
    begin
      if pSqIdx[i].MsgId = ulMsg then
      begin
        Result := True;
        Position := pSqIdx[i].Ofs;
        Break;
      end;
    end;
  end;

  if Result then
  begin
    if (not FLocked) or (fpDat = nil) then
    begin
      FileName := StrPas(SqBase.Base) + '.sqd';
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

    if SqHdr.FrameType = FRAME_NORMAL then
    begin
      fpDat.Read(XMsg, SizeOf(XMSG));

      XMsg.Attr := 0;
      if Crash <> 0 then XMsg.Attr := XMsg.Attr or MSGCRASH;
      if FileAttach <> 0 then XMsg.Attr := XMsg.Attr or MSGFILE;
      if FileRequest <> 0 then XMsg.Attr := XMsg.Attr or MSGFRQ;
      if Hold <> 0 then XMsg.Attr := XMsg.Attr or MSGHOLD;
      if KillSent <> 0 then XMsg.Attr := XMsg.Attr or MSGKILL;
      if Local_ <> 0 then XMsg.Attr := XMsg.Attr or MSGLOCAL;
      if Private_ <> 0 then XMsg.Attr := XMsg.Attr or MSGPRIVATE;
      if ReceiptRequest <> 0 then XMsg.Attr := XMsg.Attr or MSGRRQ;
      if Received <> 0 then XMsg.Attr := XMsg.Attr or MSGREAD;
      if Sent <> 0 then XMsg.Attr := XMsg.Attr or MSGSENT;

      XMsg.ReplyTo := Original;
      XMsg.Replies[0] := Reply;

      fpDat.Position := Position;
      fpDat.Write(XMsg, SizeOf(XMSG));
    end;

    if (not FLocked) and (fpDat <> nil) then
      FreeAndNil(fpDat);
  end;
end;

end.
