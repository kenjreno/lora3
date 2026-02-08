{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of filedata.cpp - TFileData and TFilechoLink classes
  File area data management with indexed dat/idx file pairs, and file echo
  link management for TIC file distribution.
  Uses TFileStream for binary I/O and TCollection for in-memory lists.
}

unit FileData;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc299, Collect, Address;

type
  TFileData = class
  public
    Display:          array[0..127] of Char;
    Key:              array[0..15] of Char;
    Level:            Word;
    AccessFlags:      LongWord;
    DenyFlags:        LongWord;
    UploadLevel:      Word;
    UploadFlags:      LongWord;
    UploadDenyFlags:  LongWord;
    DownloadLevel:    Word;
    DownloadFlags:    LongWord;
    DownloadDenyFlags: LongWord;
    Age:              Byte;
    Download:         array[0..127] of Char;
    Upload:           array[0..127] of Char;
    CdRom:            Char;
    FreeDownload:     Char;
    ShowGlobal:       Char;
    MenuName:         array[0..31] of Char;
    Moderator:        array[0..63] of Char;
    Cost:             LongWord;
    ActiveFiles:      LongWord;
    UnapprovedFiles:  LongWord;
    EchoTag:          array[0..63] of Char;
    UseFilesBBS:      Byte;
    DlCost:           Byte;
    FileList:         array[0..127] of Char;

    constructor Create; virtual;
    constructor Create(pszDataPath: PChar); virtual;
    destructor Destroy; override;

    function  Add: Word;
    procedure Delete;
    function  First: Word;
    function  Insert: Word; overload;
    function  Insert(Data: TFileData): Word; overload;
    function  Last: Word;
    procedure New_;
    function  Next: Word;
    procedure Pack;
    function  Previous: Word;
    function  Read(pszName: PChar; fCloseFile: Word = 1): Word;
    function  ReadEcho(pszEchoTag: PChar): Word;
    function  ReRead: Word;
    function  Update(pszNewKey: PChar = nil): Word;

  private
    fdDat:    TFileStream;
    fdIdx:    TFileStream;
    DataFile: String;
    IdxFile:  String;
    LastKey:  array[0..15] of Char;

    function  OpenFiles: Boolean;
    procedure Class2Struct(var F: FILES_REC);
    procedure Struct2Class(var F: FILES_REC);
    procedure FixPathField(path: PChar);
  end;

  TFilechoLink = class
  public
    Skip4D:       Word;
    EchoTag_:     LongWord;
    Zone:         Word;
    Net:          Word;
    Node:         Word;
    Point:        Word;
    Domain:       array[0..31] of Char;
    Address_:     array[0..63] of Char;
    ShortAddress: array[0..63] of Char;
    SendOnly:     Byte;
    ReceiveOnly:  Byte;
    PersonalOnly: Byte;
    Passive:      Byte;
    Skip:         Byte;

    constructor Create; virtual;
    constructor Create(pszDataPath: PChar); virtual;
    destructor Destroy; override;

    function  Add: Word;
    function  AddString(pszString: PChar): Word;
    procedure Change(pszFrom, pszTo: PChar);
    function  Check(pszAddress: PChar): Word;
    procedure Clear;
    procedure Delete;
    function  First: Word;
    procedure Load(pszEchoTag: PChar);
    procedure New_;
    function  Next: Word;
    function  Previous: Word;
    procedure Save;
    procedure Update;

  private
    DataFile: String;
    Data:     TCollection;
  end;

const
  ECHOLINK_INDEX = 32;

implementation

{ --- Helper --- }

procedure TFileData.FixPathField(path: PChar);
var
  S: String;
begin
  S := StrPas(path);
  if S <> '' then
  begin
    S := IncludeTrailingPathDelimiter(S);
    {$IFDEF UNIX}
    S := StringReplace(S, '\', '/', [rfReplaceAll]);
    {$ELSE}
    S := StringReplace(S, '/', '\', [rfReplaceAll]);
    {$ENDIF}
    StrPCopy(path, S);
  end;
end;

{ --- TFileData --- }

constructor TFileData.Create;
begin
  inherited Create;
  fdDat := nil;
  fdIdx := nil;
  DataFile := 'file.dat';
  IdxFile := 'file.idx';
end;

constructor TFileData.Create(pszDataPath: PChar);
var
  BasePath: String;
begin
  inherited Create;
  fdDat := nil;
  fdIdx := nil;
  BasePath := StrPas(pszDataPath);
  DataFile := BasePath + 'file.dat';
  IdxFile := BasePath + 'file.idx';
  {$IFDEF UNIX}
  DataFile := StringReplace(LowerCase(DataFile), '\', '/', [rfReplaceAll]);
  IdxFile := StringReplace(LowerCase(IdxFile), '\', '/', [rfReplaceAll]);
  {$ELSE}
  DataFile := StringReplace(LowerCase(DataFile), '/', '\', [rfReplaceAll]);
  IdxFile := StringReplace(LowerCase(IdxFile), '/', '\', [rfReplaceAll]);
  {$ENDIF}
end;

destructor TFileData.Destroy;
begin
  FreeAndNil(fdDat);
  FreeAndNil(fdIdx);
  inherited Destroy;
end;

function TFileData.OpenFiles: Boolean;
begin
  if fdIdx = nil then
  begin
    if FileExists(IdxFile) then
      fdIdx := TFileStream.Create(IdxFile, fmOpenReadWrite or fmShareDenyNone)
    else
      fdIdx := TFileStream.Create(IdxFile, fmCreate);
  end;
  if fdDat = nil then
  begin
    if FileExists(DataFile) then
      fdDat := TFileStream.Create(DataFile, fmOpenReadWrite or fmShareDenyNone)
    else
      fdDat := TFileStream.Create(DataFile, fmCreate);
  end;
  Result := (fdIdx <> nil) and (fdDat <> nil);
end;

procedure TFileData.Class2Struct(var F: FILES_REC);
begin
  StrCopy(F.Display, Display);
  StrCopy(F.Key, Key);
  F.Level := Level;
  F.AccessFlags := AccessFlags;
  F.DenyFlags := DenyFlags;
  F.UploadLevel := UploadLevel;
  F.UploadFlags := UploadFlags;
  F.UploadDenyFlags := UploadDenyFlags;
  F.DownloadLevel := DownloadLevel;
  F.DownloadFlags := DownloadFlags;
  F.DownloadDenyFlags := DownloadDenyFlags;
  F.Age := Age;
  StrCopy(F.Download, Download);
  StrCopy(F.Upload, Upload);
  F.CdRom := CdRom;
  F.FreeDownload := FreeDownload;
  F.ShowGlobal := ShowGlobal;
  StrCopy(F.MenuName, MenuName);
  StrCopy(F.Moderator, Moderator);
  F.Cost := Cost;
  F.ActiveFiles := ActiveFiles;
  F.UnapprovedFiles := UnapprovedFiles;
  StrCopy(F.EchoTag, EchoTag);
  F.UseFilesBBS := UseFilesBBS;
  F.DlCost := DlCost;
  StrCopy(F.FileList, FileList);
end;

procedure TFileData.Struct2Class(var F: FILES_REC);
begin
  StrCopy(Display, F.Display);
  StrCopy(Key, F.Key);
  Level := F.Level;
  AccessFlags := F.AccessFlags;
  DenyFlags := F.DenyFlags;
  UploadLevel := F.UploadLevel;
  UploadFlags := F.UploadFlags;
  UploadDenyFlags := F.UploadDenyFlags;
  DownloadLevel := F.DownloadLevel;
  DownloadFlags := F.DownloadFlags;
  DownloadDenyFlags := F.DownloadDenyFlags;
  Age := F.Age;
  StrCopy(Download, F.Download);
  FixPathField(Download);
  StrCopy(Upload, F.Upload);
  FixPathField(Upload);
  CdRom := F.CdRom;
  FreeDownload := F.FreeDownload;
  ShowGlobal := F.ShowGlobal;
  StrCopy(MenuName, F.MenuName);
  StrCopy(Moderator, F.Moderator);
  Cost := F.Cost;
  ActiveFiles := F.ActiveFiles;
  UnapprovedFiles := F.UnapprovedFiles;
  StrCopy(EchoTag, F.EchoTag);
  UseFilesBBS := F.UseFilesBBS;
  DlCost := F.DlCost;
  StrCopy(FileList, F.FileList);

  StrCopy(LastKey, F.Key);
end;

procedure TFileData.New_;
begin
  FillChar(Display, SizeOf(Display), 0);
  FillChar(Key, SizeOf(Key), 0);
  Level := 0;
  AccessFlags := 0;
  DenyFlags := 0;
  UploadLevel := 0;
  UploadFlags := 0;
  UploadDenyFlags := 0;
  DownloadLevel := 0;
  DownloadFlags := 0;
  DownloadDenyFlags := 0;
  Age := 0;
  FillChar(Download, SizeOf(Download), 0);
  FillChar(Upload, SizeOf(Upload), 0);
  CdRom := #0;
  FreeDownload := #0;
  ShowGlobal := Chr(1);
  FillChar(MenuName, SizeOf(MenuName), 0);
  FillChar(Moderator, SizeOf(Moderator), 0);
  Cost := 0;
  ActiveFiles := 0;
  UnapprovedFiles := 0;
  FillChar(EchoTag, SizeOf(EchoTag), 0);
  UseFilesBBS := 0;
  DlCost := 0;
  FillChar(FileList, SizeOf(FileList), 0);
end;

function TFileData.Add: Word;
var
  F: FILES_REC;
  Idx: INDEX;
  DoClose: Boolean;
begin
  Result := 0;
  DoClose := (fdIdx = nil) or (fdDat = nil);
  if not OpenFiles then Exit;

  fdDat.Seek(0, soFromEnd);
  fdIdx.Seek(0, soFromEnd);

  FillChar(F, SizeOf(FILES_REC), 0);
  F.Size := SizeOf(FILES_REC);
  Class2Struct(F);

  FillChar(Idx, SizeOf(INDEX), 0);
  StrCopy(Idx.Key, Key);
  Idx.Level := Level;
  Idx.AccessFlags := AccessFlags;
  Idx.DenyFlags := DenyFlags;
  Idx.Position := fdDat.Position;

  fdDat.Write(F, SizeOf(FILES_REC));
  fdIdx.Write(Idx, SizeOf(INDEX));
  Result := 1;

  if DoClose then
  begin
    FreeAndNil(fdDat);
    FreeAndNil(fdIdx);
  end;
end;

procedure TFileData.Delete;
var
  fsNew: TFileStream;
  F: FILES_REC;
  Idx: INDEX;
  Position: Int64;
begin
  if not OpenFiles then Exit;

  fsNew := TFileStream.Create('Temp2.Dat', fmCreate);
  try
    fdDat.Seek(0, soFromBeginning);
    while fdDat.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) do
    begin
      if StrComp(LastKey, F.Key) <> 0 then
        fsNew.Write(F, SizeOf(FILES_REC));
    end;

    Position := fdIdx.Position;
    if Position > 0 then
      Dec(Position, SizeOf(INDEX));

    FreeAndNil(fdDat);
    FreeAndNil(fdIdx);
    fdIdx := TFileStream.Create(IdxFile, fmCreate);
    fdDat := TFileStream.Create(DataFile, fmCreate);

    fsNew.Seek(0, soFromBeginning);
    while fsNew.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) do
    begin
      FillChar(Idx, SizeOf(INDEX), 0);
      StrCopy(Idx.Key, F.Key);
      Idx.Level := F.Level;
      Idx.AccessFlags := F.AccessFlags;
      Idx.DenyFlags := F.DenyFlags;
      Idx.Position := fdDat.Position;
      fdIdx.Write(Idx, SizeOf(INDEX));
      fdDat.Write(F, SizeOf(FILES_REC));
    end;

    fdIdx.Seek(Position, soFromBeginning);
    if Next = 0 then
    begin
      if Previous = 0 then
        New_;
    end;
  finally
    FreeAndNil(fsNew);
    SysUtils.DeleteFile('Temp2.Dat');
  end;
end;

function TFileData.First: Word;
begin
  Result := 0;
  if not OpenFiles then Exit;

  fdIdx.Seek(0, soFromBeginning);
  fdDat.Seek(0, soFromBeginning);
  Result := Next;
end;

function TFileData.Next: Word;
var
  F: FILES_REC;
  Idx: INDEX;
begin
  Result := 0;
  if (fdDat = nil) or (fdIdx = nil) then Exit;

  while fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) do
  begin
    if (Idx.Flags and IDX_DELETED) = 0 then
    begin
      if fdDat.Position <> Idx.Position then
        fdDat.Seek(Idx.Position, soFromBeginning);
      if fdDat.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) then
      begin
        New_;
        Struct2Class(F);
        Result := 1;
      end;
      Break;
    end;
  end;
end;

function TFileData.Previous: Word;
var
  F: FILES_REC;
  Idx: INDEX;
begin
  Result := 0;
  if (fdDat = nil) or (fdIdx = nil) then Exit;

  while fdIdx.Position >= SizeOf(INDEX) * 2 do
  begin
    fdIdx.Seek(fdIdx.Position - SizeOf(INDEX) * 2, soFromBeginning);
    if fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) then
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        fdDat.Seek(Idx.Position, soFromBeginning);
        if fdDat.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) then
        begin
          New_;
          Struct2Class(F);
          Result := 1;
        end;
        Break;
      end;
    end;
  end;
end;

function TFileData.Last: Word;
var
  F: FILES_REC;
  Idx: INDEX;
begin
  Result := 0;
  if (fdDat = nil) or (fdIdx = nil) then Exit;

  fdIdx.Seek(0, soFromEnd);
  if fdIdx.Position >= SizeOf(INDEX) then
  begin
    fdIdx.Seek(fdIdx.Position - SizeOf(INDEX), soFromBeginning);
    if fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) then
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        fdDat.Seek(Idx.Position, soFromBeginning);
        if fdDat.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) then
        begin
          New_;
          Struct2Class(F);
          Result := 1;
          Exit;
        end;
      end;
    end;
  end;

  { Walk backwards to find non-deleted entry }
  while fdIdx.Position >= SizeOf(INDEX) * 2 do
  begin
    fdIdx.Seek(fdIdx.Position - SizeOf(INDEX) * 2, soFromBeginning);
    if fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) then
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        fdDat.Seek(Idx.Position, soFromBeginning);
        if fdDat.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) then
        begin
          New_;
          Struct2Class(F);
          Result := 1;
        end;
        Break;
      end;
    end;
  end;
end;

function TFileData.Insert: Word;
var
  fsNew: TFileStream;
  F: FILES_REC;
  Idx: INDEX;
  Position: Int64;
begin
  Result := 0;
  if not OpenFiles then Exit;

  fsNew := TFileStream.Create('Temp2.Dat', fmCreate);
  try
    fdDat.Seek(0, soFromBeginning);
    while fdDat.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) do
    begin
      fsNew.Write(F, SizeOf(FILES_REC));
      if StrComp(LastKey, F.Key) = 0 then
      begin
        FillChar(F, SizeOf(FILES_REC), 0);
        F.Size := SizeOf(FILES_REC);
        Class2Struct(F);
        fsNew.Write(F, SizeOf(FILES_REC));
      end;
    end;

    fdDat.Seek(0, soFromBeginning);
    fsNew.Seek(0, soFromBeginning);
    Position := fdIdx.Position;
    fdIdx.Seek(0, soFromBeginning);

    while fsNew.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) do
    begin
      FillChar(Idx, SizeOf(INDEX), 0);
      StrCopy(Idx.Key, F.Key);
      Idx.Level := F.Level;
      Idx.AccessFlags := F.AccessFlags;
      Idx.DenyFlags := F.DenyFlags;
      Idx.Position := fdDat.Position;
      fdIdx.Write(Idx, SizeOf(INDEX));
      fdDat.Write(F, SizeOf(FILES_REC));
    end;

    fdIdx.Seek(Position, soFromBeginning);
    Next;
    Result := 1;
  finally
    FreeAndNil(fsNew);
    SysUtils.DeleteFile('Temp2.Dat');
  end;
end;

function TFileData.Insert(Data: TFileData): Word;
begin
  StrCopy(Display, Data.Display);
  StrCopy(Key, Data.Key);
  Level := Data.Level;
  AccessFlags := Data.AccessFlags;
  DenyFlags := Data.DenyFlags;
  UploadLevel := Data.UploadLevel;
  UploadFlags := Data.UploadFlags;
  UploadDenyFlags := Data.UploadDenyFlags;
  DownloadLevel := Data.DownloadLevel;
  DownloadFlags := Data.DownloadFlags;
  DownloadDenyFlags := Data.DownloadDenyFlags;
  Age := Data.Age;

  StrCopy(Download, Data.Download);
  FixPathField(Download);
  StrCopy(Upload, Data.Upload);
  FixPathField(Upload);

  CdRom := Data.CdRom;
  FreeDownload := Data.FreeDownload;
  ShowGlobal := Data.ShowGlobal;
  StrCopy(MenuName, Data.MenuName);
  StrCopy(Moderator, Data.Moderator);
  Cost := Data.Cost;
  ActiveFiles := Data.ActiveFiles;
  UnapprovedFiles := Data.UnapprovedFiles;
  StrCopy(EchoTag, Data.EchoTag);
  UseFilesBBS := Data.UseFilesBBS;
  DlCost := Data.DlCost;
  StrCopy(FileList, Data.FileList);

  Result := Insert;
end;

procedure TFileData.Pack;
var
  fsNewIdx, fsNewDat: TFileStream;
  F: FILES_REC;
  Idx: INDEX;
begin
  if not OpenFiles then Exit;

  fsNewIdx := nil;
  fsNewDat := nil;
  try
    fsNewIdx := TFileStream.Create('File-New.Idx', fmCreate);
    fsNewDat := TFileStream.Create('File-New.Dat', fmCreate);

    fdIdx.Seek(0, soFromBeginning);
    while fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) do
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        fdDat.Seek(Idx.Position, soFromBeginning);
        fdDat.Read(F, SizeOf(FILES_REC));
        Idx.Position := fsNewDat.Position;
        fsNewDat.Write(F, SizeOf(FILES_REC));
        fsNewIdx.Write(Idx, SizeOf(INDEX));
      end;
    end;

    FreeAndNil(fsNewIdx);
    FreeAndNil(fsNewDat);
    FreeAndNil(fdIdx);
    FreeAndNil(fdDat);

    SysUtils.DeleteFile(DataFile);
    RenameFile('File-New.Dat', DataFile);
    SysUtils.DeleteFile(IdxFile);
    RenameFile('File-New.Idx', IdxFile);
  finally
    FreeAndNil(fsNewIdx);
    FreeAndNil(fsNewDat);
    SysUtils.DeleteFile('File-New.Dat');
    SysUtils.DeleteFile('File-New.Idx');
  end;
end;

function TFileData.Read(pszName: PChar; fCloseFile: Word): Word;
var
  F: FILES_REC;
  Idx: INDEX;
begin
  Result := 0;
  New_;
  if not OpenFiles then Exit;

  fdIdx.Seek(0, soFromBeginning);
  fdDat.Seek(0, soFromBeginning);

  while fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) do
  begin
    if ((Idx.Flags and IDX_DELETED) = 0) and (StrIComp(pszName, Idx.Key) = 0) then
    begin
      fdDat.Seek(Idx.Position, soFromBeginning);
      if fdDat.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) then
      begin
        Struct2Class(F);
        Result := 1;
      end;
      Break;
    end;
  end;

  if fCloseFile <> 0 then
  begin
    FreeAndNil(fdDat);
    FreeAndNil(fdIdx);
  end;
end;

function TFileData.ReadEcho(pszEchoTag: PChar): Word;
var
  fs: TFileStream;
  F: FILES_REC;
begin
  Result := 0;
  New_;
  if not FileExists(DataFile) then Exit;

  try
    fs := TFileStream.Create(DataFile, fmOpenRead or fmShareDenyNone);
    try
      while fs.Read(F, SizeOf(FILES_REC)) = SizeOf(FILES_REC) do
      begin
        if StrIComp(pszEchoTag, F.EchoTag) = 0 then
        begin
          Struct2Class(F);
          Result := 1;
          Break;
        end;
      end;
    finally
      fs.Free;
    end;
  except
  end;
end;

function TFileData.ReRead: Word;
begin
  Result := 0;
  if (fdDat <> nil) and (fdIdx <> nil) then
  begin
    if fdIdx.Position >= SizeOf(INDEX) then
    begin
      fdIdx.Seek(fdIdx.Position - SizeOf(INDEX), soFromBeginning);
      Result := Next;
    end;
  end;
end;

function TFileData.Update(pszNewKey: PChar): Word;
var
  F: FILES_REC;
  Idx: INDEX;
  DoClose: Boolean;
begin
  Result := 0;
  DoClose := (fdIdx = nil) or (fdDat = nil);
  if not OpenFiles then Exit;

  if DoClose then
  begin
    { Opened fresh - search from beginning }
    fdIdx.Seek(0, soFromBeginning);
    while fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) do
    begin
      if ((Idx.Flags and IDX_DELETED) = 0) and (StrIComp(Key, Idx.Key) = 0) then
      begin
        Result := 1;
        Break;
      end;
    end;
  end
  else
  begin
    { Already open - try current position first }
    if fdIdx.Position >= SizeOf(INDEX) then
    begin
      fdIdx.Seek(fdIdx.Position - SizeOf(INDEX), soFromBeginning);
      fdIdx.Read(Idx, SizeOf(INDEX));
      if StrComp(Idx.Key, Key) <> 0 then
      begin
        { Key mismatch, search from start }
        fdIdx.Seek(0, soFromBeginning);
        while fdIdx.Read(Idx, SizeOf(INDEX)) = SizeOf(INDEX) do
        begin
          if ((Idx.Flags and IDX_DELETED) = 0) and (StrIComp(Key, Idx.Key) = 0) then
          begin
            Result := 1;
            Break;
          end;
        end;
      end
      else
        Result := 1;
    end;
  end;

  if (Result = 1) and (fdIdx.Position >= SizeOf(INDEX)) then
  begin
    Result := 0;
    FillChar(F, SizeOf(FILES_REC), 0);
    F.Size := SizeOf(FILES_REC);
    if pszNewKey <> nil then
      StrCopy(Key, pszNewKey);
    Class2Struct(F);

    StrCopy(Idx.Key, Key);
    fdIdx.Seek(fdIdx.Position - SizeOf(INDEX), soFromBeginning);
    fdIdx.Write(Idx, SizeOf(INDEX));

    fdDat.Seek(Idx.Position, soFromBeginning);
    fdDat.Write(F, SizeOf(FILES_REC));
    Result := 1;
  end;

  if DoClose then
  begin
    FreeAndNil(fdDat);
    FreeAndNil(fdIdx);
  end;
end;

{ --- TFilechoLink --- }

constructor TFilechoLink.Create;
begin
  inherited Create;
  DataFile := 'fecholnk.dat';
  Skip4D := 0;
  Data := TCollection.Create;
end;

constructor TFilechoLink.Create(pszDataPath: PChar);
var
  S: String;
begin
  inherited Create;
  S := IncludeTrailingPathDelimiter(StrPas(pszDataPath)) + 'fecholnk.dat';
  {$IFDEF UNIX}
  DataFile := StringReplace(S, '\', '/', [rfReplaceAll]);
  {$ELSE}
  DataFile := StringReplace(S, '/', '\', [rfReplaceAll]);
  {$ENDIF}
  Skip4D := 0;
  Data := TCollection.Create;
end;

destructor TFilechoLink.Destroy;
begin
  Data.Free;
  inherited Destroy;
end;

procedure TFilechoLink.New_;
begin
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  Address_[0] := #0;
  Domain[0] := #0;
  SendOnly := 0;
  ReceiveOnly := 0;
  PersonalOnly := 0;
  Passive := 0;
  Skip := 0;
end;

procedure TFilechoLink.Clear;
begin
  Data.Clear;
  New_;
end;

procedure TFilechoLink.Delete;
begin
  if Data.Value <> nil then
    Data.Remove;
end;

function TFilechoLink.Add: Word;
var
  Buffer: ECHOLINK;
  Current: PECHOLINK;
  Inserted: Boolean;
begin
  FillChar(Buffer, SizeOf(ECHOLINK), 0);
  Buffer.Free := 0;
  Buffer.EchoTag := EchoTag_;
  Buffer.Zone := Zone;
  Buffer.Net := Net;
  Buffer.Node := Node;
  Buffer.Point := Point;
  StrCopy(Buffer.Domain, Domain);
  Buffer.SendOnly := SendOnly;
  Buffer.ReceiveOnly := ReceiveOnly;
  Buffer.PersonalOnly := PersonalOnly;
  Buffer.Passive := Passive;
  Buffer.Skip := Skip;

  Inserted := False;
  Current := PECHOLINK(Data.First);

  if Current <> nil then
  begin
    { Check if insert before first }
    if (Current^.Zone > Zone) or
       ((Current^.Zone = Zone) and (Current^.Net > Net)) or
       ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node > Node)) or
       ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node = Node) and (Current^.Point > Point)) then
    begin
      Data.Insert(@Buffer, SizeOf(ECHOLINK));
      Data.Insert(Current, SizeOf(ECHOLINK));
      Data.First;
      Data.Remove;
      Data.First;
      Inserted := True;
    end
    else
    begin
      Current := PECHOLINK(Data.Next);
      while Current <> nil do
      begin
        if (Current^.Zone > Zone) or
           ((Current^.Zone = Zone) and (Current^.Net > Net)) or
           ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node > Node)) or
           ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node = Node) and (Current^.Point > Point)) then
        begin
          Data.Previous;
          Data.Insert(@Buffer, SizeOf(ECHOLINK));
          Inserted := True;
          Break;
        end;
        Current := PECHOLINK(Data.Next);
      end;
      if not Inserted then
      begin
        Data.Add(@Buffer, SizeOf(ECHOLINK));
        Inserted := True;
      end;
    end;
  end
  else
  begin
    Data.Add(@Buffer, SizeOf(ECHOLINK));
    Inserted := True;
  end;

  Result := Ord(Inserted);
end;

function TFilechoLink.AddString(pszString: PChar): Word;
var
  Temp, Token: String;
  p: Integer;
  Addr: TAddress;
begin
  Result := 0;
  Temp := StrPas(pszString);
  Addr := TAddress.Create;
  try
    while Temp <> '' do
    begin
      Temp := TrimLeft(Temp);
      if Temp = '' then Break;
      p := Pos(' ', Temp);
      if p > 0 then
      begin
        Token := Copy(Temp, 1, p - 1);
        System.Delete(Temp, 1, p);
      end
      else
      begin
        Token := Temp;
        Temp := '';
      end;

      Skip := 0;
      ReceiveOnly := 0;
      SendOnly := 0;
      PersonalOnly := 0;

      if Check(PChar(Token)) = 0 then
      begin
        { Strip prefix modifiers }
        while (Length(Token) > 0) and not (Token[1] in ['0'..'9', '.']) do
        begin
          if Token[1] = '>' then ReceiveOnly := 1;
          if Token[1] = '<' then SendOnly := 1;
          if Token[1] = '!' then PersonalOnly := 1;
          System.Delete(Token, 1, 1);
        end;
        Addr.Parse(PChar(Token));
        if Addr.Zone <> 0 then Zone := Addr.Zone;
        if Addr.Net <> 0 then Net := Addr.Net;
        if Addr.Node <> 0 then Node := Addr.Node;
        Point := Addr.Point;
        StrCopy(Domain, Addr.Domain);
        Result := Add;
      end;
    end;
  finally
    Addr.Free;
  end;
end;

procedure TFilechoLink.Change(pszFrom, pszTo: PChar);
var
  fs: TFileStream;
  Buffer: array[0..ECHOLINK_INDEX - 1] of ECHOLINK;
  CrcFrom, CrcTo: LongWord;
  Count, i: Integer;
  Position: Int64;
  Changed: Boolean;
begin
  CrcFrom := StringCrc32(StrPas(pszFrom), $FFFFFFFF);
  CrcTo := StringCrc32(StrPas(pszTo), $FFFFFFFF);

  if not FileExists(DataFile) then Exit;

  try
    fs := TFileStream.Create(DataFile, fmOpenReadWrite or fmShareDenyNone);
    try
      repeat
        Changed := False;
        Position := fs.Position;
        Count := fs.Read(Buffer, SizeOf(ECHOLINK) * ECHOLINK_INDEX) div SizeOf(ECHOLINK);
        for i := 0 to Count - 1 do
        begin
          if Buffer[i].EchoTag = CrcFrom then
          begin
            Buffer[i].EchoTag := CrcTo;
            Changed := True;
          end;
        end;
        if Changed then
        begin
          fs.Seek(Position, soFromBeginning);
          fs.Write(Buffer, SizeOf(ECHOLINK) * Count);
        end;
      until Count < ECHOLINK_INDEX;
    finally
      fs.Free;
    end;
  except
  end;
end;

function TFilechoLink.Check(pszAddress: PChar): Word;
var
  El: PECHOLINK;
  Addr: TAddress;
  S: String;
begin
  Result := 0;
  S := StrPas(pszAddress);
  { Skip non-digit prefix }
  while (Length(S) > 0) and not (S[1] in ['0'..'9', '.']) do
    System.Delete(S, 1, 1);

  Addr := TAddress.Create;
  try
    Addr.Parse(PChar(S));

    El := PECHOLINK(Data.First);
    while El <> nil do
    begin
      if (El^.Zone = Addr.Zone) and (El^.Net = Addr.Net) and
         (El^.Node = Addr.Node) and (El^.Point = Addr.Point) then
      begin
        EchoTag_ := El^.EchoTag;
        Zone := El^.Zone;
        Net := El^.Net;
        Node := El^.Node;
        Point := El^.Point;
        StrCopy(Domain, El^.Domain);
        SendOnly := El^.SendOnly;
        ReceiveOnly := El^.ReceiveOnly;
        PersonalOnly := El^.PersonalOnly;
        Passive := El^.Passive;
        Skip := El^.Skip;
        if Point = 0 then
          StrPCopy(Address_, Format('%u:%u/%u', [Zone, Net, Node]))
        else
          StrPCopy(Address_, Format('%u:%u/%u.%u', [Zone, Net, Node, Point]));
        if Domain[0] <> #0 then
        begin
          StrCat(Address_, '@');
          StrCat(Address_, Domain);
        end;
        Result := 1;
        Break;
      end;
      El := PECHOLINK(Data.Next);
    end;
  finally
    Addr.Free;
  end;
end;

function TFilechoLink.First: Word;
var
  El: PECHOLINK;
begin
  Result := 0;
  El := PECHOLINK(Data.First);
  if El <> nil then
  begin
    EchoTag_ := El^.EchoTag;
    Zone := El^.Zone;
    Net := El^.Net;
    Node := El^.Node;
    Point := El^.Point;
    StrCopy(Domain, El^.Domain);
    SendOnly := El^.SendOnly;
    ReceiveOnly := El^.ReceiveOnly;
    PersonalOnly := El^.PersonalOnly;
    Passive := El^.Passive;
    Skip := El^.Skip;
    if Point = 0 then
      StrPCopy(Address_, Format('%u:%u/%u', [Zone, Net, Node]))
    else
      StrPCopy(Address_, Format('%u:%u/%u.%u', [Zone, Net, Node, Point]));
    if Domain[0] <> #0 then
    begin
      StrCat(Address_, '@');
      StrCat(Address_, Domain);
    end;
    if (Skip4D <> 0) and (Point <> 0) then
      ShortAddress[0] := #0
    else
      StrCopy(ShortAddress, Address_);
    Result := 1;
  end;
end;

function TFilechoLink.Next: Word;
var
  El: PECHOLINK;
  OldZone, OldNet, OldNode: Word;
begin
  Result := 0;
  OldZone := Zone;
  OldNet := Net;
  OldNode := Node;

  El := PECHOLINK(Data.Next);
  if El <> nil then
  begin
    { Build short address based on what changed }
    if (Skip4D = 0) or (El^.Point = 0) then
    begin
      if El^.Zone <> OldZone then
      begin
        if El^.Point = 0 then
          StrPCopy(ShortAddress, Format('%u:%u/%u', [El^.Zone, El^.Net, El^.Node]))
        else
          StrPCopy(ShortAddress, Format('%u:%u/%u.%u', [El^.Zone, El^.Net, El^.Node, El^.Point]));
      end
      else if El^.Net <> OldNet then
      begin
        if El^.Point = 0 then
          StrPCopy(ShortAddress, Format('%u/%u', [El^.Net, El^.Node]))
        else
          StrPCopy(ShortAddress, Format('%u/%u.%u', [El^.Net, El^.Node, El^.Point]));
      end
      else if El^.Node <> OldNode then
      begin
        if El^.Point = 0 then
          StrPCopy(ShortAddress, Format('%u', [El^.Node]))
        else
          StrPCopy(ShortAddress, Format('%u.%u', [El^.Node, El^.Point]));
      end
      else
        StrPCopy(ShortAddress, Format('.%u', [El^.Point]));
    end
    else
      ShortAddress[0] := #0;

    EchoTag_ := El^.EchoTag;
    Zone := El^.Zone;
    Net := El^.Net;
    Node := El^.Node;
    Point := El^.Point;
    StrCopy(Domain, El^.Domain);
    SendOnly := El^.SendOnly;
    ReceiveOnly := El^.ReceiveOnly;
    PersonalOnly := El^.PersonalOnly;
    Passive := El^.Passive;
    Skip := El^.Skip;
    if Point = 0 then
      StrPCopy(Address_, Format('%u:%u/%u', [Zone, Net, Node]))
    else
      StrPCopy(Address_, Format('%u:%u/%u.%u', [Zone, Net, Node, Point]));
    if Domain[0] <> #0 then
    begin
      StrCat(Address_, '@');
      StrCat(Address_, Domain);
    end;
    Result := 1;
  end;
end;

function TFilechoLink.Previous: Word;
var
  El: PECHOLINK;
begin
  Result := 0;
  El := PECHOLINK(Data.Previous);
  if El <> nil then
  begin
    EchoTag_ := El^.EchoTag;
    Zone := El^.Zone;
    Net := El^.Net;
    Node := El^.Node;
    Point := El^.Point;
    StrCopy(Domain, El^.Domain);
    SendOnly := El^.SendOnly;
    ReceiveOnly := El^.ReceiveOnly;
    PersonalOnly := El^.PersonalOnly;
    Passive := El^.Passive;
    Skip := El^.Skip;
    if Point = 0 then
      StrPCopy(Address_, Format('%u:%u/%u', [Zone, Net, Node]))
    else
      StrPCopy(Address_, Format('%u:%u/%u.%u', [Zone, Net, Node, Point]));
    if Domain[0] <> #0 then
    begin
      StrCat(Address_, '@');
      StrCat(Address_, Domain);
    end;
    Result := 1;
  end;
end;

procedure TFilechoLink.Load(pszEchoTag: PChar);
var
  fs: TFileStream;
  Buffer: array[0..ECHOLINK_INDEX - 1] of ECHOLINK;
  Crc: LongWord;
  Count, i: Integer;
  Temp: String;
begin
  Data.Clear;
  Temp := UpperCase(StrPas(pszEchoTag));
  Crc := StringCrc32(Temp, $FFFFFFFF);
  EchoTag_ := Crc;

  if not FileExists(DataFile) then Exit;

  try
    fs := TFileStream.Create(DataFile, fmOpenRead or fmShareDenyNone);
    try
      repeat
        Count := fs.Read(Buffer, SizeOf(ECHOLINK) * ECHOLINK_INDEX) div SizeOf(ECHOLINK);
        for i := 0 to Count - 1 do
        begin
          if (Buffer[i].Free = 0) and (Buffer[i].EchoTag = Crc) then
            Data.Add(@Buffer[i], SizeOf(ECHOLINK));
        end;
      until Count < ECHOLINK_INDEX;
    finally
      fs.Free;
    end;
  except
  end;

  First;
end;

procedure TFilechoLink.Save;
var
  fs: TFileStream;
  Buffer: array[0..ECHOLINK_INDEX - 1] of ECHOLINK;
  Record_: PECHOLINK;
  Count, i: Integer;
  Position: Int64;
  Changed: Boolean;
begin
  if not FileExists(DataFile) then
  begin
    try
      fs := TFileStream.Create(DataFile, fmCreate);
    except
      Exit;
    end;
  end
  else
  begin
    try
      fs := TFileStream.Create(DataFile, fmOpenReadWrite or fmShareDenyNone);
    except
      Exit;
    end;
  end;

  try
    Record_ := PECHOLINK(Data.First);

    repeat
      Changed := False;
      Position := fs.Position;
      Count := fs.Read(Buffer, SizeOf(ECHOLINK) * ECHOLINK_INDEX) div SizeOf(ECHOLINK);

      for i := 0 to Count - 1 do
      begin
        if Record_ <> nil then
        begin
          if (Buffer[i].EchoTag = Record_^.EchoTag) or (Buffer[i].Free <> 0) then
          begin
            Move(Record_^, Buffer[i], SizeOf(ECHOLINK));
            Record_ := PECHOLINK(Data.Next);
            Changed := True;
          end;
        end;
      end;

      { Mark remaining entries with our tag as free }
      for i := 0 to Count - 1 do
      begin
        if Buffer[i].EchoTag = EchoTag_ then
        begin
          FillChar(Buffer[i], SizeOf(ECHOLINK), 0);
          Buffer[i].Free := 1;
          Changed := True;
        end;
      end;

      if Changed then
      begin
        fs.Seek(Position, soFromBeginning);
        fs.Write(Buffer, SizeOf(ECHOLINK) * Count);
      end;
    until Count < ECHOLINK_INDEX;

    { Append remaining records }
    while Record_ <> nil do
    begin
      fs.Write(Record_^, SizeOf(ECHOLINK));
      Record_ := PECHOLINK(Data.Next);
    end;
  finally
    fs.Free;
  end;
end;

procedure TFilechoLink.Update;
var
  Buffer: PECHOLINK;
begin
  Buffer := PECHOLINK(Data.Value);
  if Buffer <> nil then
  begin
    Buffer^.EchoTag := EchoTag_;
    Buffer^.Zone := Zone;
    Buffer^.Net := Net;
    Buffer^.Node := Node;
    Buffer^.Point := Point;
    StrCopy(Buffer^.Domain, Domain);
    Buffer^.SendOnly := SendOnly;
    Buffer^.ReceiveOnly := ReceiveOnly;
    Buffer^.PersonalOnly := PersonalOnly;
    Buffer^.Passive := Passive;
    Buffer^.Skip := Skip;
    if Point = 0 then
      StrPCopy(Address_, Format('%u:%u/%u', [Zone, Net, Node]))
    else
      StrPCopy(Address_, Format('%u:%u/%u.%u', [Zone, Net, Node, Point]));
    if Domain[0] <> #0 then
    begin
      StrCat(Address_, '@');
      StrCat(Address_, Domain);
    end;
  end;
end;

end.
