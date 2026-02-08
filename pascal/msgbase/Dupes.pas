{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of dupes.cpp
  Duplicate message checking using CRC-based ring buffer
}

unit Dupes;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect, Defs, Struc299, MsgBase;

const
  DUPE_INDEX = 32;  { Batch read size for index }

type
  TDupes = class
  private
    FDataFile: string;
    FIndexFile: string;
    dd: DUPEDATA;

  public
    constructor Create; overload;
    constructor Create(const DataPath: string); overload;
    destructor Destroy; override;

    procedure Add(const EchoTag: string; Msg: TMsgBase);
    function Check(const EchoTag: string; Msg: TMsgBase): Boolean;
    procedure Delete;
    function GetEID(Msg: TMsgBase): LongWord;
    function Load(const EchoTag: string): Boolean;
    procedure Save;
  end;

implementation

constructor TDupes.Create;
begin
  inherited Create;
  FDataFile := 'dupes.dat';
  FIndexFile := 'dupes.idx';
  dd.EchoTag[0] := #0;
end;

constructor TDupes.Create(const DataPath: string);
var
  BasePath: string;
begin
  inherited Create;
  BasePath := IncludeTrailingPathDelimiter(DataPath);
  FDataFile := BasePath + 'dupes.dat';
  FIndexFile := BasePath + 'dupes.idx';
  dd.EchoTag[0] := #0;
end;

destructor TDupes.Destroy;
begin
  inherited Destroy;
end;

procedure TDupes.Add(const EchoTag: string; Msg: TMsgBase);
begin
  if not SameText(StrPas(dd.EchoTag), EchoTag) then
    Load(EchoTag);
  dd.Dupes[dd.Position] := GetEID(Msg);
  Inc(dd.Position);
  if dd.Position >= MAX_DUPES then
    dd.Position := 0;
end;

function TDupes.Check(const EchoTag: string; Msg: TMsgBase): Boolean;
var
  i: Integer;
  Crc: LongWord;
begin
  Result := False;
  if not SameText(StrPas(dd.EchoTag), EchoTag) then
    Load(EchoTag);
  Crc := GetEID(Msg);
  for i := 0 to MAX_DUPES - 1 do
  begin
    if dd.Dupes[i] = Crc then
    begin
      Result := True;
      Break;
    end;
  end;
end;

procedure TDupes.Delete;
var
  fs: TFileStream;
  EchoTag: array[0..63] of Char;
  ReadBuf: DUPEDATA;
  WritePos, ReadPos: Int64;
begin
  Move(dd.EchoTag, EchoTag, SizeOf(EchoTag));
  WritePos := 0;
  ReadPos := 0;

  if FileExists(FDataFile) then
  begin
    try
      fs := TFileStream.Create(FDataFile, fmOpenReadWrite or fmShareDenyNone);
      try
        while fs.Read(ReadBuf, SizeOf(DUPEDATA)) = SizeOf(DUPEDATA) do
        begin
          if not SameText(StrPas(ReadBuf.EchoTag), StrPas(EchoTag)) then
          begin
            fs.Position := WritePos;
            fs.Write(ReadBuf, SizeOf(DUPEDATA));
            WritePos := WritePos + SizeOf(DUPEDATA);
          end;
          ReadPos := ReadPos + SizeOf(DUPEDATA);
          fs.Position := ReadPos;
        end;
        fs.Size := WritePos;
      finally
        fs.Free;
      end;
    except
    end;
  end;
  dd.EchoTag[0] := #0;
end;

function TDupes.GetEID(Msg: TMsgBase): LongWord;
var
  Found: Boolean;
  pText: PChar;
  Crc: LongWord;
begin
  Found := False;
  Crc := 0;

  pText := PChar(Msg.Text.First);
  while pText <> nil do
  begin
    if (pText^ <> #1) and (StrLComp(pText, 'AREA:', 5) <> 0) then
      Break;
    if (StrLComp(pText, #1'MSGID: ', 8) = 0) or
       (StrLComp(pText, #1'Message-ID: ', 13) = 0) then
    begin
      Crc := StringCrc32(pText, $FFFFFFFF);
      Found := True;
      Break;
    end;
    pText := PChar(Msg.Text.Next);
  end;

  if not Found then
  begin
    Crc := StringCrc32(Msg.From_, $FFFFFFFF);
    Crc := StringCrc32(Msg.To_, Crc);
    Crc := StringCrc32(Msg.Subject_, Crc);
  end;

  Result := Crc;
end;

function TDupes.Load(const EchoTag: string): Boolean;
var
  fs: TFileStream;
  IdxBuf: array[0..DUPE_INDEX-1] of DUPEIDX;
  ReadCount, i: Integer;
  FoundPos: LongWord;
begin
  Result := False;
  FoundPos := 0;

  { Search index file for the echo tag }
  if FileExists(FIndexFile) then
  begin
    try
      fs := TFileStream.Create(FIndexFile, fmOpenRead or fmShareDenyNone);
      try
        repeat
          ReadCount := fs.Read(IdxBuf, SizeOf(IdxBuf));
          ReadCount := ReadCount div SizeOf(DUPEIDX);
          for i := 0 to ReadCount - 1 do
          begin
            if SameText(EchoTag, StrPas(IdxBuf[i].EchoTag)) then
            begin
              FoundPos := IdxBuf[i].Position;
              Result := True;
              Break;
            end;
          end;
        until Result or (ReadCount = 0);
      finally
        fs.Free;
      end;
    except
    end;
  end;

  if Result then
  begin
    { Read data record at found position }
    if FileExists(FDataFile) then
    begin
      try
        fs := TFileStream.Create(FDataFile, fmOpenRead or fmShareDenyNone);
        try
          fs.Position := FoundPos;
          fs.Read(dd, SizeOf(DUPEDATA));
        finally
          fs.Free;
        end;
      except
      end;
    end;
  end
  else
  begin
    { Initialize new empty dupe data }
    FillChar(dd, SizeOf(DUPEDATA), 0);
    StrPCopy(dd.EchoTag, Copy(EchoTag, 1, 63));
  end;
end;

procedure TDupes.Save;
var
  fs: TFileStream;
  IdxBuf: array[0..DUPE_INDEX-1] of DUPEIDX;
  ReadCount, i: Integer;
  Found: Boolean;
  FoundPos: LongWord;
  NewIdx: DUPEIDX;
begin
  if dd.EchoTag[0] = #0 then
    Exit;

  Found := False;
  FoundPos := 0;

  { Search index for existing entry }
  if FileExists(FIndexFile) then
  begin
    try
      fs := TFileStream.Create(FIndexFile, fmOpenRead or fmShareDenyNone);
      try
        repeat
          ReadCount := fs.Read(IdxBuf, SizeOf(IdxBuf));
          ReadCount := ReadCount div SizeOf(DUPEIDX);
          for i := 0 to ReadCount - 1 do
          begin
            if SameText(StrPas(dd.EchoTag), StrPas(IdxBuf[i].EchoTag)) then
            begin
              FoundPos := IdxBuf[i].Position;
              Found := True;
              Break;
            end;
          end;
        until Found or (ReadCount = 0);
      finally
        fs.Free;
      end;
    except
    end;
  end;

  { Write data file }
  try
    if FileExists(FDataFile) then
      fs := TFileStream.Create(FDataFile, fmOpenReadWrite or fmShareDenyNone)
    else
      fs := TFileStream.Create(FDataFile, fmCreate);
    try
      if Found then
        fs.Position := FoundPos
      else
      begin
        fs.Position := fs.Size;
        FillChar(NewIdx, SizeOf(DUPEIDX), 0);
        StrPCopy(NewIdx.EchoTag, StrPas(dd.EchoTag));
        NewIdx.Position := fs.Position;
      end;
      fs.Write(dd, SizeOf(DUPEDATA));
    finally
      fs.Free;
    end;
  except
  end;

  { Append new index entry if not found }
  if not Found then
  begin
    try
      if FileExists(FIndexFile) then
        fs := TFileStream.Create(FIndexFile, fmOpenReadWrite or fmShareDenyNone)
      else
        fs := TFileStream.Create(FIndexFile, fmCreate);
      try
        fs.Position := fs.Size;
        fs.Write(NewIdx, SizeOf(DUPEIDX));
      finally
        fs.Free;
      end;
    except
    end;
  end;
end;

end.
