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

  FreePascal conversion of tcpip.cpp - TTcpip class
  Uses Synapse blcksock for cross-platform TCP/UDP (Windows/Linux/OS2).
  DOS uses Waterloo TCP (Watt-32) if a packet driver is loaded.
  Call TcpipAvailable to check at runtime before creating TTcpip objects.
}

unit Tcpip;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils,
  {$IFDEF MSDOS}
  Dos,
  {$ELSE}
  blcksock, synsock, synautil,
  {$ENDIF}
  Defs, ComBase;

{ Returns True if TCP/IP networking is available on this system.
  - Windows/Linux/OS2: Always True (OS provides TCP/IP stack)
  - DOS: True only if a packet driver is loaded (checks INT 60h-7Fh
    for the "PKT DRVR" signature). Use this to decide whether to
    offer TCP/IP features at startup. }
function TcpipAvailable: Boolean;

{$IFDEF MSDOS}
{ Returns the interrupt vector number (60h-7Fh) of the packet driver,
  or 0 if no packet driver is found. Equivalent to vec_search() from
  the original Waterloo TCP code. }
function PacketDriverVector: Byte;
{$ENDIF}

type
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
    function  Initialize(usPort: Word; usSocket: Word = 0; usProtocol: Word = 0): Word;
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
    {$IFNDEF MSDOS}
    FSock:        TTCPBlockSocket;   { Connected/accepted data socket }
    FListenSock:  TTCPBlockSocket;   { Listening socket for TCP server }
    FUDPSock:     TUDPBlockSocket;   { UDP socket for packet operations }
    {$ENDIF}
    fCarrierDown: Word;
    RxPosition:   Word;
    IsUDP:        Boolean;
  end;

const
  PROTO_TCP = 0;
  PROTO_UDP = 1;

implementation

{$IFDEF MSDOS}
const
  PKT_DRVR_SIG: array[0..7] of Char = 'PKT DRVR';

function PacketDriverVector: Byte;
var
  Vec: Byte;
  IntVec: Pointer;
  p: PChar;
  Match: Boolean;
  i: Integer;
begin
  Result := 0;
  { Scan interrupt vectors 60h through 7Fh for packet driver signature.
    The packet driver spec says: at the ISR entry point + 3 bytes,
    there must be the ASCII string "PKT DRVR" (8 bytes). }
  for Vec := $60 to $7F do
  begin
    GetIntVec(Vec, IntVec);
    if IntVec <> nil then
    begin
      { Check for "PKT DRVR" at offset +3 from handler }
      p := PChar(IntVec) + 3;
      Match := True;
      for i := 0 to 7 do
      begin
        if p[i] <> PKT_DRVR_SIG[i] then
        begin
          Match := False;
          Break;
        end;
      end;
      if Match then
      begin
        Result := Vec;
        Exit;
      end;
    end;
  end;
end;
{$ENDIF}

function TcpipAvailable: Boolean;
begin
  {$IFDEF MSDOS}
  Result := (PacketDriverVector <> 0);
  {$ELSE}
  Result := True;  { Win/Linux/OS2 always have TCP/IP }
  {$ENDIF}
end;

constructor TTcpip.Create;
begin
  inherited Create;
  EndRun := 0;
  fCarrierDown := 0;
  TxBytes := 0;
  RxBytes := 0;
  RxPosition := 0;
  IsUDP := False;
  {$IFNDEF MSDOS}
  FSock := nil;
  FListenSock := nil;
  FUDPSock := nil;
  {$ENDIF}
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
  if TxBytes >= ComBase.TSIZE then
    UnbufferBytes;
end;

procedure TTcpip.BufferBytes(ABytes: PByte; ALen: Word);
var
  ToCopy: Word;
begin
  if (ALen > 0) and (EndRun = 0) then
    repeat
      ToCopy := ALen;
      if ToCopy > ComBase.TSIZE - TxBytes then
        ToCopy := ComBase.TSIZE - TxBytes;
      Move(ABytes^, TxBuffer[TxBytes], ToCopy);
      Inc(ABytes, ToCopy);
      Inc(TxBytes, ToCopy);
      Dec(ALen, ToCopy);
      if TxBytes >= ComBase.TSIZE then
        UnbufferBytes;
    until (ALen = 0) or (EndRun <> 0) or (Carrier = 0);
end;

function TTcpip.BytesReady: Word;
{$IFNDEF MSDOS}
var
  i: LongInt;
{$ENDIF}
begin
  Result := 0;

  {$IFNDEF MSDOS}
  if (FSock <> nil) and (fCarrierDown = 0) and (EndRun = 0) then
  begin
    if RxBytes <> 0 then
      Result := 1
    else
    begin
      if FSock.CanRead(0) then
      begin
        i := FSock.RecvBufferEx(@RxBuffer[0], ComBase.RSIZE, 0);
        if i = 0 then
          fCarrierDown := 1
        else if i < 0 then
        begin
          RxBytes := 0;
          if FSock.LastError <> WSAEWOULDBLOCK then
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
  {$ENDIF}
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
end;

procedure TTcpip.ClosePort;
begin
  {$IFNDEF MSDOS}
  if FSock <> nil then
  begin
    FSock.CloseSocket;
    FSock.Free;
    FSock := nil;
  end;
  if FListenSock <> nil then
  begin
    FListenSock.CloseSocket;
    FListenSock.Free;
    FListenSock := nil;
  end;
  if FUDPSock <> nil then
  begin
    FUDPSock.CloseSocket;
    FUDPSock.Free;
    FUDPSock := nil;
  end;
  {$ENDIF}
end;

function TTcpip.ConnectServer(pszServerName: PChar; usPort: Word): Word;
{$IFNDEF MSDOS}
var
  LocalIP: String;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF MSDOS}
  { DOS: Would need Watt-32 library linked in.
    For now, check if packet driver is present and return 0 if not.
    When Watt-32 is integrated, this will call sock_init() + connect(). }
  if not TcpipAvailable then
    Exit;
  { TODO: Watt-32 connect implementation }
  fCarrierDown := 1;
  {$ELSE}
  FSock := TTCPBlockSocket.Create;
  FSock.CreateSocket;
  if FSock.LastError = 0 then
  begin
    FSock.Connect(StrPas(pszServerName), IntToStr(usPort));
    if FSock.LastError = 0 then
    begin
      FSock.NonBlockMode := True;

      { Get local IP for HostID }
      LocalIP := FSock.GetLocalSinIP;
      StrPCopy(HostIP, LocalIP);

      { Parse IP into HostID (network byte order) }
      HostID := synsock.inet_addr(PChar(LocalIP));

      Result := 1;
    end;
  end;

  if Result = 0 then
  begin
    fCarrierDown := 1;
    if FSock <> nil then
    begin
      FSock.Free;
      FSock := nil;
    end;
  end;
  {$ENDIF}
end;

function TTcpip.Initialize(usPort: Word; usSocket: Word; usProtocol: Word): Word;
{$IFNDEF MSDOS}
var
  LocalIP: String;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF MSDOS}
  { DOS: Would need Watt-32 library linked in.
    For now, check if packet driver is present and return 0 if not.
    When Watt-32 is integrated, this will call sock_init() + bind/listen. }
  if not TcpipAvailable then
    Exit;
  StrPCopy(HostIP, '127.0.0.1');
  HostID := $7F000001;
  { TODO: Watt-32 bind/listen implementation }
  {$ELSE}
  { Get local host IP via a temporary UDP socket trick }
  with TUDPBlockSocket.Create do
  try
    CreateSocket;
    Connect('8.8.8.8', '53');
    LocalIP := GetLocalSinIP;
    if (LocalIP = '') or (LocalIP = '0.0.0.0') then
      LocalIP := '127.0.0.1';
  finally
    Free;
  end;
  StrPCopy(HostIP, LocalIP);
  HostID := synsock.inet_addr(PChar(LocalIP));

  IsUDP := (usProtocol = PROTO_UDP);

  if usSocket = 0 then
  begin
    if IsUDP then
    begin
      { UDP mode }
      FUDPSock := TUDPBlockSocket.Create;
      FUDPSock.CreateSocket;
      if FUDPSock.LastError = 0 then
      begin
        FUDPSock.Bind('0.0.0.0', IntToStr(usPort));
        if FUDPSock.LastError = 0 then
        begin
          FUDPSock.NonBlockMode := True;
          Result := 1;
        end;
      end;
    end
    else
    begin
      { TCP server mode - create listening socket }
      FListenSock := TTCPBlockSocket.Create;
      FListenSock.CreateSocket;
      if FListenSock.LastError = 0 then
      begin
        FListenSock.Bind('0.0.0.0', IntToStr(usPort));
        if FListenSock.LastError = 0 then
        begin
          FListenSock.Listen;
          if FListenSock.LastError = 0 then
          begin
            FListenSock.NonBlockMode := True;
            Result := 1;
          end;
        end;
      end;
    end;
  end
  else
  begin
    { Use existing socket handle }
    FSock := TTCPBlockSocket.Create;
    FSock.Socket := usSocket;
    FSock.NonBlockMode := True;
    FSock.GetSins;
    Result := 1;
  end;
  {$ENDIF}
end;

function TTcpip.ReadByte: Byte;
{$IFNDEF MSDOS}
var
  i: LongInt;
{$ENDIF}
begin
  Result := 0;

  {$IFNDEF MSDOS}
  if FSock <> nil then
  begin
    while (RxBytes = 0) and (EndRun = 0) and (fCarrierDown = 0) do
    begin
      i := FSock.RecvBufferEx(@RxBuffer[0], ComBase.RSIZE, 100);
      if i = 0 then
        fCarrierDown := 1
      else if i < 0 then
      begin
        RxBytes := 0;
        if FSock.LastError <> WSAEWOULDBLOCK then
          fCarrierDown := 1;
      end
      else
      begin
        RxBytes := Word(i);
        RxPosition := 0;
      end;
    end;

    if (EndRun = 0) and (fCarrierDown = 0) and (RxBytes > 0) then
    begin
      Result := RxBuffer[RxPosition];
      Inc(RxPosition);
      Dec(RxBytes);
    end;
  end;
  {$ENDIF}
end;

function TTcpip.ReadBytes(ABytes: PByte; ALen: Word): Word;
{$IFNDEF MSDOS}
var
  i: LongInt;
{$ENDIF}
  Max: Word;
begin
  Max := 0;

  {$IFNDEF MSDOS}
  if FSock <> nil then
  begin
    while (RxBytes = 0) and (EndRun = 0) and (fCarrierDown = 0) do
    begin
      i := FSock.RecvBufferEx(@RxBuffer[0], ComBase.RSIZE, 100);
      if i = 0 then
        fCarrierDown := 1
      else if i < 0 then
      begin
        RxBytes := 0;
        if FSock.LastError <> WSAEWOULDBLOCK then
          fCarrierDown := 1;
      end
      else
      begin
        RxBytes := Word(i);
        RxPosition := 0;
      end;
    end;

    if (EndRun = 0) and (fCarrierDown = 0) and (RxBytes > 0) then
    begin
      Max := ALen;
      if Max > RxBytes then
        Max := RxBytes;
      Move(RxBuffer[RxPosition], ABytes^, Max);
      Dec(RxBytes, Max);
      Inc(RxPosition, Max);
    end;
  end;
  {$ENDIF}

  Result := Max;
end;

function TTcpip.PeekPacket(lpBuffer: Pointer; usSize: Word): Word;
begin
  Result := 0;
  {$IFNDEF MSDOS}
  if FUDPSock <> nil then
  begin
    if FUDPSock.CanRead(0) then
    begin
      if FUDPSock.PeekBuffer(lpBuffer, usSize) > 0 then
        Result := 1;
    end;
  end;
  {$ENDIF}
end;

function TTcpip.GetPacket(lpBuffer: Pointer; usSize: Word): Word;
begin
  Result := 0;
  {$IFNDEF MSDOS}
  if FUDPSock <> nil then
  begin
    Result := Word(FUDPSock.RecvBuffer(lpBuffer, usSize));
  end;
  {$ENDIF}
end;

function TTcpip.SendPacket(lpBuffer: Pointer; usSize: Word): Word;
begin
  Result := 0;
  {$IFNDEF MSDOS}
  if FUDPSock <> nil then
  begin
    Result := Word(FUDPSock.SendBuffer(lpBuffer, usSize));
  end;
  {$ENDIF}
end;

function TTcpip.WaitClient: Word;
{$IFNDEF MSDOS}
var
  NewSock: TSocket;
  NewTCP: TTCPBlockSocket;
{$ENDIF}
begin
  Result := 0;

  {$IFNDEF MSDOS}
  if FListenSock <> nil then
  begin
    if FListenSock.CanRead(0) then
    begin
      NewSock := FListenSock.Accept;
      if FListenSock.LastError = 0 then
      begin
        { Close any previous connection }
        if FSock <> nil then
        begin
          FSock.CloseSocket;
          FSock.Free;
        end;

        FSock := TTCPBlockSocket.Create;
        FSock.Socket := NewSock;
        FSock.GetSins;
        FSock.NonBlockMode := True;

        { Get client info }
        StrPCopy(ClientIP, FSock.GetRemoteSinIP);
        StrCopy(ClientName, ClientIP);

        Result := Word(NewSock);
      end;
    end;
  end;
  {$ENDIF}
end;

procedure TTcpip.SendByte(AByte: Byte);
begin
  {$IFNDEF MSDOS}
  if (FSock <> nil) and (fCarrierDown = 0) and (EndRun = 0) then
    FSock.SendByte(AByte);
  {$ENDIF}
end;

procedure TTcpip.SendBytes(ABytes: PByte; ALen: Word);
{$IFNDEF MSDOS}
var
  i: LongInt;
{$ENDIF}
begin
  {$IFNDEF MSDOS}
  if (FSock <> nil) and (fCarrierDown = 0) and (EndRun = 0) then
  begin
    repeat
      i := FSock.SendBuffer(ABytes, ALen);
      if i > 0 then
      begin
        Dec(ALen, Word(i));
        Inc(ABytes, i);
      end
      else if i < 0 then
      begin
        if FSock.LastError <> WSAEWOULDBLOCK then
          fCarrierDown := 1;
      end;
    until (ALen = 0) or (EndRun <> 0) or (Carrier = 0);
  end;
  {$ENDIF}
end;

procedure TTcpip.UnbufferBytes;
{$IFNDEF MSDOS}
var
  Written: LongInt;
  p: PByte;
{$ENDIF}
begin
  {$IFNDEF MSDOS}
  if (FSock <> nil) and (fCarrierDown = 0) and (EndRun = 0) and (TxBytes > 0) then
  begin
    { Set blocking mode for reliable flush }
    FSock.NonBlockMode := False;

    p := @TxBuffer[0];
    repeat
      Written := FSock.SendBuffer(p, TxBytes);
      if Written > 0 then
      begin
        Inc(p, Written);
        Dec(TxBytes, Word(Written));
      end
      else if Written < 0 then
      begin
        if FSock.LastError <> WSAEWOULDBLOCK then
          fCarrierDown := 1;
      end;
    until (TxBytes = 0) or (EndRun <> 0) or (Carrier = 0);

    { Restore non-blocking mode }
    FSock.NonBlockMode := True;
  end;
  {$ENDIF}
end;

procedure TTcpip.SetName(AName: PChar);
begin
end;

procedure TTcpip.SetCity(AName: PChar);
begin
end;

procedure TTcpip.SetLevel(ALevel: PChar);
begin
end;

procedure TTcpip.SetTimeLeft(ASeconds: LongWord);
begin
end;

procedure TTcpip.SetTime(ASeconds: LongWord);
begin
end;

end.
