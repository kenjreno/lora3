{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of log.cpp - TLog class
  BBS log file writer with timestamped entries.
}

unit Log;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Defs;

type
  TLog = class
  public
    Display: Word;

    constructor Create; virtual;
    destructor Destroy; override;

    function  Open(pszName: PChar): Word; virtual;
    procedure Resume; virtual;
    procedure Suspend; virtual;
    procedure Write(pszFormat: PChar; const Args: array of const); virtual;
    procedure Write(pszFormat: PChar); virtual;
    procedure WriteBlank; virtual;

  protected
    fp:       Text;
    fpOpen:   Boolean;
    Months:   array[0..11] of String[3];
    FileName: array[0..127] of Char;
    Buffer:   array[0..511] of Char;
    Temp:     array[0..511] of Char;
  end;

implementation

constructor TLog.Create;
begin
  inherited Create;
  fpOpen := False;
  Display := 0;

  Months[0]  := 'Jan';
  Months[1]  := 'Feb';
  Months[2]  := 'Mar';
  Months[3]  := 'Apr';
  Months[4]  := 'May';
  Months[5]  := 'Jun';
  Months[6]  := 'Jul';
  Months[7]  := 'Aug';
  Months[8]  := 'Sep';
  Months[9]  := 'Oct';
  Months[10] := 'Nov';
  Months[11] := 'Dec';
end;

destructor TLog.Destroy;
begin
  if fpOpen then
  begin
    System.Close(fp);
    fpOpen := False;
  end;
  inherited Destroy;
end;

function TLog.Open(pszName: PChar): Word;
begin
  Result := 0;

  if fpOpen then
  begin
    System.Close(fp);
    fpOpen := False;
  end;

  StrCopy(FileName, pszName);
  Assign(fp, StrPas(FileName));
  {$I-}
  Append(fp);
  {$I+}
  if IOResult <> 0 then
  begin
    {$I-}
    Rewrite(fp);
    {$I+}
    if IOResult <> 0 then
      Exit;
  end;

  fpOpen := True;
  Result := 1;
end;

procedure TLog.Suspend;
begin
  if fpOpen then
  begin
    System.Close(fp);
    fpOpen := False;
  end;
end;

procedure TLog.Resume;
begin
  if not fpOpen then
  begin
    Assign(fp, StrPas(FileName));
    {$I-}
    Append(fp);
    {$I+}
    if IOResult <> 0 then
    begin
      {$I-}
      Rewrite(fp);
      {$I+}
      if IOResult = 0 then
        fpOpen := True;
    end
    else
      fpOpen := True;
  end;
end;

procedure TLog.Write(pszFormat: PChar; const Args: array of const);
var
  Now: TDateTime;
  Day, Month, Year, Hour, Min, Sec, MSec: Word;
  LogLine: String;
  MsgText: String;
begin
  MsgText := Format(StrPas(pszFormat), Args);

  Now := SysUtils.Now;
  DecodeDate(Now, Year, Month, Day);
  DecodeTime(Now, Hour, Min, Sec, MSec);

  { Format: <first char> DD Mon HH:MM:SS LORA <rest of message>
    First character of message is the log level indicator }
  if Length(MsgText) > 0 then
    LogLine := Format('%s %02d %s %02d:%02d:%02d %s %s',
      [MsgText[1], Day, Months[Month - 1], Hour, Min, Sec, 'LORA',
       Copy(MsgText, 2, Length(MsgText) - 1)])
  else
    LogLine := '';

  if fpOpen then
  begin
    WriteLn(fp, LogLine);
    Flush(fp);
  end;
end;

procedure TLog.Write(pszFormat: PChar);
begin
  Write(pszFormat, []);
end;

procedure TLog.WriteBlank;
begin
  if fpOpen then
  begin
    WriteLn(fp);
    Flush(fp);
  end;
end;

end.
