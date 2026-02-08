{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of snoop.cpp
  Remote snooping utility - connects to a running BBS node via pipe
  and relays I/O between the local screen and the remote session.
}

program Snoop;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, ComBase, Npipe, Screen;

const
  PROG_NAME    = 'FastWay BBS';
  PROG_VERSION = '1.0.0';

var
  Readed: Word;
  Temp: array[0..255] of Byte;
  Pipe: TPipe;
  Stdio: TScreen;
begin
  WriteLn;
  WriteLn(Format('SNOOP; %s v%s - Remote snooping utility', [PROG_NAME, PROG_VERSION]));
  WriteLn('       Based on LoraBBS by Marco Maccaferri. GPL v2 Licensed.');
  WriteLn;

  if ParamCount < 2 then
  begin
    WriteLn(' * Usage: snoop <server> <port>');
    WriteLn;
    Halt(1);
  end;

  Pipe := TPipe.Create;
  try
    if Pipe.ConnectServer(ParamStr(1), ParamStr(2)) then
    begin
      Pipe.Time := 0;
      Stdio := TScreen.Create;
      try
        Stdio.Initialize;
        while Stdio.Carrier and Pipe.Carrier do
        begin
          if Stdio.BytesReady then
          begin
            Readed := Stdio.ReadBytes(@Temp[0], SizeOf(Temp));
            Pipe.SendBytes(@Temp[0], Readed);
          end;
          if Pipe.BytesReady then
          begin
            Readed := Pipe.ReadBytes(@Temp[0], SizeOf(Temp));
            Stdio.SendBytes(@Temp[0], Readed);
          end;
          if Pipe.Time <> 0 then
          begin
            Stdio.SetName(Pipe.Name);
            Stdio.SetCity(Pipe.City);
            Stdio.SetLevel(Pipe.Level);
            Stdio.SetTimeLeft(Pipe.TimeLeft);
            Stdio.SetTime(Pipe.Time);
            Pipe.Time := 0;
          end;
        end;
      finally
        Stdio.Free;
      end;
    end
    else
      WriteLn(' * Error: Could not connect to server');
  finally
    Pipe.Free;
  end;
end.
