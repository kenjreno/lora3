{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of packer.cpp - TPacker class
  Manages archive packer/unpacker definitions (packer.dat).
  Identifies archive types by magic bytes, runs pack/unpack commands.
}

unit Packer;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc299;

type
  TPacker = class
  public
    Key:       array[0..15] of Char;
    Display:   array[0..31] of Char;
    PackCmd:   array[0..127] of Char;
    UnpackCmd: array[0..127] of Char;
    Error:     array[0..31] of Char;
    Id:        array[0..31] of Char;
    Position:  LongInt;
    Dos_:      Byte;
    OS2_:      Byte;
    Windows_:  Byte;
    Linux_:    Byte;

    constructor Create; virtual;
    constructor Create(pszDataPath: PChar); virtual;
    destructor Destroy; override;

    function  Add: Word;
    function  CheckArc(pszArcName: PChar): Word;
    function  Delete: Word;
    function  DoPack(pszArcName, pszFiles: PChar): Word;
    function  DoUnpack(pszArcName, pszPath: PChar;
                       pszFiles: PChar = nil): Word;
    function  First(checkOS: Word = 1): Word;
    procedure New_;
    function  Next(checkOS: Word = 1): Word;
    function  Previous(checkOS: Word = 1): Word;
    function  Read(pszKey: PChar; checkOS: Word = 1): Word;
    function  Update: Word;

  private
    fdDat:    TFileStream;
    Command_: array[0..255] of Char;
    DataPath: String;

    function  OpenDat: Boolean;
    procedure Struct2Class(var Pack: PACKER_REC);
    procedure Class2Struct(var Pack: PACKER_REC);
    function  MatchesCurrentOS(var Pack: PACKER_REC): Boolean;
  end;

implementation

function OpenOrCreate(const FileName: String): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

constructor TPacker.Create;
begin
  inherited Create;
  fdDat := nil;
  DataPath := '.' + PathDelim;
end;

constructor TPacker.Create(pszDataPath: PChar);
begin
  inherited Create;
  fdDat := nil;
  DataPath := IncludeTrailingPathDelimiter(StrPas(pszDataPath));
end;

destructor TPacker.Destroy;
begin
  FreeAndNil(fdDat);
  inherited Destroy;
end;

function TPacker.OpenDat: Boolean;
begin
  if fdDat = nil then
    fdDat := OpenOrCreate(DataPath + 'packer.dat');
  Result := (fdDat <> nil);
end;

function TPacker.MatchesCurrentOS(var Pack: PACKER_REC): Boolean;
begin
  {$IFDEF OS2}
  Result := (Pack.OS and OS_OS2) <> 0;
  {$ELSE}
  {$IFDEF WINDOWS}
  Result := (Pack.OS and OS_WINDOWS) <> 0;
  {$ELSE}
  {$IFDEF UNIX}
  Result := (Pack.OS and OS_LINUX) <> 0;
  {$ELSE}
  Result := (Pack.OS and OS_DOS) <> 0;
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

procedure TPacker.Struct2Class(var Pack: PACKER_REC);
begin
  StrCopy(Key, Pack.Key);
  StrCopy(Display, Pack.Display);
  StrCopy(PackCmd, Pack.PackCmd);
  StrCopy(UnpackCmd, Pack.UnpackCmd);
  StrCopy(Id, Pack.Id);
  Position := Pack.Position;
  Dos_ := Ord((Pack.OS and OS_DOS) <> 0);
  OS2_ := Ord((Pack.OS and OS_OS2) <> 0);
  Windows_ := Ord((Pack.OS and OS_WINDOWS) <> 0);
  Linux_ := Ord((Pack.OS and OS_LINUX) <> 0);
end;

procedure TPacker.Class2Struct(var Pack: PACKER_REC);
begin
  FillChar(Pack, SizeOf(PACKER_REC), 0);
  StrCopy(Pack.Key, Key);
  StrCopy(Pack.Display, Display);
  StrCopy(Pack.PackCmd, PackCmd);
  StrCopy(Pack.UnpackCmd, UnpackCmd);
  StrCopy(Pack.Id, Id);
  Pack.Position := Position;
  Pack.OS := 0;
  if Dos_ <> 0 then
    Pack.OS := Pack.OS or OS_DOS;
  if OS2_ <> 0 then
    Pack.OS := Pack.OS or OS_OS2;
  if Windows_ <> 0 then
    Pack.OS := Pack.OS or OS_WINDOWS;
  if Linux_ <> 0 then
    Pack.OS := Pack.OS or OS_LINUX;
end;

function TPacker.Add: Word;
var
  Pack: PACKER_REC;
begin
  Result := 0;
  if not OpenDat then Exit;

  Class2Struct(Pack);
  fdDat.Seek(0, soFromEnd);
  if fdDat.Write(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) then
    Result := 1;
end;

function TPacker.CheckArc(pszArcName: PChar): Word;
var
  fsArc: TFileStream;
  Pack: PACKER_REC;
  Buffer: array[0..15] of Byte;
  p: PChar;
  a: PByte;
  c, c1: Byte;
  Match: Boolean;
begin
  Result := 0;
  if not OpenDat then Exit;

  if not FileExists(StrPas(pszArcName)) then Exit;

  try
    fsArc := TFileStream.Create(StrPas(pszArcName), fmOpenRead or fmShareDenyNone);
    try
      fdDat.Seek(0, soFromBeginning);
      while fdDat.Read(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) do
      begin
        if not MatchesCurrentOS(Pack) then
          Continue;

        { Seek to magic byte position }
        if Pack.Position < 0 then
          fsArc.Seek(fsArc.Size + Pack.Position, soFromBeginning)
        else
          fsArc.Seek(Pack.Position, soFromBeginning);

        FillChar(Buffer, SizeOf(Buffer), 0);
        fsArc.Read(Buffer, SizeOf(Buffer));

        { Compare hex ID string against file bytes }
        p := Pack.Id;
        a := @Buffer[0];
        Match := True;

        while (p^ <> #0) and Match do
        begin
          c := Byte(UpCase(p^)) - Byte('0');
          if c > 9 then Dec(c, 7);
          Inc(p);
          if p^ <> #0 then
          begin
            c1 := Byte(UpCase(p^)) - Byte('0');
            if c1 > 9 then Dec(c1, 7);
            c := (c shl 4) or c1;
            Inc(p);
          end;
          if a^ <> c then
            Match := False;
          Inc(a);
        end;

        if Match then
        begin
          Struct2Class(Pack);
          Result := 1;
          Break;
        end;
      end;
    finally
      fsArc.Free;
    end;
  except
  end;
end;

function TPacker.Delete: Word;
var
  fsNew: TFileStream;
  Pack: PACKER_REC;
  SavedPos: Int64;
begin
  Result := 0;
  if fdDat = nil then Exit;

  fsNew := nil;
  try
    fsNew := TFileStream.Create(DataPath + 'packer.new', fmCreate);

    SavedPos := fdDat.Position;
    fdDat.Seek(0, soFromBeginning);

    while fdDat.Read(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) do
    begin
      if fdDat.Position <> SavedPos then
        fsNew.Write(Pack, SizeOf(PACKER_REC));
    end;

    fdDat.Seek(0, soFromBeginning);
    fsNew.Seek(0, soFromBeginning);

    while fsNew.Read(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) do
      fdDat.Write(Pack, SizeOf(PACKER_REC));
    fdDat.Size := fdDat.Position;

    if fdDat.Position > SavedPos then
      fdDat.Seek(SavedPos, soFromBeginning);
    if Next = 0 then
    begin
      if Previous = 0 then
        New_;
    end;

    Result := 1;
  finally
    FreeAndNil(fsNew);
    SysUtils.DeleteFile(DataPath + 'packer.new');
  end;
end;

function TPacker.DoPack(pszArcName, pszFiles: PChar): Word;
var
  Cmd: String;
begin
  Cmd := StringReplace(StrPas(PackCmd), '%1', StrPas(pszArcName), []);
  Cmd := StringReplace(Cmd, '%a', StrPas(pszArcName), []);
  if pszFiles <> nil then
  begin
    Cmd := StringReplace(Cmd, '%2', StrPas(pszFiles), []);
    Cmd := StringReplace(Cmd, '%f', StrPas(pszFiles), []);
  end;

  SysUtils.ExecuteProcess(UTF8Encode('/bin/sh'), ['-c', Cmd]);
  Result := 1;
end;

function TPacker.DoUnpack(pszArcName, pszPath: PChar;
                           pszFiles: PChar): Word;
var
  Cmd, SavedDir: String;
begin
  Cmd := StringReplace(StrPas(UnpackCmd), '%1', StrPas(pszArcName), []);
  Cmd := StringReplace(Cmd, '%a', StrPas(pszArcName), []);
  Cmd := StringReplace(Cmd, '%2', '', []);
  if pszFiles <> nil then
  begin
    Cmd := StringReplace(Cmd, '%3', StrPas(pszFiles), []);
    Cmd := StringReplace(Cmd, '%f', StrPas(pszFiles), []);
  end;

  SavedDir := GetCurrentDir;
  SetCurrentDir(StrPas(pszPath));
  try
    SysUtils.ExecuteProcess(UTF8Encode('/bin/sh'), ['-c', Cmd]);
  finally
    SetCurrentDir(SavedDir);
  end;
  Result := 1;
end;

function TPacker.First(checkOS: Word): Word;
begin
  if not OpenDat then
  begin
    Result := 0;
    Exit;
  end;

  fdDat.Seek(0, soFromBeginning);
  Result := Next(checkOS);
end;

procedure TPacker.New_;
begin
  FillChar(Key, SizeOf(Key), 0);
  FillChar(Display, SizeOf(Display), 0);
  FillChar(PackCmd, SizeOf(PackCmd), 0);
  FillChar(UnpackCmd, SizeOf(UnpackCmd), 0);
  FillChar(Id, SizeOf(Id), 0);
  Position := 0;
  Dos_ := 0;
  OS2_ := 0;
  Windows_ := 0;
  Linux_ := 0;
end;

function TPacker.Next(checkOS: Word): Word;
var
  Pack: PACKER_REC;
begin
  Result := 0;
  if fdDat = nil then Exit;

  while fdDat.Read(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) do
  begin
    if (checkOS <> 0) and (not MatchesCurrentOS(Pack)) then
      Continue;
    Struct2Class(Pack);
    Result := 1;
    Break;
  end;
end;

function TPacker.Previous(checkOS: Word): Word;
var
  Pack: PACKER_REC;
begin
  Result := 0;
  if fdDat = nil then Exit;

  while fdDat.Position >= SizeOf(PACKER_REC) * 2 do
  begin
    fdDat.Seek(fdDat.Position - SizeOf(PACKER_REC) * 2, soFromBeginning);
    if fdDat.Read(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) then
    begin
      if (checkOS <> 0) and (not MatchesCurrentOS(Pack)) then
        Continue;
      Struct2Class(Pack);
      Result := 1;
      Break;
    end;
  end;
end;

function TPacker.Read(pszKey: PChar; checkOS: Word): Word;
var
  Pack: PACKER_REC;
begin
  Result := 0;
  if not OpenDat then Exit;

  fdDat.Seek(0, soFromBeginning);
  while fdDat.Read(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) do
  begin
    if (checkOS <> 0) and (not MatchesCurrentOS(Pack)) then
      Continue;
    if stricmp(Pack.Key, pszKey) = 0 then
    begin
      Struct2Class(Pack);
      Result := 1;
      Break;
    end;
  end;
end;

function TPacker.Update: Word;
var
  Pack: PACKER_REC;
begin
  Result := 0;
  if (fdDat <> nil) and (fdDat.Position >= SizeOf(PACKER_REC)) then
  begin
    Class2Struct(Pack);
    fdDat.Seek(fdDat.Position - SizeOf(PACKER_REC), soFromBeginning);
    if fdDat.Write(Pack, SizeOf(PACKER_REC)) = SizeOf(PACKER_REC) then
      Result := 1;
  end;
end;

end.
