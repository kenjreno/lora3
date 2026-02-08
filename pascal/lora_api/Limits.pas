{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of limits.cpp - TLimits class
  Manages limits.dat - user access level limits and download restrictions.
}

unit Limits;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc;

type
  TLimits = class
  public
    Key:              array[0..15] of Char;
    Description:      array[0..31] of Char;
    Level:            Word;
    Flags:            LongWord;
    DenyFlags:        LongWord;
    CallTimeLimit:    Word;
    DayTimeLimit:     Word;
    DownloadLimit:    Word;
    DownloadAt2400:   Word;
    DownloadAt9600:   Word;
    DownloadAt14400:  Word;
    DownloadAt28800:  Word;
    DownloadAt33600:  Word;
    DownloadRatio:    Word;
    RatioStart:       Word;
    DownloadSpeed:    LongWord;

    constructor Create; virtual;
    constructor Create(pszDataPath: PChar); virtual;
    destructor Destroy; override;

    function  Add: Word;
    procedure New_;
    procedure Delete;
    function  First: Word;
    function  Next: Word;
    function  Previous: Word;
    function  Read(pszName: PChar; fCloseFile: Word = 1): Word;
    function  Update: Word;

  private
    fdDat:   TFileStream;
    DatFile: String;
    LastKey: array[0..15] of Char;

    procedure Struct2Class(var Lim: LIMITS_REC);
    procedure Class2Struct(var Lim: LIMITS_REC);
  end;

implementation

constructor TLimits.Create;
begin
  inherited Create;
  fdDat := nil;
  New_;
  DatFile := 'limits.dat';
end;

constructor TLimits.Create(pszDataPath: PChar);
begin
  inherited Create;
  fdDat := nil;
  New_;
  DatFile := IncludeTrailingPathDelimiter(StrPas(pszDataPath)) + 'limits.dat';
end;

destructor TLimits.Destroy;
begin
  FreeAndNil(fdDat);
  inherited Destroy;
end;

procedure TLimits.Struct2Class(var Lim: LIMITS_REC);
begin
  StrCopy(Key, Lim.Key);
  StrCopy(Description, Lim.Description);
  Level := Lim.Level;
  Flags := Lim.Flags;
  DenyFlags := Lim.DenyFlags;
  CallTimeLimit := Lim.CallTimeLimit;
  DayTimeLimit := Lim.DayTimeLimit;
  DownloadLimit := Lim.DownloadLimit;
  DownloadAt2400 := Lim.DownloadAt2400;
  DownloadAt9600 := Lim.DownloadAt9600;
  DownloadAt14400 := Lim.DownloadAt14400;
  DownloadAt28800 := Lim.DownloadAt28800;
  DownloadAt33600 := Lim.DownloadAt33600;
  DownloadRatio := Lim.DownloadRatio;
  RatioStart := Lim.RatioStart;
  DownloadSpeed := Lim.DownloadSpeed;
  StrCopy(LastKey, Key);
end;

procedure TLimits.Class2Struct(var Lim: LIMITS_REC);
begin
  FillChar(Lim, SizeOf(LIMITS_REC), 0);
  Lim.Size := SizeOf(LIMITS_REC);
  StrCopy(Lim.Key, Key);
  StrCopy(Lim.Description, Description);
  Lim.Level := Level;
  Lim.Flags := Flags;
  Lim.DenyFlags := DenyFlags;
  Lim.CallTimeLimit := CallTimeLimit;
  Lim.DayTimeLimit := DayTimeLimit;
  Lim.DownloadLimit := DownloadLimit;
  Lim.DownloadAt2400 := DownloadAt2400;
  Lim.DownloadAt9600 := DownloadAt9600;
  Lim.DownloadAt14400 := DownloadAt14400;
  Lim.DownloadAt28800 := DownloadAt28800;
  Lim.DownloadAt33600 := DownloadAt33600;
  Lim.DownloadRatio := DownloadRatio;
  Lim.RatioStart := RatioStart;
  Lim.DownloadSpeed := DownloadSpeed;
end;

function OpenOrCreate(const FileName: String): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

function TLimits.Add: Word;
var
  DoClose: Boolean;
  Lim: LIMITS_REC;
begin
  Result := 0;
  DoClose := False;

  if fdDat = nil then
  begin
    fdDat := OpenOrCreate(DatFile);
    DoClose := True;
  end;

  if fdDat <> nil then
  begin
    fdDat.Seek(0, soFromEnd);
    Class2Struct(Lim);
    fdDat.Write(Lim, SizeOf(LIMITS_REC));
    StrCopy(LastKey, Key);
    Result := 1;
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

procedure TLimits.New_;
begin
  Key[0] := #0;
  Description[0] := #0;
  Level := 0;
  Flags := 0;
  DenyFlags := 0;
  CallTimeLimit := 0;
  DayTimeLimit := 0;
  DownloadLimit := 0;
  DownloadAt2400 := 0;
  DownloadAt9600 := 0;
  DownloadAt14400 := 0;
  DownloadAt28800 := 0;
  DownloadAt33600 := 0;
  DownloadRatio := 0;
  RatioStart := 0;
  DownloadSpeed := 0;
end;

procedure TLimits.Delete;
var
  fsNew: TFileStream;
  DoClose: Boolean;
  Lim: LIMITS_REC;
begin
  DoClose := False;

  if fdDat = nil then
  begin
    fdDat := OpenOrCreate(DatFile);
    DoClose := True;
  end;

  fsNew := nil;
  try
    fsNew := TFileStream.Create('temp3.dat', fmCreate);

    if fdDat <> nil then
    begin
      fdDat.Seek(0, soFromBeginning);

      while fdDat.Read(Lim, SizeOf(LIMITS_REC)) = SizeOf(LIMITS_REC) do
      begin
        if StrComp(Key, Lim.Key) <> 0 then
          fsNew.Write(Lim, SizeOf(LIMITS_REC));
      end;

      fdDat.Seek(0, soFromBeginning);
      fsNew.Seek(0, soFromBeginning);

      while fsNew.Read(Lim, SizeOf(LIMITS_REC)) = SizeOf(LIMITS_REC) do
        fdDat.Write(Lim, SizeOf(LIMITS_REC));

      fdDat.Size := fdDat.Position;
    end;
  finally
    FreeAndNil(fsNew);
    SysUtils.DeleteFile('temp3.dat');
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

function TLimits.First: Word;
begin
  Result := 0;

  if fdDat = nil then
    fdDat := OpenOrCreate(DatFile);

  if fdDat <> nil then
  begin
    fdDat.Seek(0, soFromBeginning);
    Result := Next;
  end;
end;

function TLimits.Next: Word;
var
  Lim: LIMITS_REC;
begin
  Result := 0;
  New_;

  if fdDat <> nil then
  begin
    if fdDat.Read(Lim, SizeOf(LIMITS_REC)) = SizeOf(LIMITS_REC) then
    begin
      Struct2Class(Lim);
      Result := 1;
    end;
  end;
end;

function TLimits.Previous: Word;
var
  Lim: LIMITS_REC;
begin
  Result := 0;
  New_;

  if fdDat <> nil then
  begin
    if fdDat.Position >= SizeOf(LIMITS_REC) * 2 then
    begin
      fdDat.Seek(fdDat.Position - SizeOf(LIMITS_REC) * 2, soFromBeginning);
      fdDat.Read(Lim, SizeOf(LIMITS_REC));
      Struct2Class(Lim);
      Result := 1;
    end;
  end;
end;

function TLimits.Read(pszName: PChar; fCloseFile: Word): Word;
var
  Lim: LIMITS_REC;
begin
  Result := 0;
  New_;

  if fdDat = nil then
    fdDat := OpenOrCreate(DatFile);

  if fdDat <> nil then
  begin
    fdDat.Seek(0, soFromBeginning);

    while (Result = 0) and (fdDat.Read(Lim, SizeOf(LIMITS_REC)) = SizeOf(LIMITS_REC)) do
    begin
      if stricmp(pszName, Lim.Key) = 0 then
      begin
        Struct2Class(Lim);
        Result := 1;
      end;
    end;
  end;

  if (fCloseFile <> 0) then
    FreeAndNil(fdDat);
end;

function TLimits.Update: Word;
var
  DoClose: Boolean;
  Lim: LIMITS_REC;
begin
  Result := 0;
  DoClose := False;

  if fdDat = nil then
  begin
    fdDat := OpenOrCreate(DatFile);
    DoClose := True;
  end;

  if fdDat <> nil then
  begin
    fdDat.Seek(0, soFromBeginning);
    while (Result = 0) and (fdDat.Read(Lim, SizeOf(LIMITS_REC)) = SizeOf(LIMITS_REC)) do
    begin
      if stricmp(LastKey, Lim.Key) = 0 then
      begin
        fdDat.Seek(fdDat.Position - SizeOf(LIMITS_REC), soFromBeginning);
        Class2Struct(Lim);
        fdDat.Write(Lim, SizeOf(LIMITS_REC));
        Result := 1;
      end;
    end;
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

end.
