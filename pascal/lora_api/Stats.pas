{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of stats.cpp - TStatistics class
  Reads/writes stats.dat for BBS system and per-line statistics.
}

unit Stats;

{$MODE OBJFPC}
{$H+}
{$PACKRECORDS 1}

interface

uses
  SysUtils, Defs;

const
  STAT_OFFLINE    = 0;
  STAT_WAITING    = 1;
  STAT_USER       = 2;
  STAT_MAILER     = 3;
  STAT_FAXRECEIVE = 4;

type
  SYSSTAT = packed record
    LastCaller: array[0..47] of Char;
    TodayCalls: LongWord;
    Calls:      LongWord;
    MailCalls:  LongWord;
  end;

  LINESTAT = packed record
    Number:     Word;
    Status:     Word;
    User:       array[0..47] of Char;
    From_:      array[0..47] of Char;
    Action:     array[0..47] of Char;
    LastCaller: array[0..47] of Char;
    TodayCalls: LongWord;
    Calls:      LongWord;
    MailCalls:  LongWord;
  end;

type
  TStatistics = class
  public
    LineNumber:      Word;
    Status:          Word;
    User:            array[0..47] of Char;
    From_:           array[0..47] of Char;
    Action:          array[0..47] of Char;
    LastCaller:      array[0..47] of Char;
    LineLastCaller:  array[0..47] of Char;
    TotalCalls:      LongWord;
    Calls:           LongWord;
    TotalMailCalls:  LongWord;
    MailCalls:       LongWord;
    TotalTodayCalls: LongWord;
    TodayCalls:      LongWord;

    constructor Create; virtual;
    constructor Create(pszDataPath: PChar); virtual;
    destructor Destroy; override;

    function  First: Word;
    function  Next: Word;
    procedure Read(usLine: Word);
    procedure Update;

  private
    LastTask: Word;
    DataFile: array[0..127] of Char;
    Sys:      SYSSTAT;
    Line:     LINESTAT;
  end;

implementation

constructor TStatistics.Create;
begin
  inherited Create;
  StrCopy(DataFile, 'stats.dat');
end;

constructor TStatistics.Create(pszDataPath: PChar);
begin
  inherited Create;
  StrCopy(DataFile, pszDataPath);
  if DataFile[0] <> #0 then
  begin
    if DataFile[StrLen(DataFile) - 1] <> PathDelim then
      StrCat(DataFile, PathDelim);
  end;
  StrCat(DataFile, 'stats.dat');
end;

destructor TStatistics.Destroy;
begin
  inherited Destroy;
end;

function TStatistics.First: Word;
begin
  LastTask := 0;
  Result := Next;
end;

function TStatistics.Next: Word;
var
  fd: LongInt;
begin
  Result := 0;
  FillChar(Sys, SizeOf(Sys), 0);

  fd := FileOpen(StrPas(DataFile), fmOpenReadWrite or fmShareDenyNone);
  if fd = -1 then
    fd := FileCreate(StrPas(DataFile));

  if fd <> -1 then
  begin
    FileRead(fd, Sys, SizeOf(Sys));
    while FileRead(fd, Line, SizeOf(Line)) = SizeOf(Line) do
    begin
      if Line.Number > LastTask then
      begin
        Result := 1;
        Break;
      end;
    end;
    FileClose(fd);
  end;

  if Result = 1 then
  begin
    LineNumber := Line.Number;
    Status := Line.Status;
    StrCopy(User, Line.User);
    StrCopy(From_, Line.From_);
    StrCopy(Action, Line.Action);
    StrCopy(LineLastCaller, Line.LastCaller);
    if LineLastCaller[0] = #0 then
      StrCopy(LineLastCaller, 'None');
    Calls := Line.Calls;
    MailCalls := Line.MailCalls;
    TodayCalls := Line.TodayCalls;

    LastTask := LineNumber;
  end;
end;

procedure TStatistics.Read(usLine: Word);
var
  fd: LongInt;
  Found: Boolean;
begin
  Found := False;
  FillChar(Sys, SizeOf(Sys), 0);

  fd := FileOpen(StrPas(DataFile), fmOpenReadWrite or fmShareDenyNone);
  if fd = -1 then
    fd := FileCreate(StrPas(DataFile));

  if fd <> -1 then
  begin
    FileRead(fd, Sys, SizeOf(Sys));
    while FileRead(fd, Line, SizeOf(Line)) = SizeOf(Line) do
    begin
      if Line.Number = usLine then
      begin
        Found := True;
        Break;
      end;
    end;
    FileClose(fd);
  end;

  StrCopy(LastCaller, Sys.LastCaller);
  if LastCaller[0] = #0 then
    StrCopy(LastCaller, 'None');
  TotalCalls := Sys.Calls;
  TotalMailCalls := Sys.MailCalls;
  TotalTodayCalls := Sys.TodayCalls;

  if Found then
  begin
    LineNumber := Line.Number;
    Status := Line.Status;
    StrCopy(User, Line.User);
    StrCopy(From_, Line.From_);
    StrCopy(Action, Line.Action);
    StrCopy(LineLastCaller, Line.LastCaller);
    if LineLastCaller[0] = #0 then
      StrCopy(LineLastCaller, 'None');
    Calls := Line.Calls;
    MailCalls := Line.MailCalls;
    TodayCalls := Line.TodayCalls;
  end
  else
  begin
    LineNumber := usLine;
    Status := STAT_OFFLINE;
    StrCopy(User, 'None');
    Action[0] := #0;
    From_[0] := #0;
    StrCopy(LineLastCaller, 'None');
    Calls := 0;
    MailCalls := 0;
    TodayCalls := 0;
  end;
end;

procedure TStatistics.Update;
var
  fd: LongInt;
  Found: Boolean;
begin
  Found := False;
  FillChar(Sys, SizeOf(Sys), 0);

  StrCopy(Sys.LastCaller, LastCaller);
  Sys.Calls := TotalCalls;
  Sys.MailCalls := TotalMailCalls;
  Sys.TodayCalls := TotalTodayCalls;

  fd := FileOpen(StrPas(DataFile), fmOpenReadWrite or fmShareDenyNone);
  if fd = -1 then
    fd := FileCreate(StrPas(DataFile));

  if fd <> -1 then
  begin
    FileWrite(fd, Sys, SizeOf(Sys));
    while FileRead(fd, Line, SizeOf(Line)) = SizeOf(Line) do
    begin
      if Line.Number = LineNumber then
      begin
        Found := True;
        Break;
      end;
    end;

    FillChar(Line, SizeOf(Line), 0);

    Line.Number := LineNumber;
    StrCopy(Line.LastCaller, LineLastCaller);
    Line.Calls := Calls;
    Line.MailCalls := MailCalls;
    Line.TodayCalls := TodayCalls;
    Line.Status := Status;
    StrCopy(Line.User, User);
    StrCopy(Line.From_, From_);
    StrCopy(Line.Action, Action);

    if Found then
      FileSeek(fd, FileSeek(fd, 0, 1) - SizeOf(Line), 0);
    FileWrite(fd, Line, SizeOf(Line));

    FileClose(fd);
  end;
end;

end.
