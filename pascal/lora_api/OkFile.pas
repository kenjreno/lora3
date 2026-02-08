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
  SysUtils, Classes, Defs, Struc299;

type
  TOkFile = class
  public
    Name:       array[0..31] of Char;
    Path:       array[0..127] of Char;
    Pwd:        array[0..31] of Char;
    Normal:     Char;
    Known:      Char;
    Protected_: Char;

    constructor Create; overload;
    constructor Create(pszDataPath: PChar); overload;
    destructor Destroy; override;

    procedure Add;
    procedure DeleteAll;
    function  First: Word;
    function  Next: Word;
    function  Read(pszName: PChar): Word;
    procedure Update;

  private
    fdDat:    TFileStream;
    DataFile: String;
  end;

implementation

function OpenOrCreate(const FileName: String): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

constructor TOkFile.Create;
begin
  inherited Create;
  fdDat := nil;
  DataFile := 'okfile.dat';
end;

constructor TOkFile.Create(pszDataPath: PChar);
begin
  inherited Create;
  fdDat := nil;
  DataFile := IncludeTrailingPathDelimiter(StrPas(pszDataPath)) + 'okfile.dat';
end;

destructor TOkFile.Destroy;
begin
  FreeAndNil(fdDat);
  inherited Destroy;
end;

procedure TOkFile.Add;
var
  DoClose: Boolean;
  ok: Struc299.OKFILE;
begin
  DoClose := False;

  if fdDat = nil then
  begin
    fdDat := OpenOrCreate(DataFile);
    DoClose := True;
  end;

  if fdDat <> nil then
  begin
    FillChar(ok, SizeOf(ok), 0);
    ok.Size := SizeOf(ok);
    StrCopy(ok.Name, Name);
    StrCopy(ok.Path, Path);
    StrCopy(ok.Pwd, Pwd);
    ok.Normal := Normal;
    ok.Known := Known;
    ok.Protected_ := Protected_;

    fdDat.Seek(0, soFromEnd);
    fdDat.Write(ok, SizeOf(ok));
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

procedure TOkFile.DeleteAll;
begin
  FreeAndNil(fdDat);
  SysUtils.DeleteFile(DataFile);
end;

function TOkFile.First: Word;
begin
  if fdDat = nil then
    fdDat := OpenOrCreate(DataFile);

  if fdDat <> nil then
    fdDat.Seek(0, soFromBeginning);

  Result := Next;
end;

function TOkFile.Next: Word;
var
  ok: Struc299.OKFILE;
begin
  Result := 0;

  if fdDat <> nil then
  begin
    if fdDat.Read(ok, SizeOf(ok)) = SizeOf(ok) then
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
  ok: Struc299.OKFILE;
begin
  Result := 0;
  DoClose := False;

  if fdDat = nil then
  begin
    fdDat := OpenOrCreate(DataFile);
    DoClose := True;
  end;

  if fdDat <> nil then
  begin
    fdDat.Seek(0, soFromBeginning);
    while fdDat.Read(ok, SizeOf(ok)) = SizeOf(ok) do
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

  if DoClose then
    FreeAndNil(fdDat);
end;

procedure TOkFile.Update;
var
  ok: Struc299.OKFILE;
begin
  if fdDat <> nil then
  begin
    fdDat.Seek(fdDat.Position - SizeOf(ok), soFromBeginning);
    ok.Size := SizeOf(ok);
    StrCopy(ok.Name, Name);
    StrCopy(ok.Path, Path);
    StrCopy(ok.Pwd, Pwd);
    ok.Normal := Normal;
    ok.Known := Known;
    ok.Protected_ := Protected_;
    fdDat.Write(ok, SizeOf(ok));
  end;
end;

end.
