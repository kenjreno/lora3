{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of okfile.cpp - TOkFile class
  Manages okfile.dat - list of authorized file request names/paths.
}

unit OkFile;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Defs, Struc;

type
  TOkFile = class
  public
    Name:       array[0..31] of Char;
    Path:       array[0..127] of Char;
    Pwd:        array[0..31] of Char;
    Normal:     Char;
    Known:      Char;
    Protected_: Char;

    constructor Create; virtual;
    constructor Create(pszDataPath: PChar); virtual;
    destructor Destroy; override;

    procedure Add;
    procedure DeleteAll;
    function  First: Word;
    function  Next: Word;
    function  Read(pszName: PChar): Word;
    procedure Update;

  private
    fdDat:    LongInt;
    DataFile: array[0..127] of Char;
  end;

implementation

constructor TOkFile.Create;
begin
  inherited Create;
  fdDat := -1;
  StrCopy(DataFile, 'okfile.dat');
end;

constructor TOkFile.Create(pszDataPath: PChar);
begin
  inherited Create;
  fdDat := -1;
  StrCopy(DataFile, pszDataPath);
  StrCat(DataFile, 'okfile.dat');
  AdjustPath(DataFile);
end;

destructor TOkFile.Destroy;
begin
  if fdDat <> -1 then
  begin
    FileClose(fdDat);
    fdDat := -1;
  end;
  inherited Destroy;
end;

procedure TOkFile.Add;
var
  DoClose: Boolean;
  ok: OKFILE;
begin
  DoClose := False;

  if fdDat = -1 then
  begin
    fdDat := FileOpen(StrPas(DataFile), fmOpenReadWrite);
    if fdDat = -1 then
      fdDat := FileCreate(StrPas(DataFile));
    DoClose := True;
  end;

  if fdDat <> -1 then
  begin
    FillChar(ok, SizeOf(ok), 0);
    ok.Size := SizeOf(ok);
    StrCopy(ok.Name, Name);
    StrCopy(ok.Path, Path);
    StrCopy(ok.Pwd, Pwd);
    ok.Normal := Normal;
    ok.Known := Known;
    ok.Protected_ := Protected_;

    FileSeek(fdDat, 0, 2);  { SEEK_END }
    FileWrite(fdDat, ok, SizeOf(ok));
  end;

  if DoClose and (fdDat <> -1) then
  begin
    FileClose(fdDat);
    fdDat := -1;
  end;
end;

procedure TOkFile.DeleteAll;
begin
  if fdDat <> -1 then
  begin
    FileClose(fdDat);
    fdDat := -1;
  end;

  SysUtils.DeleteFile(StrPas(DataFile));
end;

function TOkFile.First: Word;
begin
  if fdDat = -1 then
  begin
    fdDat := FileOpen(StrPas(DataFile), fmOpenReadWrite);
    if fdDat = -1 then
      fdDat := FileCreate(StrPas(DataFile));
  end;

  if fdDat <> -1 then
    FileSeek(fdDat, 0, 0);  { SEEK_SET }

  Result := Next;
end;

function TOkFile.Next: Word;
var
  ok: OKFILE;
begin
  Result := 0;

  if fdDat <> -1 then
  begin
    if FileRead(fdDat, ok, SizeOf(ok)) = SizeOf(ok) then
    begin
      StrCopy(Name, ok.Name);
      StrCopy(Path, ok.Path);
      StrCopy(Pwd, ok.Pwd);
      Normal := ok.Normal;
      Known := ok.Known;
      Protected_ := ok.Protected_;

      Result := 1;
    end;
  end;
end;

function TOkFile.Read(pszName: PChar): Word;
var
  DoClose: Boolean;
  ok: OKFILE;
begin
  Result := 0;
  DoClose := False;

  if fdDat = -1 then
  begin
    fdDat := FileOpen(StrPas(DataFile), fmOpenReadWrite);
    if fdDat = -1 then
      fdDat := FileCreate(StrPas(DataFile));
    DoClose := True;
  end;

  if fdDat <> -1 then
  begin
    FileSeek(fdDat, 0, 0);
    while FileRead(fdDat, ok, SizeOf(ok)) = SizeOf(ok) do
    begin
      if stricmp(ok.Name, pszName) = 0 then
      begin
        StrCopy(Name, ok.Name);
        StrCopy(Path, ok.Path);
        StrCopy(Pwd, ok.Pwd);
        Normal := ok.Normal;
        Known := ok.Known;
        Protected_ := ok.Protected_;

        Result := 1;
        Break;
      end;
    end;
  end;

  if DoClose and (fdDat <> -1) then
  begin
    FileClose(fdDat);
    fdDat := -1;
  end;
end;

procedure TOkFile.Update;
var
  ok: OKFILE;
begin
  if fdDat <> -1 then
  begin
    FileSeek(fdDat, FileSeek(fdDat, 0, 1) - SizeOf(ok), 0);
    ok.Size := SizeOf(ok);
    StrCopy(ok.Name, Name);
    StrCopy(ok.Path, Path);
    StrCopy(ok.Pwd, Pwd);
    ok.Normal := Normal;
    ok.Known := Known;
    ok.Protected_ := Protected_;
    FileWrite(fdDat, ok, SizeOf(ok));
  end;
end;

end.
