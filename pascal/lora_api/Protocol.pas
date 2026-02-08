{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of protocol.cpp - TProtocol class
  Manages protocol.dat - external file transfer protocol definitions.
}

unit Protocol;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc299;

type
  TProtocol = class
  public
    Key:                  array[0..15] of Char;
    Description:          array[0..63] of Char;
    Active:               Byte;
    Batch:                Byte;
    DisablePort:          Byte;
    ChangeToUploadPath:   Byte;
    DownloadCmd:          array[0..63] of Char;
    UploadCmd:            array[0..63] of Char;
    LogFileName:          array[0..63] of Char;
    CtlFileName:          array[0..63] of Char;
    DownloadCtlString:    array[0..31] of Char;
    UploadCtlString:      array[0..31] of Char;
    DownloadKeyword:      array[0..31] of Char;
    UploadKeyword:        array[0..31] of Char;
    FileNamePos:          Word;
    SizePos:              Word;
    CpsPos:               Word;

    constructor Create; overload;
    constructor Create(pszPath: PChar); overload;
    destructor Destroy; override;

    procedure Add;
    procedure Delete;
    function  First: Word;
    procedure New_;
    function  Next: Word;
    function  Previous: Word;
    function  Read(pszKey: PChar): Word;
    procedure Update;

  private
    fdDat:    TFileStream;
    DataFile: String;
    prot:     PROTOCOL_REC;

    procedure Struct2Class(var proto: PROTOCOL_REC);
    procedure Class2Struct(var proto: PROTOCOL_REC);
  end;

implementation

constructor TProtocol.Create;
begin
  inherited Create;
  fdDat := nil;
  DataFile := 'protocol.dat';
end;

constructor TProtocol.Create(pszPath: PChar);
begin
  inherited Create;
  fdDat := nil;
  DataFile := IncludeTrailingPathDelimiter(StrPas(pszPath)) + 'protocol.dat';
end;

destructor TProtocol.Destroy;
begin
  FreeAndNil(fdDat);
  inherited Destroy;
end;

procedure TProtocol.Struct2Class(var proto: PROTOCOL_REC);
begin
  StrCopy(Key, proto.Key);
  StrCopy(Description, proto.Description);
  Active := proto.Active;
  Batch := proto.Batch;
  DisablePort := proto.DisablePort;
  ChangeToUploadPath := proto.ChangeToUploadPath;
  StrCopy(DownloadCmd, proto.DownloadCmd);
  StrCopy(UploadCmd, proto.UploadCmd);
  StrCopy(LogFileName, proto.LogFileName);
  StrCopy(CtlFileName, proto.CtlFileName);
  StrCopy(DownloadCtlString, proto.DownloadCtlString);
  StrCopy(UploadCtlString, proto.UploadCtlString);
  StrCopy(DownloadKeyword, proto.DownloadKeyword);
  StrCopy(UploadKeyword, proto.UploadKeyword);
  FileNamePos := proto.FileNamePos;
  SizePos := proto.SizePos;
  CpsPos := proto.CpsPos;
end;

procedure TProtocol.Class2Struct(var proto: PROTOCOL_REC);
begin
  FillChar(proto, SizeOf(PROTOCOL_REC), 0);
  proto.Size := SizeOf(PROTOCOL_REC);
  StrCopy(proto.Key, Key);
  StrCopy(proto.Description, Description);
  proto.Active := Active;
  proto.Batch := Batch;
  proto.DisablePort := DisablePort;
  proto.ChangeToUploadPath := ChangeToUploadPath;
  StrCopy(proto.DownloadCmd, DownloadCmd);
  StrCopy(proto.UploadCmd, UploadCmd);
  StrCopy(proto.LogFileName, LogFileName);
  StrCopy(proto.CtlFileName, CtlFileName);
  StrCopy(proto.DownloadCtlString, DownloadCtlString);
  StrCopy(proto.UploadCtlString, UploadCtlString);
  StrCopy(proto.DownloadKeyword, DownloadKeyword);
  StrCopy(proto.UploadKeyword, UploadKeyword);
  proto.FileNamePos := FileNamePos;
  proto.SizePos := SizePos;
  proto.CpsPos := CpsPos;
end;

function OpenOrCreate(const FileName: String): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

procedure TProtocol.Add;
var
  DoClose: Boolean;
begin
  DoClose := False;

  if fdDat = nil then
  begin
    fdDat := OpenOrCreate(DataFile);
    DoClose := True;
  end;

  if fdDat <> nil then
  begin
    Class2Struct(prot);
    fdDat.Seek(0, soFromEnd);
    fdDat.Write(prot, SizeOf(PROTOCOL_REC));
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

procedure TProtocol.Delete;
var
  fsNew: TFileStream;
  DoClose: Boolean;
  Position: Int64;
begin
  DoClose := False;

  if fdDat = nil then
  begin
    fdDat := OpenOrCreate(DataFile);
    DoClose := True;
  end;

  fsNew := nil;
  try
    fsNew := TFileStream.Create('temp.dat', fmCreate);

    if fdDat <> nil then
    begin
      Position := fdDat.Position;
      if Position > 0 then
        Dec(Position, SizeOf(PROTOCOL_REC));

      fdDat.Seek(0, soFromBeginning);

      while fdDat.Read(prot, SizeOf(PROTOCOL_REC)) = SizeOf(PROTOCOL_REC) do
      begin
        if StrComp(Key, prot.Key) <> 0 then
          fsNew.Write(prot, SizeOf(PROTOCOL_REC));
      end;

      fdDat.Seek(0, soFromBeginning);
      fsNew.Seek(0, soFromBeginning);

      while fsNew.Read(prot, SizeOf(PROTOCOL_REC)) = SizeOf(PROTOCOL_REC) do
        fdDat.Write(prot, SizeOf(PROTOCOL_REC));

      fdDat.Size := fdDat.Position;

      fdDat.Seek(Position, soFromBeginning);
      if Next = 0 then
      begin
        if Previous = 0 then
          New_;
      end;
    end;
  finally
    FreeAndNil(fsNew);
    SysUtils.DeleteFile('temp.dat');
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

function TProtocol.First: Word;
begin
  Result := 0;

  if fdDat = nil then
    fdDat := OpenOrCreate(DataFile);

  if fdDat <> nil then
  begin
    fdDat.Seek(0, soFromBeginning);
    Result := Next;
  end;
end;

procedure TProtocol.New_;
begin
  FillChar(prot, SizeOf(PROTOCOL_REC), 0);
  Struct2Class(prot);
end;

function TProtocol.Next: Word;
begin
  Result := 0;

  if fdDat <> nil then
  begin
    if fdDat.Read(prot, SizeOf(PROTOCOL_REC)) = SizeOf(PROTOCOL_REC) then
    begin
      Struct2Class(prot);
      Result := 1;
    end;
  end;
end;

function TProtocol.Previous: Word;
begin
  Result := 0;

  if fdDat <> nil then
  begin
    if fdDat.Position > SizeOf(PROTOCOL_REC) then
    begin
      fdDat.Seek(fdDat.Position - SizeOf(PROTOCOL_REC) * 2, soFromBeginning);
      fdDat.Read(prot, SizeOf(PROTOCOL_REC));
      Struct2Class(prot);
      Result := 1;
    end;
  end;
end;

function TProtocol.Read(pszKey: PChar): Word;
var
  DoClose: Boolean;
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
    while fdDat.Read(prot, SizeOf(PROTOCOL_REC)) = SizeOf(PROTOCOL_REC) do
    begin
      if stricmp(pszKey, prot.Key) = 0 then
      begin
        Struct2Class(prot);
        Result := 1;
        Break;
      end;
    end;
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

procedure TProtocol.Update;
begin
  if fdDat <> nil then
  begin
    if fdDat.Position >= SizeOf(PROTOCOL_REC) then
    begin
      fdDat.Seek(fdDat.Position - SizeOf(PROTOCOL_REC), soFromBeginning);
      Class2Struct(prot);
      fdDat.Write(prot, SizeOf(PROTOCOL_REC));
    end;
  end;
end;

end.
