{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of luser.cpp
  User maintenance utility
}

program LUser;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, DateUtils, User;

const
  PROG_NAME    = 'LoraBBS';
  PROG_VERSION = '2.99.70';

procedure PurgeUsers(Days: Word; Level: Word);
var
  Today: LongInt;
  DaysInactive: LongWord;
  DT: TDateTime;
  Usr: TUser;
begin
  WriteLn(' * Purging Users');
  Today := DateTimeToUnix(Now);

  Usr := TUser.Create;
  try
    if Usr.Open('users') then
    begin
      if Usr.First then
      repeat
        if (Level = 0) or (Usr.Level < Level) then
        begin
          DaysInactive := (Today - Usr.LastCall) div 86400;
          if DaysInactive >= Days then
          begin
            DT := UnixToDateTime(Usr.LastCall);
            WriteLn(Format(' +-- %-30s Last: %s (%u days)',
              [Usr.Name, FormatDateTime('ddd mmm dd hh:nn:ss yyyy', DT), DaysInactive]));
            Usr.Delete;
          end;
        end;
      until not Usr.Next;
      Usr.Close;
    end;
  finally
    Usr.Free;
  end;
end;

procedure PackUsers;
var
  Usr: TUser;
begin
  WriteLn(' * Pack (Compressing) Users');

  Usr := TUser.Create;
  try
    if Usr.Open('users') then
    begin
      Usr.Pack;
      Usr.Close;
    end;
  finally
    Usr.Free;
  end;
end;

var
  i: Integer;
  DoPack: Boolean;
  Purge, Level: Word;
begin
  DoPack := False;
  Purge := 0;
  Level := 0;

  WriteLn;
  WriteLn(Format('LUSER; %s v%s - User maintenance utility', [PROG_NAME, PROG_VERSION]));
  WriteLn('       Copyright (c) 1991-96 by Marco Maccaferri. All Rights Reserved.');
  WriteLn;

  if ParamCount = 0 then
  begin
    WriteLn(' * Command-line parameters:');
    WriteLn;
    WriteLn('        -P        Pack (compress) user file');
    WriteLn('        -D[n]     Delete users who haven''t called in [n] days');
    WriteLn('        -M[s]     Only purge users with security level less than [s]');
    WriteLn;
    WriteLn(' * Please refer to the documentation for a more complete command summary');
    WriteLn;
  end
  else
  begin
    for i := 1 to ParamCount do
    begin
      if (ParamStr(i)[1] = '-') or (ParamStr(i)[1] = '/') then
      begin
        case UpCase(ParamStr(i)[2]) of
          'D': Purge := StrToIntDef(Copy(ParamStr(i), 3, Length(ParamStr(i))), 0);
          'M': Level := StrToIntDef(Copy(ParamStr(i), 3, Length(ParamStr(i))), 0);
          'P': DoPack := True;
        end;
      end;
    end;

    if Purge <> 0 then
      PurgeUsers(Purge, Level);
    if DoPack then
      PackUsers;

    if (Purge <> 0) or DoPack then
      WriteLn(' * Done')
    else
      WriteLn(' * Nothing to do');
    WriteLn;
  end;
end.
