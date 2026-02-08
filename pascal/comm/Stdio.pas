{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

  FreePascal conversion of stdio.cpp - TStdio class
}

unit Stdio;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, BaseUnix, Unix, Termio,
  Defs, ComBase;

type
  TStdio = class(TCom)
  public
    constructor Create; override;
    destructor Destroy; override;

    function  BytesReady: Word; override;
    procedure BufferByte(AByte: Byte); override;
    procedure BufferBytes(ABytes: PByte; ALen: Word); override;
    function  Carrier: Word; override;
    procedure ClearOutbound; override;
    procedure ClearInbound; override;
    function  Initialize: Word;
    function  ReadByte: Byte; override;
    function  ReadBytes(ABytes: PByte; ALen: Word): Word; override;
    procedure SendByte(AByte: Byte); override;
    procedure SendBytes(ABytes: PByte; ALen: Word); override;
    procedure UnbufferBytes; override;

    procedure SetName(AName: PChar); override;
    procedure SetCity(AName: PChar); override;
    procedure SetLevel(ALevel: PChar); override;
    procedure SetTimeLeft(ASeconds: LongWord); override;
    procedure SetTime(ASeconds: LongWord); override;

  private
    RxPosition: Word;
    tty_fd:     LongInt;
    new_termio: Termios;
    old_termio: Termios;
  end;

implementation

constructor TStdio.Create;
begin
  inherited Create;
  RxBytes := 0;
  RxPosition := 0;
  tty_fd := -1;
end;

destructor TStdio.Destroy;
begin
  if tty_fd <> -1 then
  begin
    TCSetAttr(tty_fd, TCSANOW, old_termio);
    FpClose(tty_fd);
    tty_fd := -1;
  end;
  inherited Destroy;
end;

function TStdio.BytesReady: Word;
var
  i: LongInt;
begin
  Result := 0;
  if RxBytes = 0 then
  begin
    i := FpRead(tty_fd, @RxBuffer[0], ComBase.RSIZE);
    if i > 0 then
    begin
      RxBytes := Word(i);
      RxPosition := 0;
      Result := 1;
    end;
  end
  else
    Result := 1;
end;

procedure TStdio.BufferByte(AByte: Byte);
begin
  FpWrite(tty_fd, @AByte, 1);
end;

procedure TStdio.BufferBytes(ABytes: PByte; ALen: Word);
begin
  FpWrite(tty_fd, ABytes, ALen);
end;

function TStdio.Carrier: Word;
begin
  Result := 1;
end;

procedure TStdio.ClearOutbound;
begin
end;

procedure TStdio.ClearInbound;
begin
  RxBytes := 0;
end;

function TStdio.Initialize: Word;
begin
  Result := 1;
  tty_fd := 0; { stdin fileno }
  FpFcntl(tty_fd, F_SETFL, O_NONBLOCK);

  TCGetAttr(tty_fd, old_termio);
  new_termio := old_termio;
  new_termio.c_iflag := new_termio.c_iflag and (not ICRNL);
  new_termio.c_lflag := new_termio.c_lflag and (not (ISIG or ICANON or ECHO));
  TCSetAttr(tty_fd, TCSANOW, new_termio);
end;

function TStdio.ReadByte: Byte;
begin
  Result := 0;
  if RxBytes > 0 then
  begin
    Result := RxBuffer[RxPosition];
    Inc(RxPosition);
    Dec(RxBytes);
  end;
end;

function TStdio.ReadBytes(ABytes: PByte; ALen: Word): Word;
var
  Max: Word;
begin
  Max := 0;
  while (ALen > 0) and (BytesReady <> 0) do
  begin
    ABytes^ := ReadByte;
    Inc(ABytes);
    Dec(ALen);
    Inc(Max);
  end;
  Result := Max;
end;

procedure TStdio.SendByte(AByte: Byte);
begin
  FpWrite(tty_fd, @AByte, 1);
end;

procedure TStdio.SendBytes(ABytes: PByte; ALen: Word);
begin
  FpWrite(tty_fd, ABytes, ALen);
end;

procedure TStdio.UnbufferBytes;
begin
end;

procedure TStdio.SetName(AName: PChar);
begin
end;

procedure TStdio.SetCity(AName: PChar);
begin
end;

procedure TStdio.SetLevel(ALevel: PChar);
begin
end;

procedure TStdio.SetTimeLeft(ASeconds: LongWord);
begin
end;

procedure TStdio.SetTime(ASeconds: LongWord);
begin
end;

end.
