{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of filebase.cpp
  TFileBase: file database management (filebase.dat/filebase.idx)
  Supports variable-length description and uploader fields, wildcard search,
  sorted result lists by name/date/download count.
}

unit FileBase;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, DateUtils, Math, Defs, Collect, Struc299;

type
  TFBDATE = record
    Day:    Byte;
    Month:  Byte;
    Year:   Word;
    Hour:   Byte;
    Minute: Byte;
  end;

  PNAMESORT = ^NAMESORT;
  NAMESORT = record
    Name:        array[0..31] of Char;
    Date_:       LongWord;
    Download:    LongWord;
    Position:    LongWord;
    IdxPosition: LongWord;
  end;

  TFileBase = class
  private
    FIdx: TFileStream;
    FDat: TFileStream;
    FArea: String;
    FDataPath: String;
    FUploader_Owned: Boolean;
    FList: TCollection;
    function MatchName(const AName, ASearch: String): Boolean;
    procedure ReadFileData(var FD: FILEDATA_REC);
    function DateToUnix(const D: TFBDATE): LongWord;
    procedure UnixToDate(UnixTime: LongWord; out D: TFBDATE);
    procedure SortedInsertByName(var ns: NAMESORT);
    procedure SortedInsertByDate(var ns: NAMESORT);
    procedure SortedInsertByDownload(var ns: NAMESORT);
  public
    Area: String;
    Name: String;
    Complete: String;
    Keyword: String;
    UplDate, Date: TFBDATE;
    Level: Word;
    Uploader: String;
    Unapproved: Boolean;
    Size: LongWord;
    DlTimes: LongWord;
    Cost, Password: LongWord;
    AccessFlags, DenyFlags: LongWord;
    UploadDate, FileDate: LongWord;
    CdRom: Boolean;
    Description: TCollection;

    constructor Create; overload;
    constructor Create(const APath, AArea: String); overload;
    destructor Destroy; override;

    function Add: Boolean;
    function ChangeLibrary(const AFrom, ATo: String): LongWord;
    procedure Clear;
    procedure Close;
    procedure Delete;
    function First(const ASearch: String = ''): Boolean;
    function Next(const ASearch: String = ''): Boolean;
    function Open(const ADataPath, AArea: String): Boolean;
    procedure Pack;
    function Previous: Boolean;
    function Read(const AFile: String): Boolean;
    procedure ReadFileList(const AListFile, ADlPath: String);
    function Replace: Boolean;
    function ReplaceHeader: Boolean;
    procedure SearchFile(const AFile: String);
    procedure SearchKeyword(const AKeyword: String);
    procedure SearchText(const AText: String);
    procedure SortByDate(ADate: LongWord = 0);
    procedure SortByDownload;
    procedure SortByName;
  end;

implementation

const
  MAX_INDEX = 256;

function AdjustPath(const S: String): String;
begin
  {$IFDEF UNIX}
  Result := StringReplace(S, '\', '/', [rfReplaceAll]);
  {$ELSE}
  Result := StringReplace(S, '/', '\', [rfReplaceAll]);
  {$ENDIF}
end;

{ TFileBase }

constructor TFileBase.Create;
begin
  inherited Create;
  FIdx := nil;
  FDat := nil;
  FUploader_Owned := False;
  Description := TCollection.Create;
  FList := nil;
  Clear;
end;

constructor TFileBase.Create(const APath, AArea: String);
begin
  inherited Create;
  FIdx := nil;
  FDat := nil;
  FUploader_Owned := False;
  Description := TCollection.Create;
  FList := nil;
  Clear;
  Open(APath, AArea);
end;

destructor TFileBase.Destroy;
begin
  Clear;
  Close;
  FreeAndNil(Description);
  if FList <> nil then
  begin
    FList.Clear;
    FreeAndNil(FList);
  end;
  inherited Destroy;
end;

function TFileBase.DateToUnix(const D: TFBDATE): LongWord;
var
  DT: TDateTime;
begin
  try
    DT := EncodeDate(D.Year, D.Month, D.Day) +
          EncodeTime(D.Hour, D.Minute, 0, 0);
    Result := LongWord(DateTimeToUnix(DT));
  except
    Result := 0;
  end;
end;

procedure TFileBase.UnixToDate(UnixTime: LongWord; out D: TFBDATE);
var
  DT: TDateTime;
  Y, M, Dy, H, Mi, S, MS: Word;
begin
  FillChar(D, SizeOf(D), 0);
  if UnixTime = 0 then Exit;
  try
    DT := UnixToDateTime(UnixTime);
    DecodeDate(DT, Y, M, Dy);
    DecodeTime(DT, H, Mi, S, MS);
    D.Day := Dy;
    D.Month := M;
    D.Year := Y;
    D.Hour := H;
    D.Minute := Mi;
  except
  end;
end;

procedure TFileBase.Clear;
begin
  Area := '';
  Name := '';
  Complete := '';
  Keyword := '';
  FillChar(Date, SizeOf(Date), 0);
  FillChar(UplDate, SizeOf(UplDate), 0);
  Description.Clear;
  FUploader_Owned := False;
  Uploader := '';
  Size := 0;
  DlTimes := 0;
  Cost := 0;
  Password := 0;
  Level := 0;
  AccessFlags := 0;
  DenyFlags := 0;
  FileDate := 0;
  UploadDate := 0;
  Unapproved := False;
  CdRom := False;
end;

procedure TFileBase.Close;
begin
  FreeAndNil(FIdx);
  FreeAndNil(FDat);
end;

function TFileBase.Open(const ADataPath, AArea: String): Boolean;
var
  IdxFile, DatFile: String;
begin
  Result := False;
  FDataPath := IncludeTrailingPathDelimiter(ADataPath);
  FArea := AArea;

  IdxFile := AdjustPath(FDataPath + 'filebase.idx');
  DatFile := AdjustPath(FDataPath + 'filebase.dat');

  try
    if FileExists(IdxFile) then
      FIdx := TFileStream.Create(IdxFile, fmOpenReadWrite or fmShareDenyNone)
    else
      FIdx := TFileStream.Create(IdxFile, fmCreate);
  except
    Exit;
  end;

  try
    if FileExists(DatFile) then
      FDat := TFileStream.Create(DatFile, fmOpenReadWrite or fmShareDenyNone)
    else
      FDat := TFileStream.Create(DatFile, fmCreate);
  except
    FreeAndNil(FIdx);
    Exit;
  end;

  Result := True;
end;

procedure TFileBase.ReadFileData(var FD: FILEDATA_REC);
var
  DescLen: Word;
  UplLen: Word;
  Buf: array[0..79] of Char;
  Line: String;
  R, I: Integer;
  UplBuf: String;
begin
  Clear;
  FD.Area[SizeOf(FD.Area) - 1] := #0;
  FD.Name[SizeOf(FD.Name) - 1] := #0;
  FD.Complete[SizeOf(FD.Complete) - 1] := #0;
  FD.Keyword[SizeOf(FD.Keyword) - 1] := #0;

  Area := StrPas(FD.Area);
  Name := StrPas(FD.Name);
  Complete := StrPas(FD.Complete);
  Keyword := StrPas(FD.Keyword);

  DescLen := FD.Description;
  if DescLen > 0 then
  begin
    Line := '';
    while DescLen > 0 do
    begin
      R := SizeOf(Buf);
      if R > DescLen then R := DescLen;
      R := FDat.Read(Buf, R);
      if R <= 0 then Break;
      for I := 0 to R - 1 do
      begin
        if Buf[I] = #13 then
        begin
          Description.Add(PChar(Line));
          Line := '';
        end
        else if Buf[I] <> #10 then
          Line := Line + Buf[I];
      end;
      Dec(DescLen, R);
    end;
    if Line <> '' then
      Description.Add(PChar(Line));
  end;

  UplLen := FD.Uploader;
  if UplLen > 0 then
  begin
    SetLength(UplBuf, UplLen);
    FDat.Read(UplBuf[1], UplLen);
    Uploader := PChar(UplBuf);
    FUploader_Owned := True;
  end;

  Size := FD.Size;
  DlTimes := FD.DlTimes;
  FileDate := FD.FileDate;
  UnixToDate(FD.FileDate, Date);
  UploadDate := FD.UploadDate;
  UnixToDate(FD.UploadDate, UplDate);
  Cost := FD.Cost;
  Password := FD.Password;
  Level := FD.Level;
  AccessFlags := FD.AccessFlags;
  DenyFlags := FD.DenyFlags;
  Unapproved := (FD.Flags and FILE_UNAPPROVED) <> 0;
  CdRom := (FD.Flags and FILE_CDROM) <> 0;
end;

function TFileBase.Add: Boolean;
var
  FD: FILEDATA_REC;
  FI: FILEINDEX;
  DescLine: PChar;
  CRLF: array[0..1] of Char;
begin
  Result := False;
  if (FIdx = nil) or (FDat = nil) then Exit;

  FUploader_Owned := False;
  CRLF[0] := #13;
  CRLF[1] := #10;

  FillChar(FI, SizeOf(FI), 0);
  FI.Area := StringCrc32(Area, $FFFFFFFF);
  StrPCopy(FI.Name, Name);
  FI.UploadDate := DateToUnix(UplDate);
  FDat.Seek(0, soEnd);
  FI.Offset := FDat.Position;
  if Unapproved then
    FI.Flags := FI.Flags or FILE_UNAPPROVED;

  FIdx.Seek(0, soEnd);
  FIdx.Write(FI, SizeOf(FI));

  FillChar(FD, SizeOf(FD), 0);
  FD.Id := FILEBASE_ID;
  StrPCopy(FD.Area, Area);
  StrPCopy(FD.Name, Name);
  StrPCopy(FD.Complete, Complete);
  StrPCopy(FD.Keyword, Keyword);
  FD.Size := Size;
  FD.DlTimes := DlTimes;
  FileDate := DateToUnix(Date);
  FD.FileDate := FileDate;
  UploadDate := DateToUnix(UplDate);
  FD.UploadDate := UploadDate;
  FD.Cost := Cost;
  FD.Password := Password;
  FD.Level := Level;
  FD.AccessFlags := AccessFlags;
  FD.DenyFlags := DenyFlags;
  if Unapproved then
    FD.Flags := FD.Flags or FILE_UNAPPROVED;
  if CdRom then
    FD.Flags := FD.Flags or FILE_CDROM;

  { Calculate description length }
  DescLine := PChar(Description.First);
  while DescLine <> nil do
  begin
    Inc(FD.Description, StrLen(DescLine) + 2);
    DescLine := PChar(Description.Next);
  end;

  if Uploader <> '' then
    FD.Uploader := Length(Uploader) + 1;

  FDat.Seek(0, soEnd);
  FDat.Write(FD, SizeOf(FD));

  DescLine := PChar(Description.First);
  while DescLine <> nil do
  begin
    FDat.Write(DescLine^, StrLen(DescLine));
    FDat.Write(CRLF, 2);
    DescLine := PChar(Description.Next);
  end;

  if Uploader <> '' then
    FDat.Write(PChar(Uploader)^, FD.Uploader);

  Result := True;
end;

function TFileBase.ChangeLibrary(const AFrom, ATo: String): LongWord;
var
  CrcFrom, CrcTo: LongWord;
  FD: FILEDATA_REC;
  FI: FILEINDEX;
begin
  Result := 0;
  if (FIdx = nil) or (FDat = nil) then Exit;

  CrcFrom := StringCrc32(AFrom, $FFFFFFFF);
  CrcTo := StringCrc32(ATo, $FFFFFFFF);

  FIdx.Seek(0, soBeginning);
  while FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) do
  begin
    if (FI.Flags and FILE_DELETED) <> 0 then Continue;
    if FI.Area = CrcFrom then
    begin
      FDat.Seek(FI.Offset, soBeginning);
      FDat.Read(FD, SizeOf(FD));
      StrPCopy(FD.Area, ATo);
      FDat.Seek(FI.Offset, soBeginning);
      FDat.Write(FD, SizeOf(FD));

      FI.Area := CrcTo;
      FIdx.Seek(FIdx.Position - SizeOf(FI), soBeginning);
      FIdx.Write(FI, SizeOf(FI));

      Inc(Result);
    end;
  end;
end;

procedure TFileBase.Delete;
var
  FD: FILEDATA_REC;
  FI: FILEINDEX;
begin
  if (FIdx = nil) or (FDat = nil) then Exit;
  if FIdx.Position < SizeOf(FI) then Exit;

  FIdx.Seek(FIdx.Position - SizeOf(FI), soBeginning);
  if FIdx.Read(FI, SizeOf(FI)) <> SizeOf(FI) then Exit;

  FI.Flags := FI.Flags or FILE_DELETED;
  FIdx.Seek(FIdx.Position - SizeOf(FI), soBeginning);
  FIdx.Write(FI, SizeOf(FI));

  FDat.Seek(FI.Offset, soBeginning);
  if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
  begin
    FD.Flags := FI.Flags;
    FDat.Seek(FI.Offset, soBeginning);
    FDat.Write(FD, SizeOf(FD));
  end;

  if FList <> nil then
  begin
    FList.Clear;
    FreeAndNil(FList);
  end;
end;

function TFileBase.First(const ASearch: String): Boolean;
var
  NS: PNAMESORT;
  FD: FILEDATA_REC;
begin
  Result := False;
  if FList = nil then
  begin
    if FIdx = nil then Exit;
    FIdx.Seek(0, soBeginning);
    Result := Next(ASearch);
  end
  else
  begin
    NS := PNAMESORT(FList.First);
    if NS <> nil then
    begin
      FDat.Seek(NS^.Position, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
      begin
        if FD.Id = FILEBASE_ID then
        begin
          ReadFileData(FD);
          Result := True;
        end;
      end;
    end;
  end;
end;

function TFileBase.MatchName(const AName, ASearch: String): Boolean;
var
  NI, SI: Integer;
  N, S: String;
begin
  Result := True;
  N := UpperCase(AName);
  S := UpperCase(ASearch);
  NI := 1;
  SI := 1;

  while (NI <= Length(N)) and (SI <= Length(S)) and Result do
  begin
    if S[SI] = '*' then
    begin
      Inc(SI);
      if SI > Length(S) then Exit;
      while (NI <= Length(N)) and (N[NI] <> S[SI]) do
        Inc(NI);
      if (NI > Length(N)) or (N[NI] <> S[SI]) then
        Result := False;
    end
    else if (S[SI] <> '?') and (N[NI] <> S[SI]) then
      Result := False
    else
    begin
      Inc(SI);
      Inc(NI);
    end;
  end;
end;

function TFileBase.Next(const ASearch: String): Boolean;
var
  NS: PNAMESORT;
  FD: FILEDATA_REC;
  FI: FILEINDEX;
  AreaCrc: LongWord;
  Found: Boolean;
begin
  Result := False;
  Found := False;

  if (FList = nil) and (FDat <> nil) then
  begin
    AreaCrc := StringCrc32(FArea, $FFFFFFFF);
    while FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) do
    begin
      if (FI.Flags and FILE_DELETED) <> 0 then Continue;
      if (FArea = '') or (FI.Area = AreaCrc) then
      begin
        Found := True;
        if ASearch <> '' then
          Found := MatchName(StrPas(FI.Name), ASearch);
        if Found then
        begin
          FDat.Seek(FI.Offset, soBeginning);
          Break;
        end;
      end;
    end;
  end
  else if (FList <> nil) then
  begin
    NS := PNAMESORT(FList.Next);
    if NS <> nil then
    begin
      FDat.Seek(NS^.Position, soBeginning);
      Found := True;
    end;
  end;

  if Found then
  begin
    if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
    begin
      if FD.Id = FILEBASE_ID then
      begin
        ReadFileData(FD);
        Result := True;
      end;
    end;
  end;
end;

function TFileBase.Previous: Boolean;
var
  NS: PNAMESORT;
  FD: FILEDATA_REC;
  FI: FILEINDEX;
  AreaCrc: LongWord;
  Found: Boolean;
begin
  Result := False;
  Found := False;

  if (FList = nil) and (FDat <> nil) then
  begin
    AreaCrc := StringCrc32(FArea, $FFFFFFFF);
    while FIdx.Position >= SizeOf(FILEINDEX) * 2 do
    begin
      FIdx.Seek(FIdx.Position - SizeOf(FILEINDEX) * 2, soBeginning);
      if FIdx.Read(FI, SizeOf(FI)) <> SizeOf(FI) then Break;
      if (FI.Flags and FILE_DELETED) <> 0 then Continue;
      if (FArea = '') or (FI.Area = AreaCrc) then
      begin
        FDat.Seek(FI.Offset, soBeginning);
        Found := True;
        Break;
      end;
    end;
  end
  else if (FList <> nil) then
  begin
    NS := PNAMESORT(FList.Previous);
    if NS <> nil then
    begin
      FDat.Seek(NS^.Position, soBeginning);
      Found := True;
    end;
  end;

  if Found then
  begin
    if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
    begin
      if FD.Id = FILEBASE_ID then
      begin
        ReadFileData(FD);
        Result := True;
      end;
    end;
  end;
end;

function TFileBase.Read(const AFile: String): Boolean;
var
  FD: FILEDATA_REC;
  FI: FILEINDEX;
  AreaCrc: LongWord;
begin
  Result := False;
  if (FIdx = nil) or (FDat = nil) then Exit;

  AreaCrc := StringCrc32(FArea, $FFFFFFFF);
  FIdx.Seek(0, soBeginning);

  while FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) do
  begin
    if (FI.Flags and FILE_DELETED) <> 0 then Continue;
    if (FArea = '') or (FI.Area = AreaCrc) then
    begin
      if SameText(StrPas(FI.Name), AFile) then
      begin
        FDat.Seek(FI.Offset, soBeginning);
        if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
        begin
          if FD.Id = FILEBASE_ID then
          begin
            ReadFileData(FD);
            Result := True;
          end;
        end;
        Exit;
      end;
    end;
  end;
end;

function TFileBase.Replace: Boolean;
var
  FD: FILEDATA_REC;
  FI: FILEINDEX;
  AreaCrc: LongWord;
  Found: Boolean;
  DescLine: PChar;
  CRLF: array[0..1] of Char;
begin
  Result := False;
  if (FIdx = nil) or (FDat = nil) then Exit;

  FUploader_Owned := False;
  AreaCrc := StringCrc32(FArea, $FFFFFFFF);
  CRLF[0] := #13;
  CRLF[1] := #10;

  { Try current position first }
  Found := False;
  if FIdx.Position >= SizeOf(FI) then
  begin
    FIdx.Seek(FIdx.Position - SizeOf(FI), soBeginning);
    if FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) then
    begin
      if ((FArea = '') or (FI.Area = AreaCrc)) and SameText(StrPas(FI.Name), Name) then
        Found := True;
    end;
  end;

  if not Found then
  begin
    FIdx.Seek(0, soBeginning);
    while FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) do
    begin
      if (FI.Flags and FILE_DELETED) <> 0 then Continue;
      if ((FArea = '') or (FI.Area = AreaCrc)) and SameText(StrPas(FI.Name), Name) then
      begin
        Found := True;
        Break;
      end;
    end;
  end;

  if not Found then Exit;

  { Mark old data as deleted }
  FDat.Seek(FI.Offset, soBeginning);
  if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then Exit;
  if FD.Id <> FILEBASE_ID then Exit;

  FD.Flags := FD.Flags or FILE_DELETED;
  FDat.Seek(FI.Offset, soBeginning);
  FDat.Write(FD, SizeOf(FD));

  { Write new data at end }
  FDat.Seek(0, soEnd);
  FI.Offset := FDat.Position;
  FI.UploadDate := DateToUnix(UplDate);
  if Unapproved then
    FI.Flags := FI.Flags or FILE_UNAPPROVED
  else
    FI.Flags := FI.Flags and (not FILE_UNAPPROVED);

  FIdx.Seek(FIdx.Position - SizeOf(FI), soBeginning);
  FIdx.Write(FI, SizeOf(FI));

  FillChar(FD, SizeOf(FD), 0);
  FD.Id := FILEBASE_ID;
  StrPCopy(FD.Area, Area);
  StrPCopy(FD.Name, Name);
  StrPCopy(FD.Complete, Complete);
  StrPCopy(FD.Keyword, Keyword);
  FD.Size := Size;
  FD.DlTimes := DlTimes;
  FileDate := DateToUnix(Date);
  FD.FileDate := FileDate;
  UploadDate := DateToUnix(UplDate);
  FD.UploadDate := UploadDate;
  FD.Cost := Cost;
  FD.Password := Password;
  FD.Level := Level;
  FD.AccessFlags := AccessFlags;
  FD.DenyFlags := DenyFlags;
  if Unapproved then FD.Flags := FD.Flags or FILE_UNAPPROVED;
  if CdRom then FD.Flags := FD.Flags or FILE_CDROM;

  DescLine := PChar(Description.First);
  while DescLine <> nil do
  begin
    Inc(FD.Description, StrLen(DescLine) + 2);
    DescLine := PChar(Description.Next);
  end;
  if Uploader <> '' then
    FD.Uploader := Length(Uploader) + 1;

  FDat.Seek(0, soEnd);
  FDat.Write(FD, SizeOf(FD));

  DescLine := PChar(Description.First);
  while DescLine <> nil do
  begin
    FDat.Write(DescLine^, StrLen(DescLine));
    FDat.Write(CRLF, 2);
    DescLine := PChar(Description.Next);
  end;

  if Uploader <> '' then
    FDat.Write(PChar(Uploader)^, FD.Uploader);

  Result := True;
end;

function TFileBase.ReplaceHeader: Boolean;
var
  FD: FILEDATA_REC;
  FI: FILEINDEX;
  AreaCrc: LongWord;
  NS: PNAMESORT;
  Found: Boolean;
begin
  Result := False;
  if (FIdx = nil) or (FDat = nil) then Exit;

  Found := False;
  AreaCrc := StringCrc32(FArea, $FFFFFFFF);

  if FList = nil then
  begin
    FIdx.Seek(0, soBeginning);
    while FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) do
    begin
      if (FI.Flags and FILE_DELETED) <> 0 then Continue;
      if ((FArea = '') or (FI.Area = AreaCrc)) and SameText(StrPas(FI.Name), Name) then
      begin
        FDat.Seek(FI.Offset, soBeginning);
        if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
          if FD.Id = FILEBASE_ID then
          begin
            Found := True;
            Break;
          end;
      end;
    end;
  end
  else
  begin
    NS := PNAMESORT(FList.Value);
    if NS <> nil then
    begin
      FIdx.Seek(NS^.IdxPosition, soBeginning);
      if FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) then
      begin
        FDat.Seek(FI.Offset, soBeginning);
        if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
          if (FD.Id = FILEBASE_ID) and SameText(StrPas(FD.Name), Name) then
            Found := True;
      end;
    end;

    if not Found then
    begin
      NS := PNAMESORT(FList.First);
      while NS <> nil do
      begin
        if SameText(StrPas(NS^.Name), Name) then
        begin
          FIdx.Seek(NS^.IdxPosition, soBeginning);
          if FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) then
          begin
            FDat.Seek(FI.Offset, soBeginning);
            if FDat.Read(FD, SizeOf(FD)) = SizeOf(FD) then
              if FD.Id = FILEBASE_ID then
              begin
                Found := True;
                Break;
              end;
          end;
        end;
        NS := PNAMESORT(FList.Next);
      end;
    end;
  end;

  if Found then
  begin
    { Update index }
    FI.Area := StringCrc32(Area, $FFFFFFFF);
    StrPCopy(FI.Name, Name);
    FI.UploadDate := DateToUnix(UplDate);
    if Unapproved then
      FI.Flags := FI.Flags or FILE_UNAPPROVED
    else
      FI.Flags := FI.Flags and (not FILE_UNAPPROVED);

    FIdx.Seek(FIdx.Position - SizeOf(FI), soBeginning);
    FIdx.Write(FI, SizeOf(FI));

    { Update data header (not description/uploader) }
    StrPCopy(FD.Area, Area);
    StrPCopy(FD.Name, Name);
    StrPCopy(FD.Complete, Complete);
    StrPCopy(FD.Keyword, Keyword);
    FD.Size := Size;
    FD.DlTimes := DlTimes;
    FileDate := DateToUnix(Date);
    FD.FileDate := FileDate;
    UploadDate := DateToUnix(UplDate);
    FD.UploadDate := UploadDate;
    FD.Cost := Cost;
    FD.Password := Password;
    FD.Level := Level;
    FD.AccessFlags := AccessFlags;
    FD.DenyFlags := DenyFlags;
    if Unapproved then
      FD.Flags := FD.Flags or FILE_UNAPPROVED
    else
      FD.Flags := FD.Flags and (not FILE_UNAPPROVED);
    if CdRom then
      FD.Flags := FD.Flags or FILE_CDROM
    else
      FD.Flags := FD.Flags and (not FILE_CDROM);

    FDat.Seek(FI.Offset, soBeginning);
    FDat.Write(FD, SizeOf(FD));
  end;

  Result := True;
end;

procedure TFileBase.Pack;
var
  NewIdx, NewDat: TFileStream;
  FD: FILEDATA_REC;
  FI: FILEINDEX;
  NewIdxFile, NewDatFile: String;
  Buffer: array[0..2047] of Byte;
  Remaining, BytesRead: Integer;
begin
  if (FIdx = nil) or (FDat = nil) then Exit;

  NewIdxFile := AdjustPath(FDataPath + 'filebase.$dx');
  NewDatFile := AdjustPath(FDataPath + 'filebase.$at');

  try
    NewIdx := TFileStream.Create(NewIdxFile, fmCreate);
    NewDat := TFileStream.Create(NewDatFile, fmCreate);
  except
    Exit;
  end;

  try
    FIdx.Seek(0, soBeginning);
    while FIdx.Read(FI, SizeOf(FI)) = SizeOf(FI) do
    begin
      if (FI.Flags and FILE_DELETED) <> 0 then Continue;

      FDat.Seek(FI.Offset, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then Continue;

      FI.Offset := NewDat.Position;
      NewIdx.Write(FI, SizeOf(FI));
      NewDat.Write(FD, SizeOf(FD));

      { Copy description bytes }
      Remaining := FD.Description;
      while Remaining > 0 do
      begin
        BytesRead := FDat.Read(Buffer, Min(SizeOf(Buffer), Remaining));
        if BytesRead <= 0 then Break;
        NewDat.Write(Buffer, BytesRead);
        Dec(Remaining, BytesRead);
      end;

      { Copy uploader bytes }
      Remaining := FD.Uploader;
      while Remaining > 0 do
      begin
        BytesRead := FDat.Read(Buffer, Min(SizeOf(Buffer), Remaining));
        if BytesRead <= 0 then Break;
        NewDat.Write(Buffer, BytesRead);
        Dec(Remaining, BytesRead);
      end;
    end;
  finally
    NewDat.Free;
    NewIdx.Free;
  end;

  Close;

  { Replace old files with new ones }
  SysUtils.DeleteFile(AdjustPath(FDataPath + 'filebase.dat'));
  RenameFile(NewDatFile, AdjustPath(FDataPath + 'filebase.dat'));
  SysUtils.DeleteFile(AdjustPath(FDataPath + 'filebase.idx'));
  RenameFile(NewIdxFile, AdjustPath(FDataPath + 'filebase.idx'));

  { Reopen }
  try
    FIdx := TFileStream.Create(AdjustPath(FDataPath + 'filebase.idx'), fmOpenReadWrite or fmShareDenyNone);
    FDat := TFileStream.Create(AdjustPath(FDataPath + 'filebase.dat'), fmOpenReadWrite or fmShareDenyNone);
  except
  end;

  { Clean up temp files if rename failed }
  SysUtils.DeleteFile(NewDatFile);
  SysUtils.DeleteFile(NewIdxFile);
end;

{ Sorted insert helpers for search/sort results }

procedure TFileBase.SortedInsertByName(var ns: NAMESORT);
var
  P: PNAMESORT;
  Inserted: Boolean;
begin
  Inserted := False;
  P := PNAMESORT(FList.First);
  if P <> nil then
  begin
    if StrComp(P^.Name, ns.Name) > 0 then
    begin
      FList.Insert(@ns, SizeOf(NAMESORT));
      FList.Insert(P, SizeOf(NAMESORT));
      FList.First;
      FList.Remove;
      Inserted := True;
    end;
    if not Inserted then
    begin
      repeat
        if StrComp(P^.Name, ns.Name) > 0 then
        begin
          FList.Previous;
          FList.Insert(@ns, SizeOf(NAMESORT));
          Inserted := True;
          Break;
        end;
        P := PNAMESORT(FList.Next);
      until P = nil;
    end;
  end;
  if not Inserted then
    FList.Add(@ns, SizeOf(NAMESORT));
end;

procedure TFileBase.SortedInsertByDate(var ns: NAMESORT);
var
  P: PNAMESORT;
  Inserted: Boolean;
begin
  Inserted := False;
  P := PNAMESORT(FList.First);
  if P <> nil then
  begin
    if P^.Date_ < ns.Date_ then
    begin
      FList.Insert(@ns, SizeOf(NAMESORT));
      FList.Insert(P, SizeOf(NAMESORT));
      FList.First;
      FList.Remove;
      FList.First;
      Inserted := True;
    end;
    if not Inserted then
    begin
      repeat
        if P^.Date_ < ns.Date_ then
        begin
          FList.Previous;
          FList.Insert(@ns, SizeOf(NAMESORT));
          Inserted := True;
          Break;
        end;
        P := PNAMESORT(FList.Next);
      until P = nil;
    end;
  end;
  if not Inserted then
    FList.Add(@ns, SizeOf(NAMESORT));
end;

procedure TFileBase.SortedInsertByDownload(var ns: NAMESORT);
var
  P: PNAMESORT;
  Inserted: Boolean;
begin
  Inserted := False;
  P := PNAMESORT(FList.First);
  if P <> nil then
  begin
    if P^.Download < ns.Download then
    begin
      FList.Insert(@ns, SizeOf(NAMESORT));
      FList.Insert(P, SizeOf(NAMESORT));
      FList.First;
      FList.Remove;
      Inserted := True;
    end;
    if not Inserted then
    begin
      repeat
        if P^.Download < ns.Download then
        begin
          FList.Previous;
          FList.Insert(@ns, SizeOf(NAMESORT));
          Inserted := True;
          Break;
        end;
        P := PNAMESORT(FList.Next);
      until P = nil;
    end;
  end;
  if not Inserted then
    FList.Add(@ns, SizeOf(NAMESORT));
end;

procedure TFileBase.SearchFile(const AFile: String);
var
  Crc: LongWord;
  FD: FILEDATA_REC;
  FI: array[0..MAX_INDEX - 1] of FILEINDEX;
  NS: NAMESORT;
  I, Count: Integer;
  LowerFile: String;
begin
  if FList = nil then
    FList := TCollection.Create;
  LowerFile := LowerCase(AFile);

  FList.Clear;
  Crc := StringCrc32(FArea, $FFFFFFFF);
  if (FDat = nil) or (FIdx = nil) then Exit;

  FIdx.Seek(0, soBeginning);
  repeat
    Count := FIdx.Read(FI, SizeOf(FI)) div SizeOf(FILEINDEX);
    for I := 0 to Count - 1 do
    begin
      if (FI[I].Flags and (FILE_DELETED or FILE_UNAPPROVED)) <> 0 then Continue;
      if (FArea <> '') and (FI[I].Area <> Crc) then Continue;

      FDat.Seek(FI[I].Offset, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then Continue;
      if FD.Id <> FILEBASE_ID then Continue;

      if MatchName(StrPas(FI[I].Name), LowerFile) then
      begin
        FillChar(NS, SizeOf(NS), 0);
        FI[I].Name[SizeOf(FI[I].Name) - 1] := #0;
        StrCopy(NS.Name, FI[I].Name);
        NS.Position := FI[I].Offset;
        SortedInsertByName(NS);
      end;
    end;
  until Count < MAX_INDEX;
end;

procedure TFileBase.SearchKeyword(const AKeyword: String);
var
  Crc: LongWord;
  FD: FILEDATA_REC;
  FI: array[0..MAX_INDEX - 1] of FILEINDEX;
  NS: NAMESORT;
  I, Count: Integer;
  LowerKw: String;
begin
  if FList = nil then
    FList := TCollection.Create;
  LowerKw := LowerCase(AKeyword);

  FList.Clear;
  Crc := StringCrc32(FArea, $FFFFFFFF);
  if (FDat = nil) or (FIdx = nil) then Exit;

  FIdx.Seek(0, soBeginning);
  repeat
    Count := FIdx.Read(FI, SizeOf(FI)) div SizeOf(FILEINDEX);
    for I := 0 to Count - 1 do
    begin
      if (FI[I].Flags and (FILE_DELETED or FILE_UNAPPROVED)) <> 0 then Continue;
      if (FArea <> '') and (FI[I].Area <> Crc) then Continue;

      FDat.Seek(FI[I].Offset, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then Continue;
      if FD.Id <> FILEBASE_ID then Continue;

      if Pos(LowerKw, LowerCase(StrPas(FD.Keyword))) > 0 then
      begin
        FillChar(NS, SizeOf(NS), 0);
        FI[I].Name[SizeOf(FI[I].Name) - 1] := #0;
        StrCopy(NS.Name, FI[I].Name);
        NS.Position := FI[I].Offset;
        SortedInsertByName(NS);
      end;
    end;
  until Count < MAX_INDEX;
end;

procedure TFileBase.SearchText(const AText: String);
var
  Crc: LongWord;
  FD: FILEDATA_REC;
  FI: array[0..MAX_INDEX - 1] of FILEINDEX;
  NS: NAMESORT;
  I, Count: Integer;
  LowerText: String;
  AddThis: Boolean;
  Buf: array[0..79] of Char;
  Line: String;
  R, J, DescRemain: Integer;
begin
  if FList = nil then
    FList := TCollection.Create;
  LowerText := LowerCase(AText);

  FList.Clear;
  Crc := StringCrc32(FArea, $FFFFFFFF);
  if (FDat = nil) or (FIdx = nil) then Exit;

  FIdx.Seek(0, soBeginning);
  repeat
    Count := FIdx.Read(FI, SizeOf(FI)) div SizeOf(FILEINDEX);
    for I := 0 to Count - 1 do
    begin
      if (FI[I].Flags and (FILE_DELETED or FILE_UNAPPROVED)) <> 0 then Continue;
      if (FArea <> '') and (FI[I].Area <> Crc) then Continue;

      FDat.Seek(FI[I].Offset, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then Continue;
      if FD.Id <> FILEBASE_ID then Continue;

      AddThis := False;
      FD.Name[SizeOf(FD.Name) - 1] := #0;
      FD.Keyword[SizeOf(FD.Keyword) - 1] := #0;

      if Pos(LowerText, LowerCase(StrPas(FD.Name))) > 0 then
        AddThis := True;
      if (not AddThis) and (Pos(LowerText, LowerCase(StrPas(FD.Keyword))) > 0) then
        AddThis := True;

      { Search description text }
      if (not AddThis) and (FD.Description > 0) then
      begin
        DescRemain := FD.Description;
        Line := '';
        while (DescRemain > 0) and not AddThis do
        begin
          R := SizeOf(Buf);
          if R > DescRemain then R := DescRemain;
          R := FDat.Read(Buf, R);
          if R <= 0 then Break;
          for J := 0 to R - 1 do
          begin
            if AddThis then Break;
            if Buf[J] = #13 then
            begin
              if Pos(LowerText, LowerCase(Line)) > 0 then
                AddThis := True;
              Line := '';
            end
            else if Buf[J] <> #10 then
              Line := Line + Buf[J];
          end;
          Dec(DescRemain, R);
        end;
        if (not AddThis) and (Line <> '') then
          if Pos(LowerText, LowerCase(Line)) > 0 then
            AddThis := True;
      end;

      if AddThis then
      begin
        FillChar(NS, SizeOf(NS), 0);
        FI[I].Name[SizeOf(FI[I].Name) - 1] := #0;
        StrCopy(NS.Name, FI[I].Name);
        NS.Position := FI[I].Offset;
        SortedInsertByName(NS);
      end;
    end;
  until Count < MAX_INDEX;
end;

procedure TFileBase.SortByDate(ADate: LongWord);
var
  Crc: LongWord;
  FD: FILEDATA_REC;
  FI: array[0..MAX_INDEX - 1] of FILEINDEX;
  NS: NAMESORT;
  I, Count: Integer;
begin
  if FList = nil then
    FList := TCollection.Create;

  FList.Clear;
  Crc := StringCrc32(FArea, $FFFFFFFF);
  if (FDat = nil) or (FIdx = nil) then Exit;

  FIdx.Seek(0, soBeginning);
  repeat
    Count := FIdx.Read(FI, SizeOf(FI)) div SizeOf(FILEINDEX);
    for I := 0 to Count - 1 do
    begin
      if (FI[I].Flags and (FILE_DELETED or FILE_UNAPPROVED)) <> 0 then Continue;
      if (FArea <> '') and (FI[I].Area <> Crc) then Continue;

      FDat.Seek(FI[I].Offset, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then Continue;
      if FD.Id <> FILEBASE_ID then Continue;

      FillChar(NS, SizeOf(NS), 0);
      FI[I].Name[SizeOf(FI[I].Name) - 1] := #0;
      StrCopy(NS.Name, FI[I].Name);
      NS.Date_ := FI[I].UploadDate;
      NS.Position := FI[I].Offset;

      if NS.Date_ > ADate then
        SortedInsertByDate(NS);
    end;
  until Count < MAX_INDEX;
end;

procedure TFileBase.SortByDownload;
var
  Crc: LongWord;
  FD: FILEDATA_REC;
  FI: array[0..MAX_INDEX - 1] of FILEINDEX;
  NS: NAMESORT;
  I, Count: Integer;
begin
  if FList = nil then
    FList := TCollection.Create;

  FList.Clear;
  Crc := StringCrc32(FArea, $FFFFFFFF);
  if (FDat = nil) or (FIdx = nil) then Exit;

  FIdx.Seek(0, soBeginning);
  repeat
    Count := FIdx.Read(FI, SizeOf(FI)) div SizeOf(FILEINDEX);
    for I := 0 to Count - 1 do
    begin
      if (FI[I].Flags and (FILE_DELETED or FILE_UNAPPROVED)) <> 0 then Continue;
      if (FArea <> '') and (FI[I].Area <> Crc) then Continue;

      FDat.Seek(FI[I].Offset, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then Continue;
      if FD.Id <> FILEBASE_ID then Continue;

      FillChar(NS, SizeOf(NS), 0);
      FI[I].Name[SizeOf(FI[I].Name) - 1] := #0;
      StrCopy(NS.Name, FI[I].Name);
      NS.Download := FD.DlTimes;
      NS.Position := FI[I].Offset;
      SortedInsertByDownload(NS);
    end;
  until Count < MAX_INDEX;
end;

procedure TFileBase.SortByName;
var
  Crc: LongWord;
  FD: FILEDATA_REC;
  FI: array[0..MAX_INDEX - 1] of FILEINDEX;
  NS: NAMESORT;
  I, Count: Integer;
  Position: LongWord;
begin
  if FList = nil then
    FList := TCollection.Create;

  FList.Clear;
  Crc := StringCrc32(FArea, $FFFFFFFF);
  if (FDat = nil) or (FIdx = nil) then Exit;

  FIdx.Seek(0, soBeginning);
  Position := 0;
  repeat
    Count := FIdx.Read(FI, SizeOf(FI)) div SizeOf(FILEINDEX);
    for I := 0 to Count - 1 do
    begin
      if (FI[I].Flags and (FILE_DELETED or FILE_UNAPPROVED)) <> 0 then
      begin
        Inc(Position, SizeOf(FILEINDEX));
        Continue;
      end;
      if (FArea <> '') and (FI[I].Area <> Crc) then
      begin
        Inc(Position, SizeOf(FILEINDEX));
        Continue;
      end;

      FDat.Seek(FI[I].Offset, soBeginning);
      if FDat.Read(FD, SizeOf(FD)) <> SizeOf(FD) then
      begin
        Inc(Position, SizeOf(FILEINDEX));
        Continue;
      end;
      if FD.Id <> FILEBASE_ID then
      begin
        Inc(Position, SizeOf(FILEINDEX));
        Continue;
      end;

      FillChar(NS, SizeOf(NS), 0);
      FI[I].Name[SizeOf(FI[I].Name) - 1] := #0;
      StrCopy(NS.Name, FI[I].Name);
      NS.Position := FI[I].Offset;
      NS.IdxPosition := Position;
      SortedInsertByName(NS);

      Inc(Position, SizeOf(FILEINDEX));
    end;
  until Count < MAX_INDEX;
end;

procedure TFileBase.ReadFileList(const AListFile, ADlPath: String);
var
  Lines: TStringList;
  I: Integer;
  Line, FileName, Desc, Path: String;
  PendingWrite: Boolean;
  P: Integer;
  DlPath: String;
  SR: TSearchRec;
  FAge: LongInt;
  FTime: TDateTime;
  Y, M, D, H, Mi, S, MS: Word;
begin
  if not FileExists(AListFile) then Exit;

  DlPath := IncludeTrailingPathDelimiter(ADlPath);
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AListFile);
    PendingWrite := False;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if (Length(Line) >= 2) and (Line[2] = '>') then
      begin
        if PendingWrite then
          Description.Add(PChar(Copy(Line, 3, MaxInt)));
      end
      else
      begin
        if PendingWrite then
        begin
          Add;
          Clear;
          PendingWrite := False;
        end;

        P := Pos(' ', Line);
        if P > 0 then
        begin
          FileName := Copy(Line, 1, P - 1);
          Desc := TrimLeft(Copy(Line, P + 1, MaxInt));

          { Parse download count in parens/brackets }
          DlTimes := 0;
          if (Desc <> '') and ((Desc[1] = '(') or (Desc[1] = '[')) then
          begin
            P := 1;
            while (P <= Length(Desc)) and not (Desc[P] in [')', ']']) do
            begin
              if Desc[P] in ['0'..'9'] then
                DlTimes := DlTimes * 10 + Ord(Desc[P]) - Ord('0');
              Inc(P);
            end;
            if (P <= Length(Desc)) and (Desc[P] in [')', ']']) then
              Inc(P);
            Desc := TrimLeft(Copy(Desc, P, MaxInt));
          end;

          if Desc <> '' then
            Description.Add(PChar(Desc));

          Path := DlPath + FileName;
          {$IFDEF UNIX}
          Path := LowerCase(Path);
          {$ENDIF}

          if FindFirst(Path, faAnyFile and not faDirectory, SR) = 0 then
          begin
            try
              Name := FileName;
              Complete := DlPath + FileName;
              Size := SR.Size;

              FAge := FileAge(Path);
              if FAge <> -1 then
              begin
                FTime := FileDateToDateTime(FAge);
                DecodeDate(FTime, Y, M, D);
                DecodeTime(FTime, H, Mi, S, MS);
                Date.Day := D;
                Date.Month := M;
                Date.Year := Y;
                Date.Hour := H;
                Date.Minute := Mi;
                UplDate := Date;
              end;

              Uploader := 'Sysop';
              CdRom := False;
              PendingWrite := True;
            finally
              FindClose(SR);
            end;
          end
          else
            Clear;
        end;
      end;
    end;

    if PendingWrite then
    begin
      Add;
      Clear;
    end;
  finally
    Lines.Free;
  end;
end;

end.
