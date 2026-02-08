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
}

unit LoraTcpip;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, BaseUnix, Unix, Sockets,
  LoraDefs, LoraComBase;

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

implementation

uses
  Errors;

const
  FIONBIO = $5421;

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
      server.sin_addr.s_addr := 0;

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
  Written: LongInt;
  p: PByte;
  flag: LongInt;
begin
  while (Sock <> 0) and (fCarrierDown = 0) and (EndRun = 0) and (TxBytes > 0) do
  begin
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

    flag := 1;
    FpIOCtl(Sock, FIONBIO, @flag);
  end;
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
