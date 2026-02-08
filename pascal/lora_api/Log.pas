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
  SysUtils;

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
    FileName: String;
  end;

implementation

constructor TLog.Create;
begin
  inherited Create;
  fpOpen := False;
  Display := 0;
  FileName := '';
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

  FileName := StrPas(pszName);
  Assign(fp, FileName);
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
    Assign(fp, FileName);
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
  MsgText, LogLine: String;
begin
  MsgText := Format(StrPas(pszFormat), Args);

  { Format: <level char> DD Mon HH:MM:SS LORA <rest of message>
    First character of message is the log level indicator }
  if Length(MsgText) > 0 then
    LogLine := MsgText[1] + FormatDateTime(' dd mmm hh:nn:ss ', Now) +
               'LORA ' + Copy(MsgText, 2, MaxInt)
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
