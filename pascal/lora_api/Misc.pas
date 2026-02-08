{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of misc.cpp
  Utility functions: string manipulation, path building, external process
  execution, timer functions. CRC tables/functions are in Defs.pas.

  Many C functions replaced by FPC RTL equivalents:
  - strsrep -> StringReplace
  - BuildPath -> ForceDirectories
  - Pause -> Sleep
  - TimerSet/TimeUp -> GetTickCount64
}

unit Misc;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Process
  {$IFDEF UNIX}, BaseUnix{$ENDIF}
  {$IFDEF WINDOWS}, Windows{$ENDIF}
  {$IFDEF OS2}, DosCalls{$ENDIF};

{ String utilities }
function strinc(const Substr, Str: String): Integer;
function strdel(const Substr: String; var Str: String): Boolean;
procedure strins(const InsStr: String; var Str: String; StPos: Integer);
function strsrep(var Str: String; const Search, Replace: String): Boolean;

{ Path utilities }
function BuildPath(const Path: String): Boolean;
function BuildEmptyPath(const Path: String): Boolean;

{ Process execution }
procedure RunExternal(const Cmd: String; TimeLimit: Word = 0);
procedure SpawnExternal(const Cmd: String);

{ Timer functions - using GetTickCount64 instead of DOS timer }
function TimerSet(MilliSeconds: LongInt): QWord;
function TimeUp(EndTime: QWord): Boolean;
procedure Pause(MilliSeconds: LongInt);

{ System info }
function AvailableMemory: LongWord;

implementation

{ --- String utilities --- }

function strinc(const Substr, Str: String): Integer;
begin
  Result := Pos(Substr, Str);
end;

function strdel(const Substr: String; var Str: String): Boolean;
var
  P: Integer;
begin
  P := Pos(Substr, Str);
  if P > 0 then
  begin
    System.Delete(Str, P, Length(Substr));
    Result := True;
  end
  else
    Result := False;
end;

procedure strins(const InsStr: String; var Str: String; StPos: Integer);
begin
  System.Insert(InsStr, Str, StPos);
end;

function strsrep(var Str: String; const Search, Replace: String): Boolean;
var
  P: Integer;
begin
  P := Pos(Search, Str);
  if P > 0 then
  begin
    Str := StringReplace(Str, Search, Replace, []);
    Result := True;
  end
  else
    Result := False;
end;

{ --- Path utilities --- }

function BuildPath(const Path: String): Boolean;
begin
  Result := ForceDirectories(ExcludeTrailingPathDelimiter(Path));
end;

function BuildEmptyPath(const Path: String): Boolean;
var
  CleanPath: String;
  SR: TSearchRec;
begin
  Result := ForceDirectories(ExcludeTrailingPathDelimiter(Path));

  if Result then
  begin
    CleanPath := IncludeTrailingPathDelimiter(Path);
    if FindFirst(CleanPath + '*', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') and
             ((SR.Attr and faDirectory) = 0) then
            SysUtils.DeleteFile(CleanPath + SR.Name);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
  end;
end;

{ --- Process execution --- }

procedure RunExternal(const Cmd: String; TimeLimit: Word);
var
  Proc: TProcess;
  StartTime: QWord;
begin
  if Cmd = '' then Exit;

  Proc := TProcess.Create(nil);
  try
    {$IFDEF UNIX}
    Proc.Executable := '/bin/sh';
    Proc.Parameters.Add('-c');
    Proc.Parameters.Add(Cmd);
    {$ELSE}
    {$IFDEF WINDOWS}
    Proc.Executable := GetEnvironmentVariable('COMSPEC');
    if Proc.Executable = '' then
      Proc.Executable := 'CMD.EXE';
    Proc.Parameters.Add('/C');
    Proc.Parameters.Add(Cmd);
    {$ELSE}
    { DOS / OS2 fallback }
    Proc.Executable := GetEnvironmentVariable('COMSPEC');
    if Proc.Executable = '' then
      Proc.Executable := 'CMD.EXE';
    Proc.Parameters.Add('/C');
    Proc.Parameters.Add(Cmd);
    {$ENDIF}
    {$ENDIF}

    Proc.Options := [poWaitOnExit];
    if TimeLimit > 0 then
    begin
      Proc.Options := Proc.Options - [poWaitOnExit];
      Proc.Execute;
      StartTime := GetTickCount64;
      while Proc.Running do
      begin
        if (GetTickCount64 - StartTime) > (QWord(TimeLimit) * 60000) then
        begin
          Proc.Terminate(1);
          Break;
        end;
        Sleep(100);
      end;
    end
    else
      Proc.Execute;
  finally
    Proc.Free;
  end;
end;

procedure SpawnExternal(const Cmd: String);
var
  Proc: TProcess;
begin
  if Cmd = '' then Exit;

  Proc := TProcess.Create(nil);
  try
    {$IFDEF UNIX}
    Proc.Executable := '/bin/sh';
    Proc.Parameters.Add('-c');
    Proc.Parameters.Add(Cmd);
    {$ELSE}
    Proc.Executable := GetEnvironmentVariable('COMSPEC');
    if Proc.Executable = '' then
      Proc.Executable := 'CMD.EXE';
    Proc.Parameters.Add('/C');
    Proc.Parameters.Add(Cmd);
    {$ENDIF}

    { Fire and forget - don't wait }
    Proc.Options := [];
    Proc.Execute;
  finally
    Proc.Free;
  end;
end;

{ --- Timer functions --- }

function TimerSet(MilliSeconds: LongInt): QWord;
begin
  Result := GetTickCount64 + QWord(MilliSeconds);
end;

function TimeUp(EndTime: QWord): Boolean;
begin
  Result := GetTickCount64 >= EndTime;
end;

procedure Pause(MilliSeconds: LongInt);
begin
  Sleep(MilliSeconds);
end;

{ --- System info --- }

function AvailableMemory: LongWord;
begin
  {$IFDEF OS2}
  { DosQuerySysInfo could be called here }
  Result := 0;
  {$ELSE}
  Result := 0;
  {$ENDIF}
end;

end.
