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

  FreePascal conversion of serial.cpp - TSerial class
}

unit LoraSerial;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, BaseUnix, Unix, Termio,
  LoraDefs, LoraComBase;

type
  TSerial = class(TCom)
  public
    Device:   array[0..31] of Char;
    Speed:    LongWord;
    DataBits: Word;
    StopBits: Word;
    Parity:   Char;
    hFile:    LongInt;
    tty:      Termios;

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
    procedure SetDTR(fStatus: Word);
    procedure SetRTS(fStatus: Word);
    procedure SetParameters(ulSpeed: LongWord; nData: Word; nParity: Byte; nStop: Word);
    procedure UnbufferBytes; override;

    procedure SetName(AName: PChar); override;
    procedure SetCity(AName: PChar); override;
    procedure SetLevel(ALevel: PChar); override;
    procedure SetTimeLeft(ASeconds: LongWord); override;
    procedure SetTime(ASeconds: LongWord); override;

  private
    new_termio: Termios;
    old_termio: Termios;
  end;

implementation

const
  TIOCM_DTR = $002;
  TIOCM_RTS = $004;
  TIOCM_CAR = $040;
  TIOCMGET  = $5415;
  TIOCMSET  = $5418;

constructor TSerial.Create;
begin
  inherited Create;
  hFile := -1;
  StrPCopy(Device, '/dev/modem');
  Speed := 19200;
  DataBits := 8;
  StopBits := 1;
  Parity := 'N';
  EndRun := 0;
  TxBytes := 0;
  RxBytes := 0;
end;

destructor TSerial.Destroy;
begin
  if hFile >= 0 then
  begin
    TCSetAttr(hFile, TCSANOW, old_termio);
    FpClose(hFile);
  end;
  inherited Destroy;
end;

procedure TSerial.BufferByte(AByte: Byte);
begin
  TxBuffer[TxBytes] := AByte;
  Inc(TxBytes);
  if TxBytes >= TSIZE then
    UnbufferBytes;
end;

procedure TSerial.BufferBytes(ABytes: PByte; ALen: Word);
var
  ToCopy: Word;
begin
  if (ALen > 0) and (EndRun = 0) then
  begin
    repeat
      if TxBytes < TSIZE then
      begin
        ToCopy := ALen;
        if ToCopy > TSIZE - TxBytes then
          ToCopy := TSIZE - TxBytes;
        Move(ABytes^, TxBuffer[TxBytes], ToCopy);
        Inc(ABytes, ToCopy);
        Inc(TxBytes, ToCopy);
        Dec(ALen, ToCopy);
      end;
      if TxBytes >= TSIZE then
        UnbufferBytes;
    until (ALen = 0) or (EndRun <> 0);
  end;
end;

function TSerial.BytesReady: Word;
var
  i: LongInt;
begin
  Result := 0;
  if hFile >= 0 then
  begin
    if RxBytes > 0 then
      Result := 1
    else
    begin
      i := FpRead(hFile, @RxBuffer[0], RSIZE);
      if i > 0 then
      begin
        RxBytes := Word(i);
        NextByte := @RxBuffer[0];
        Result := 1;
      end;
    end;
  end;
end;

function TSerial.Carrier: Word;
var
  mcs: LongInt;
begin
  mcs := 0;
  FpIOCtl(hFile, TIOCMGET, @mcs);
  if (mcs and TIOCM_CAR) <> 0 then
    Result := 1
  else
    Result := 0;
end;

procedure TSerial.ClearInbound;
begin
  RxBytes := 0;
end;

procedure TSerial.ClearOutbound;
begin
  TxBytes := 0;
end;

function TSerial.Initialize: Word;
begin
  Result := 0;
  hFile := FpOpen(Device, O_RDWR or O_NONBLOCK);
  if hFile >= 0 then
  begin
    TCGetAttr(hFile, old_termio);
    new_termio := old_termio;
    new_termio.c_iflag := 0;
    new_termio.c_oflag := 0;
    new_termio.c_lflag := 0;
    new_termio.c_cflag := CRTSCTS;
    TCSetAttr(hFile, TCSANOW, new_termio);
    SetParameters(Speed, DataBits, Byte(Parity), StopBits);
    Result := 1;
  end;
end;

function TSerial.ReadByte: Byte;
var
  i: LongInt;
begin
  Result := 0;
  if hFile >= 0 then
  begin
    if RxBytes = 0 then
    begin
      repeat
        i := FpRead(hFile, @RxBuffer[0], RSIZE);
      until (i > 0) or (EndRun <> 0);
      if i > 0 then
      begin
        RxBytes := Word(i);
        NextByte := @RxBuffer[0];
      end;
    end;
  end;
  if RxBytes > 0 then
  begin
    Result := NextByte^;
    Inc(NextByte);
    Dec(RxBytes);
  end;
end;

function TSerial.ReadBytes(ABytes: PByte; ALen: Word): Word;
var
  i: LongInt;
  Max: Word;
begin
  Max := 0;
  if hFile >= 0 then
  begin
    if RxBytes = 0 then
    begin
      repeat
        i := FpRead(hFile, @RxBuffer[0], RSIZE);
      until (i > 0) or (EndRun <> 0);
      if i > 0 then
      begin
        RxBytes := Word(i);
        NextByte := @RxBuffer[0];
      end;
    end;
  end;
  if RxBytes > 0 then
  begin
    Max := ALen;
    if Max > RxBytes then
      Max := RxBytes;
    Move(NextByte^, ABytes^, Max);
    Dec(RxBytes, Max);
    Inc(NextByte, Max);
  end;
  Result := Max;
end;

procedure TSerial.SetDTR(fStatus: Word);
var
  mcs: LongInt;
begin
  mcs := 0;
  FpIOCtl(hFile, TIOCMGET, @mcs);
  if fStatus = 0 then
    mcs := mcs and (not TIOCM_DTR)
  else
    mcs := mcs or TIOCM_DTR;
  FpIOCtl(hFile, TIOCMSET, @mcs);
end;

procedure TSerial.SetRTS(fStatus: Word);
var
  mcs: LongInt;
begin
  mcs := 0;
  FpIOCtl(hFile, TIOCMGET, @mcs);
  if fStatus = 0 then
    mcs := mcs and (not TIOCM_RTS)
  else
    mcs := mcs or TIOCM_RTS;
  FpIOCtl(hFile, TIOCMSET, @mcs);
end;

procedure TSerial.SetParameters(ulSpeed: LongWord; nData: Word; nParity: Byte; nStop: Word);
var
  spd: LongWord;
begin
  TCGetAttr(hFile, tty);

  case ulSpeed of
    300:     spd := B300;
    1200:    spd := B1200;
    2400:    spd := B2400;
    4800:    spd := B4800;
    9600:    spd := B9600;
    19200:   spd := B19200;
    38400:   spd := B38400;
    57600:   spd := B57600;
    115200:  spd := B115200;
  else
    spd := B19200;
  end;

  CfSetOSpeed(tty, spd);
  CfSetISpeed(tty, spd);

  tty.c_cflag := tty.c_cflag and (not CSIZE);
  case nData of
    5: tty.c_cflag := tty.c_cflag or CS5;
    6: tty.c_cflag := tty.c_cflag or CS6;
    7: tty.c_cflag := tty.c_cflag or CS7;
  else
    tty.c_cflag := tty.c_cflag or CS8;
  end;

  tty.c_cflag := tty.c_cflag or CRTSCTS;

  tty.c_cflag := tty.c_cflag and (not (PARENB or PARODD));
  if Char(nParity) = 'E' then
    tty.c_cflag := tty.c_cflag or PARENB
  else if Char(nParity) = 'O' then
    tty.c_cflag := tty.c_cflag or (PARENB or PARODD);

  TCSetAttr(hFile, TCSANOW, tty);
end;

procedure TSerial.SendByte(AByte: Byte);
begin
  while FpWrite(hFile, @AByte, 1) <> 1 do
    ;
end;

procedure TSerial.SendBytes(ABytes: PByte; ALen: Word);
begin
  FpWrite(hFile, ABytes, ALen);
end;

procedure TSerial.UnbufferBytes;
var
  i: LongInt;
  flags: LongInt;
begin
  if TxBytes > 0 then
  begin
    flags := FpFcntl(hFile, F_GETFL, 0);
    FpFcntl(hFile, F_SETFL, flags and (not O_NONBLOCK));
    repeat
      i := FpWrite(hFile, @TxBuffer[0], TxBytes);
      if i > 0 then
        Dec(TxBytes, Word(i));
    until TxBytes = 0;
    FpFcntl(hFile, F_SETFL, flags or O_NONBLOCK);
  end;
end;

procedure TSerial.SetName(AName: PChar);
begin
end;

procedure TSerial.SetCity(AName: PChar);
begin
end;

procedure TSerial.SetLevel(ALevel: PChar);
begin
end;

procedure TSerial.SetTimeLeft(ASeconds: LongWord);
begin
end;

procedure TSerial.SetTime(ASeconds: LongWord);
begin
end;

end.
