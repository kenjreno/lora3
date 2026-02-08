{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of stats.cpp - TStatistics class
  Reads/writes stats.dat for BBS system and per-line statistics.
}

unit Stats;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc299;

const
  STAT_OFFLINE    = 0;
  STAT_WAITING    = 1;
  STAT_USER       = 2;
  STAT_MAILER     = 3;
  STAT_FAXRECEIVE = 4;

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
    DataFile: String;
    Sys:      SYSSTAT;
    Line:     LINESTAT;
  end;

implementation

constructor TStatistics.Create;
begin
  inherited Create;
  DataFile := 'stats.dat';
end;

constructor TStatistics.Create(pszDataPath: PChar);
begin
  inherited Create;
  DataFile := IncludeTrailingPathDelimiter(StrPas(pszDataPath)) + 'stats.dat';
end;

destructor TStatistics.Destroy;
begin
  inherited Destroy;
end;

function OpenOrCreate(const FileName: String): TFileStream;
begin
  if FileExists(FileName) then
    Result := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(FileName, fmCreate);
end;

function TStatistics.First: Word;
begin
  LastTask := 0;
  Result := Next;
end;

function TStatistics.Next: Word;
var
  fs: TFileStream;
begin
  Result := 0;
  FillChar(Sys, SizeOf(Sys), 0);

  try
    fs := OpenOrCreate(DataFile);
    try
      fs.Read(Sys, SizeOf(Sys));
      while fs.Read(Line, SizeOf(Line)) = SizeOf(Line) do
      begin
        if Line.Number > LastTask then
        begin
          Result := 1;
          Break;
        end;
      end;
    finally
      fs.Free;
    end;
  except
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
  fs: TFileStream;
  Found: Boolean;
begin
  Found := False;
  FillChar(Sys, SizeOf(Sys), 0);

  try
    fs := OpenOrCreate(DataFile);
    try
      fs.Read(Sys, SizeOf(Sys));
      while fs.Read(Line, SizeOf(Line)) = SizeOf(Line) do
      begin
        if Line.Number = usLine then
        begin
          Found := True;
          Break;
        end;
      end;
    finally
      fs.Free;
    end;
  except
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
  fs: TFileStream;
  Found: Boolean;
begin
  Found := False;
  FillChar(Sys, SizeOf(Sys), 0);

  StrCopy(Sys.LastCaller, LastCaller);
  Sys.Calls := TotalCalls;
  Sys.MailCalls := TotalMailCalls;
  Sys.TodayCalls := TotalTodayCalls;

  try
    fs := OpenOrCreate(DataFile);
    try
      fs.Write(Sys, SizeOf(Sys));
      while fs.Read(Line, SizeOf(Line)) = SizeOf(Line) do
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
        fs.Seek(fs.Position - SizeOf(Line), soFromBeginning);
      fs.Write(Line, SizeOf(Line));
    finally
      fs.Free;
    end;
  except
  end;
end;

end.
