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

  FreePascal conversion of combase.h, serial.cpp, tcpip.cpp, stdio.cpp,
  screen.cpp, npipe.cpp  (comm.tgt - Communications library)
}

unit LoraComBase;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, BaseUnix, Unix, Termio, Sockets,
  LoraDefs;

const
  RSIZE = 2048;
  TSIZE = 512;

  { Modem control line constants }
  DTR_        = 1;
  RTS_        = 2;
  CTS_        = 16;
  DSR_        = 32;
  RI_         = 64;
  DCD_        = 128;
  DATA_READY  = $0100;
  TX_SHIFT_EMPTY = $4000;

  { CXL color/attribute constants used by TScreen }
  CXL_BLACK    = 0;
  CXL_BLUE     = 1;
  CXL_GREEN    = 2;
  CXL_CYAN     = 3;
  CXL_RED      = 4;
  CXL_MAGENTA  = 5;
  CXL_BROWN    = 6;
  CXL_LGREY    = 7;
  CXL_DGREY    = 8;
  CXL_LBLUE    = 9;
  CXL_LGREEN   = 10;
  CXL_LCYAN    = 11;
  CXL_LRED     = 12;
  CXL_LMAGENTA = 13;
  CXL_YELLOW   = 14;
  CXL_WHITE    = 15;
  CXL_BLINK    = 128;
  CXL_BG_BLACK = 0;
  CXL_BG_BLUE  = 16;
  CXL_BG_GREEN = 32;
  CXL_BG_CYAN  = 48;
  CXL_BG_RED   = 64;
  CXL_BG_MAGENTA = 80;
  CXL_BG_BROWN = 96;
  CXL_BG_LGREY = 112;

type
  { Abstract base class for all communication }
  TCom = class
  public
    EndRun:  Word;
    RxBytes: Word;
    TxBytes: Word;

    constructor Create; virtual;
    destructor Destroy; override;

    function  BytesReady: Word; virtual; abstract;
    procedure BufferByte(AByte: Byte); virtual; abstract;
    procedure BufferBytes(ABytes: PByte; ALen: Word); virtual; abstract;
    function  Carrier: Word; virtual; abstract;
    procedure ClearOutbound; virtual; abstract;
    procedure ClearInbound; virtual; abstract;
    function  ReadByte: Byte; virtual; abstract;
    function  ReadBytes(ABytes: PByte; ALen: Word): Word; virtual; abstract;
    procedure SendByte(AByte: Byte); virtual; abstract;
    procedure SendBytes(ABytes: PByte; ALen: Word); virtual; abstract;
    procedure UnbufferBytes; virtual; abstract;

    procedure SetName(AName: PChar); virtual; abstract;
    procedure SetCity(AName: PChar); virtual; abstract;
    procedure SetLevel(ALevel: PChar); virtual; abstract;
    procedure SetTimeLeft(ASeconds: LongWord); virtual; abstract;
    procedure SetTime(ASeconds: LongWord); virtual; abstract;

  protected
    RxBuffer: array[0..RSIZE-1] of Byte;
    TxBuffer: array[0..TSIZE-1] of Byte;
    NextByte: PByte;
  end;

  { Serial port communication }
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

  { TCP/IP socket communication }
  TTcpip = class(TCom)
  public
    ClientIP:   array[0..15] of Char;
    ClientName: array[0..127] of Char;
    HostIP:     array[0..15] of Char;
    HostID:     LongWord;

    constructor Create; override;
    destructor Destroy; override;

    function  BytesReady: Word; override;
    procedure BufferByte(AByte: Byte); override;
    procedure BufferBytes(ABytes: PByte; ALen: Word); override;
    function  Carrier: Word; override;
    procedure ClearOutbound; override;
    procedure ClearInbound; override;
    procedure ClosePort;
    function  ConnectServer(pszServerName: PChar; usPort: Word): Word;
    function  Initialize(usPort: Word; usSocket: Word = 0; usProtocol: Word = IPPROTO_TCP): Word;
    function  ReadByte: Byte; override;
    function  ReadBytes(ABytes: PByte; ALen: Word): Word; override;
    procedure SendByte(AByte: Byte); override;
    procedure SendBytes(ABytes: PByte; ALen: Word); override;
    procedure UnbufferBytes; override;
    function  WaitClient: Word;

    function  GetPacket(lpBuffer: Pointer; usSize: Word): Word;
    function  PeekPacket(lpBuffer: Pointer; usSize: Word): Word;
    function  SendPacket(lpBuffer: Pointer; usSize: Word): Word;

    procedure SetName(AName: PChar); override;
    procedure SetCity(AName: PChar); override;
    procedure SetLevel(ALevel: PChar); override;
    procedure SetTimeLeft(ASeconds: LongWord); override;
    procedure SetTime(ASeconds: LongWord); override;

  private
    Sock:         LongInt;
    Accepted:     LongInt;
    LSock:        LongInt;
    fCarrierDown: Word;
    RxPosition:   Word;
    udp_client:   TInetSockAddr;
  end;

  { Standard I/O communication }
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

  { Screen/terminal communication (ANSI interpreter + CXL windowing) }
  TScreen = class(TCom)
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
    Running:    Word;
    RxPosition: Word;
    Attr:       Word;
    Count:      Word;
    Params:     array[0..9] of Word;
    Prec:       Char;
    AnsiState:  Char;
    Counter:    Word;
    CurRow:     SmallInt;
    CurCol:     SmallInt;
    ScreenBuf:  array[0..24, 0..79] of Char;
    ScreenAttr: array[0..24, 0..79] of Byte;
  end;

implementation

uses
  Errors;

const
  TIOCM_DTR = $002;
  TIOCM_RTS = $004;
  TIOCM_CAR = $040;
  TIOCMGET  = $5415;
  TIOCMSET  = $5418;
  FIONBIO   = $5421;

{ ======================================================================== }
{ TCom - Abstract base                                                      }
{ ======================================================================== }

constructor TCom.Create;
begin
  inherited Create;
  EndRun := 0;
  RxBytes := 0;
  TxBytes := 0;
  NextByte := nil;
end;

destructor TCom.Destroy;
begin
  inherited Destroy;
end;

{ ======================================================================== }
{ TSerial - Serial port communication (Linux)                               }
{ ======================================================================== }

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
    { Set blocking mode for flush }
    flags := FpFcntl(hFile, F_GETFL, 0);
    FpFcntl(hFile, F_SETFL, flags and (not O_NONBLOCK));
    repeat
      i := FpWrite(hFile, @TxBuffer[0], TxBytes);
      if i > 0 then
        Dec(TxBytes, Word(i));
    until TxBytes = 0;
    { Restore non-blocking mode }
    FpFcntl(hFile, F_SETFL, flags or O_NONBLOCK);
  end;
end;

procedure TSerial.SetName(AName: PChar);
begin
  { No-op for serial }
end;

procedure TSerial.SetCity(AName: PChar);
begin
  { No-op for serial }
end;

procedure TSerial.SetLevel(ALevel: PChar);
begin
  { No-op for serial }
end;

procedure TSerial.SetTimeLeft(ASeconds: LongWord);
begin
  { No-op for serial }
end;

procedure TSerial.SetTime(ASeconds: LongWord);
begin
  { No-op for serial }
end;

{ ======================================================================== }
{ TTcpip - TCP/IP socket communication (Linux)                              }
{ ======================================================================== }

constructor TTcpip.Create;
begin
  inherited Create;
  EndRun := 0;
  fCarrierDown := 0;
  TxBytes := 0;
  RxBytes := 0;
  RxPosition := 0;
  LSock := 0;
  Sock := 0;
  Accepted := 0;
end;

destructor TTcpip.Destroy;
begin
  ClosePort;
  inherited Destroy;
end;

procedure TTcpip.BufferByte(AByte: Byte);
begin
  TxBuffer[TxBytes] := AByte;
  Inc(TxBytes);
  if TxBytes >= TSIZE then
    UnbufferBytes;
end;

procedure TTcpip.BufferBytes(ABytes: PByte; ALen: Word);
var
  ToCopy: Word;
begin
  if (ALen > 0) and (EndRun = 0) then
    repeat
      ToCopy := ALen;
      if ToCopy > TSIZE - TxBytes then
        ToCopy := TSIZE - TxBytes;
      Move(ABytes^, TxBuffer[TxBytes], ToCopy);
      Inc(ABytes, ToCopy);
      Inc(TxBytes, ToCopy);
      Dec(ALen, ToCopy);
      if TxBytes >= TSIZE then
        UnbufferBytes;
    until (ALen = 0) or (EndRun <> 0) or (Carrier = 0);
end;

function TTcpip.BytesReady: Word;
var
  i: LongInt;
begin
  Result := 0;
  if (Sock <> 0) and (fCarrierDown = 0) and (EndRun = 0) then
  begin
    if RxBytes <> 0 then
      Result := 1
    else
    begin
      i := fpRecv(Sock, @RxBuffer[0], RSIZE, 0);
      if i = 0 then
        fCarrierDown := 1
      else if i = -1 then
      begin
        RxBytes := 0;
        if (fpGetErrno <> ESysEWOULDBLOCK) and (fpGetErrno <> ESysEAGAIN) then
          fCarrierDown := 1;
      end
      else
      begin
        RxBytes := Word(i);
        RxPosition := 0;
        Result := 1;
      end;
    end;
  end;
end;

function TTcpip.Carrier: Word;
begin
  if fCarrierDown <> 0 then
    Result := 0
  else
    Result := 1;
end;

procedure TTcpip.ClearInbound;
begin
  RxBytes := 0;
end;

procedure TTcpip.ClearOutbound;
begin
  { Nothing to do }
end;

procedure TTcpip.ClosePort;
begin
  if Sock <> 0 then
  begin
    FpClose(Sock);
    Sock := 0;
  end;
  if LSock <> 0 then
  begin
    FpClose(LSock);
    LSock := 0;
  end;
end;

function TTcpip.ConnectServer(pszServerName: PChar; usPort: Word): Word;
var
  i: LongInt;
  namelen: TSockLen;
  hostnm: PHostEnt;
  server, sock_addr: TInetSockAddr;
begin
  Result := 0;

  server.sin_family := AF_INET;
  server.sin_port := htons(usPort);

  hostnm := GetHostByName(pszServerName);
  if hostnm = nil then
  begin
    fCarrierDown := 1;
    Exit;
  end;
  server.sin_addr.s_addr := PLongWord(hostnm^.h_addr_list^)^;

  Sock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Sock >= 0 then
  begin
    if fpConnect(Sock, @server, SizeOf(server)) >= 0 then
    begin
      i := 1;
      FpIOCtl(Sock, FIONBIO, @i);

      namelen := SizeOf(TInetSockAddr);
      fpGetSockName(Sock, @sock_addr, @namelen);
      HostID := (sock_addr.sin_addr.s_addr and $FF000000) shr 24;
      HostID := HostID or ((sock_addr.sin_addr.s_addr and $00FF0000) shr 8);
      HostID := HostID or ((sock_addr.sin_addr.s_addr and $0000FF00) shl 8);
      HostID := HostID or ((sock_addr.sin_addr.s_addr and $000000FF) shl 24);

      Result := 1;
    end;
  end;

  if Result = 0 then
    fCarrierDown := 1;
end;

function TTcpip.Initialize(usPort: Word; usSocket: Word; usProtocol: Word): Word;
var
  i: LongInt;
  socktype: LongInt;
  server: TInetSockAddr;
  hid: LongWord;
begin
  Result := 0;

  hid := fpGetHostID;
  HostID := (hid and $00FF0000) shl 8;
  HostID := HostID or ((hid and $FF000000) shr 8);
  HostID := HostID or ((hid and $000000FF) shl 8);
  HostID := HostID or ((hid and $0000FF00) shr 8);

  StrFmt(HostIP, '%d.%d.%d.%d', [
    (HostID and $FF000000) shr 24,
    (HostID and $FF0000) shr 16,
    (HostID and $FF00) shr 8,
    HostID and $FF
  ]);

  if usSocket = 0 then
  begin
    socktype := SOCK_STREAM;
    if usProtocol = IPPROTO_UDP then
      socktype := SOCK_DGRAM;

    LSock := fpSocket(AF_INET, socktype, usProtocol);
    if LSock >= 0 then
    begin
      FillChar(server, SizeOf(server), 0);
      server.sin_family := AF_INET;
      server.sin_port := htons(usPort);
      server.sin_addr.s_addr := 0; { INADDR_ANY }

      if fpBind(LSock, @server, SizeOf(server)) >= 0 then
      begin
        if usProtocol = IPPROTO_TCP then
        begin
          if fpListen(LSock, 1) >= 0 then
          begin
            Sock := 0;
            Result := 1;
          end;
        end
        else
          Result := 1;
      end;
    end;
  end
  else
  begin
    Sock := usSocket;
    i := 1;
    FpIOCtl(Sock, FIONBIO, @i);
    Result := 1;
  end;
end;

function TTcpip.ReadByte: Byte;
var
  i: LongInt;
begin
  Result := 0;
  if Sock <> 0 then
  begin
    while (RxBytes = 0) and (EndRun = 0) and (fCarrierDown = 0) do
    begin
      i := fpRecv(Sock, @RxBuffer[0], RSIZE, 0);
      if i = 0 then
        fCarrierDown := 1
      else if i = -1 then
      begin
        RxBytes := 0;
        if (fpGetErrno <> ESysEWOULDBLOCK) and (fpGetErrno <> ESysEAGAIN) then
          fCarrierDown := 1;
      end
      else
      begin
        RxBytes := Word(i);
        RxPosition := 0;
      end;
    end;

    if (EndRun = 0) and (fCarrierDown = 0) then
    begin
      Result := RxBuffer[RxPosition];
      Inc(RxPosition);
      Dec(RxBytes);
    end;
  end;
end;

function TTcpip.ReadBytes(ABytes: PByte; ALen: Word): Word;
var
  i: LongInt;
  Max: Word;
begin
  Max := 0;
  if Sock <> 0 then
  begin
    while (RxBytes = 0) and (EndRun = 0) and (fCarrierDown = 0) do
    begin
      i := fpRecv(Sock, @RxBuffer[0], RSIZE, 0);
      if i = 0 then
        fCarrierDown := 1
      else if i = -1 then
      begin
        RxBytes := 0;
        if (fpGetErrno <> ESysEWOULDBLOCK) and (fpGetErrno <> ESysEAGAIN) then
          fCarrierDown := 1;
      end
      else
      begin
        RxBytes := Word(i);
        RxPosition := 0;
      end;
    end;

    if (EndRun = 0) and (fCarrierDown = 0) then
    begin
      Max := ALen;
      if Max > RxBytes then
        Max := RxBytes;
      Move(RxBuffer[RxPosition], ABytes^, Max);
      Dec(RxBytes, Max);
      Inc(RxPosition, Max);
    end;
  end;
  Result := Max;
end;

function TTcpip.PeekPacket(lpBuffer: Pointer; usSize: Word): Word;
var
  namelen: TSockLen;
begin
  namelen := SizeOf(udp_client);
  if fpRecvFrom(LSock, lpBuffer, usSize, MSG_PEEK, @udp_client, @namelen) > 0 then
    Result := 1
  else
    Result := 0;
end;

function TTcpip.GetPacket(lpBuffer: Pointer; usSize: Word): Word;
var
  namelen: TSockLen;
begin
  namelen := SizeOf(udp_client);
  Result := Word(fpRecvFrom(LSock, lpBuffer, usSize, 0, @udp_client, @namelen));
end;

function TTcpip.SendPacket(lpBuffer: Pointer; usSize: Word): Word;
begin
  Result := Word(fpSendTo(LSock, lpBuffer, usSize, 0, @udp_client, SizeOf(udp_client)));
end;

function TTcpip.WaitClient: Word;
var
  i: LongInt;
  s: LongInt;
  namelen: TSockLen;
  client: TInetSockAddr;
begin
  Sock := 0;

  namelen := SizeOf(client);
  s := fpAccept(LSock, @client, @namelen);
  if s > 0 then
  begin
    Sock := s;
    StrFmt(ClientIP, '%d.%d.%d.%d', [
      client.sin_addr.s_addr and $FF,
      (client.sin_addr.s_addr and $FF00) shr 8,
      (client.sin_addr.s_addr and $FF0000) shr 16,
      (client.sin_addr.s_addr and $FF000000) shr 24
    ]);
    StrCopy(ClientName, ClientIP);
    i := 1;
    FpIOCtl(Sock, FIONBIO, @i);
  end;

  Result := Word(Sock);
end;

procedure TTcpip.SendByte(AByte: Byte);
begin
  if (Sock <> 0) and (fCarrierDown = 0) and (EndRun = 0) then
    fpSend(Sock, @AByte, 1, 0);
end;

procedure TTcpip.SendBytes(ABytes: PByte; ALen: Word);
var
  i: LongInt;
begin
  if (Sock <> 0) and (fCarrierDown = 0) and (EndRun = 0) then
  begin
    repeat
      i := fpSend(Sock, ABytes, ALen, 0);
      if i > 0 then
      begin
        Dec(ALen, Word(i));
        Inc(ABytes, i);
      end
      else if i < 0 then
      begin
        if (fpGetErrno <> ESysEWOULDBLOCK) and (fpGetErrno <> ESysENOBUFS) then
          fCarrierDown := 1;
      end;
    until (ALen = 0) or (EndRun <> 0) or (Carrier = 0);
  end;
end;

procedure TTcpip.UnbufferBytes;
var
  i: LongInt;
  Written: LongInt;
  p: PByte;
  flag: LongInt;
begin
  while (Sock <> 0) and (fCarrierDown = 0) and (EndRun = 0) and (TxBytes > 0) do
  begin
    { Set blocking mode }
    flag := 0;
    FpIOCtl(Sock, FIONBIO, @flag);

    p := @TxBuffer[0];
    repeat
      Written := fpSend(Sock, p, TxBytes, 0);
      if Written > 0 then
      begin
        Inc(p, Written);
        Dec(TxBytes, Word(Written));
      end
      else if Written < 0 then
      begin
        if (fpGetErrno <> ESysEWOULDBLOCK) and (fpGetErrno <> ESysENOBUFS) then
          fCarrierDown := 1;
      end;
    until (TxBytes = 0) or (EndRun <> 0) or (Carrier = 0);

    { Restore non-blocking mode }
    flag := 1;
    FpIOCtl(Sock, FIONBIO, @flag);
  end;
end;

procedure TTcpip.SetName(AName: PChar);
begin
  { No-op for TCP/IP }
end;

procedure TTcpip.SetCity(AName: PChar);
begin
  { No-op for TCP/IP }
end;

procedure TTcpip.SetLevel(ALevel: PChar);
begin
  { No-op for TCP/IP }
end;

procedure TTcpip.SetTimeLeft(ASeconds: LongWord);
begin
  { No-op for TCP/IP }
end;

procedure TTcpip.SetTime(ASeconds: LongWord);
begin
  { No-op for TCP/IP }
end;

{ ======================================================================== }
{ TStdio - Standard I/O communication (Linux)                              }
{ ======================================================================== }

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
    i := FpRead(tty_fd, @RxBuffer[0], RSIZE);
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
  { Nothing to do }
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
  { Nothing to do on Linux - no buffering for tty writes }
end;

procedure TStdio.SetName(AName: PChar);
begin
  { No-op for stdio }
end;

procedure TStdio.SetCity(AName: PChar);
begin
  { No-op for stdio }
end;

procedure TStdio.SetLevel(ALevel: PChar);
begin
  { No-op for stdio }
end;

procedure TStdio.SetTimeLeft(ASeconds: LongWord);
begin
  { No-op for stdio }
end;

procedure TStdio.SetTime(ASeconds: LongWord);
begin
  { No-op for stdio }
end;

{ ======================================================================== }
{ TScreen - Screen/terminal with ANSI interpreter                           }
{ Replaces CXL windowing with direct ANSI terminal output on Linux          }
{ ======================================================================== }

constructor TScreen.Create;
begin
  inherited Create;
  AnsiState := #0;
  Prec := #0;
  Attr := CXL_BLACK or CXL_BG_LGREY;
  RxBytes := 0;
  RxPosition := 0;
  Counter := 0;
  Running := 0;
  CurRow := 0;
  CurCol := 0;
  FillChar(ScreenBuf, SizeOf(ScreenBuf), ' ');
  FillChar(ScreenAttr, SizeOf(ScreenAttr), 7);
end;

destructor TScreen.Destroy;
begin
  { Restore terminal }
  Write(#27'[0m');   { Reset attributes }
  Write(#27'[?25h'); { Show cursor }
  inherited Destroy;
end;

function TScreen.BytesReady: Word;
var
  c: Byte;
  i: LongInt;
begin
  Result := 0;

  { Try to read a byte in non-blocking mode from stdin }
  i := FpRead(0, @c, 1);
  if i > 0 then
  begin
    { Map special keys to ANSI escape sequences if needed }
    RxBuffer[RxBytes] := c;
    Inc(RxBytes);
  end;

  if RxBytes > 0 then
    Result := 1;
end;

procedure TScreen.BufferByte(AByte: Byte);
var
  i: Word;
  ch: Char;
begin
  ch := Char(AByte);

  if (ch = '[') and (Prec = #27) then
  begin
    AnsiState := #1;
    Count := 0;
    Params[Count] := 0;
  end
  else
  begin
    if AnsiState = #1 then
    begin
      if (ch >= 'A') and (ch <= 'Z') or (ch >= 'a') and (ch <= 'z') then
      begin
        case ch of
          'm': begin
            { SGR - Set Graphics Rendition: pass through to terminal }
            Write(#27'[');
            for i := 0 to Count do
            begin
              if i > 0 then Write(';');
              Write(Params[i]);
            end;
            Write('m');
          end;
          'A': begin { Cursor Up }
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'A');
          end;
          'B': begin { Cursor Down }
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'B');
          end;
          'C': begin { Cursor Forward }
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'C');
          end;
          'D': begin { Cursor Back }
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'D');
          end;
          'n': begin { Device Status Report }
            if Params[0] = 6 then
            begin
              { Return cursor position as escape sequence in rx buffer }
              RxBuffer[RxBytes] := $1B; Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('['); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('0'); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte(';'); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('0'); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('h'); Inc(RxBytes);
              RxPosition := 0;
            end;
          end;
          'f', 'H': begin { Cursor Position }
            Write(#27'[', Params[0], ';', Params[1], 'H');
          end;
          'J': begin { Erase in Display }
            if Params[0] = 2 then
              Write(#27'[2J');
          end;
          'K': begin { Erase in Line }
            Write(#27'[K');
          end;
        end;
        AnsiState := #0;
      end
      else if ch = ';' then
      begin
        Inc(Count);
        if Count < 10 then
          Params[Count] := 0;
      end
      else if (ch >= '0') and (ch <= '9') then
      begin
        Params[Count] := Params[Count] * 10 + Word(Byte(ch) - Byte('0'));
      end
      else
        AnsiState := #0;
    end
    else if AByte = 12 then { Form Feed / Ctrl-L }
      Write(#27'[2J')
    else if ch <> #27 then
      Write(ch);
  end;

  Prec := ch;
  Inc(Counter);
  if (Counter mod 64) = 0 then
  begin
    Flush(Output);
    Counter := 0;
  end;
end;

procedure TScreen.BufferBytes(ABytes: PByte; ALen: Word);
begin
  while ALen > 0 do
  begin
    BufferByte(ABytes^);
    Inc(ABytes);
    Dec(ALen);
  end;
end;

function TScreen.Carrier: Word;
begin
  Result := Running;
end;

procedure TScreen.ClearOutbound;
begin
  TxBytes := 0;
end;

procedure TScreen.ClearInbound;
begin
  RxBytes := 0;
end;

function TScreen.Initialize: Word;
begin
  RxBytes := 0;
  RxPosition := 0;
  Running := 1;

  { Set up terminal }
  Write(#27'[2J');    { Clear screen }
  Write(#27'[?25h');  { Show cursor }
  Flush(Output);

  Result := 1;
end;

function TScreen.ReadByte: Byte;
var
  c: Byte;
begin
  if RxBytes = 0 then
  begin
    { Blocking read }
    FpRead(0, @c, 1);
    Result := c;
  end
  else
  begin
    Result := RxBuffer[RxPosition];
    Inc(RxPosition);
    Dec(RxBytes);
    if RxBytes = 0 then
      RxPosition := 0;
  end;
end;

function TScreen.ReadBytes(ABytes: PByte; ALen: Word): Word;
var
  Max: Word;
begin
  Max := ALen;
  if Max > RxBytes then
    Max := RxBytes;
  if Max > 0 then
  begin
    Move(RxBuffer[RxPosition], ABytes^, Max);
    Inc(RxPosition, Max);
    Dec(RxBytes, Max);
    if RxBytes = 0 then
      RxPosition := 0;
  end;
  Result := Max;
end;

procedure TScreen.SendByte(AByte: Byte);
begin
  BufferByte(AByte);
  Flush(Output);
end;

procedure TScreen.SendBytes(ABytes: PByte; ALen: Word);
begin
  BufferBytes(ABytes, ALen);
  Flush(Output);
end;

procedure TScreen.UnbufferBytes;
begin
  Flush(Output);
end;

procedure TScreen.SetName(AName: PChar);
begin
  { Display name in status area - use terminal title for now }
  Write(#27']0;', AName, #7);
  Flush(Output);
end;

procedure TScreen.SetCity(AName: PChar);
begin
  { No direct equivalent without CXL - could extend status line }
end;

procedure TScreen.SetLevel(ALevel: PChar);
begin
  { No direct equivalent without CXL }
end;

procedure TScreen.SetTimeLeft(ASeconds: LongWord);
begin
  { No direct equivalent without CXL }
end;

procedure TScreen.SetTime(ASeconds: LongWord);
begin
  { No direct equivalent without CXL }
end;

end.
