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

  FreePascal conversion of npipe.cpp - TPipe class
  Inter-node IPC communication:
    - Windows: Named pipes (CreateNamedPipe/ConnectNamedPipe)
    - OS/2:    Named pipes (DosCreateNPipe/DosConnectNPipe)
    - Linux:   Unix domain sockets (equivalent functionality)
    - DOS:     Not supported (single-tasking OS, no IPC needed)
}

unit Npipe;

{$MODE OBJFPC}
{$H+}

{$IFNDEF MSDOS}
interface

uses
  SysUtils,
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF OS2}
  DosCalls, Os2Def,
  {$ENDIF}
  {$IFDEF UNIX}
  BaseUnix, Sockets, Unix,
  {$ENDIF}
  Defs, ComBase;

{$IFDEF UNIX}
const
  UNIX_SOCK_PATH_MAX = 108;
{$ENDIF}

type
  TPipe = class(TCom)
  public
    PipeName: array[0..63] of Char;
    PipeCity: array[0..63] of Char;
    PipeLevel: array[0..63] of Char;
    TimeLeft: LongWord;
    Time_:    LongWord;

    constructor Create; override;
    destructor Destroy; override;

    function  BytesReady: Word; override;
    procedure BufferByte(AByte: Byte); override;
    procedure BufferBytes(ABytes: PByte; ALen: Word); override;
    function  Carrier: Word; override;
    procedure ClearOutbound; override;
    procedure ClearInbound; override;
    function  Initialize(pszPipeName: PChar; pszCtlName: PChar; usInstances: Word): Word;
    function  ConnectServer(pszPipeName: PChar; pszCtlName: PChar): Word;
    function  ReadByte: Byte; override;
    function  ReadBytes(ABytes: PByte; ALen: Word): Word; override;
    procedure SendByte(AByte: Byte); override;
    procedure SendBytes(ABytes: PByte; ALen: Word); override;
    procedure UnbufferBytes; override;
    function  WaitClient: Word;

    procedure SetName(AName: PChar); override;
    procedure SetCity(AName: PChar); override;
    procedure SetLevel(ALevel: PChar); override;
    procedure SetTimeLeft(ASeconds: LongWord); override;
    procedure SetTime(ASeconds: LongWord); override;

  private
    CtlConnect:  Word;
    PipeConnect: Word;
    {$IFDEF WINDOWS}
    hFile:    THandle;
    hFileCtl: THandle;
    {$ENDIF}
    {$IFDEF OS2}
    hFile:    HFILE;
    hFileCtl: HFILE;
    {$ENDIF}
    {$IFDEF UNIX}
    hFile:    LongInt;       { Data socket (accepted client or connected) }
    hFileCtl: LongInt;       { Control socket (accepted client or connected) }
    hListen:  LongInt;       { Listening socket for data pipe }
    hListenCtl: LongInt;     { Listening socket for control pipe }
    szPipePath: array[0..UNIX_SOCK_PATH_MAX-1] of Char;
    szCtlPath:  array[0..UNIX_SOCK_PATH_MAX-1] of Char;
    {$ENDIF}
  end;

implementation

{$IFDEF UNIX}
type
  sockaddr_un = record
    sun_family: sa_family_t;
    sun_path: array[0..UNIX_SOCK_PATH_MAX-1] of Char;
  end;

function TranslatePipePath(pszName: PChar; out UnixPath: String): Boolean;
var
  s: String;
begin
  { Convert Windows/OS2 pipe names like \\.\pipe\lorabbs\1
    to Unix socket paths like /tmp/lorabbs_pipe_1 }
  s := StrPas(pszName);
  { Strip leading \\. or \\.\ prefix }
  if Copy(s, 1, 3) = '\\.' then
    Delete(s, 1, 3);
  if (Length(s) > 0) and (s[1] = '\') then
    Delete(s, 1, 1);
  { Replace backslashes with underscores }
  s := StringReplace(s, '\', '_', [rfReplaceAll]);
  { Replace forward slashes with underscores }
  s := StringReplace(s, '/', '_', [rfReplaceAll]);
  { Place in /tmp }
  UnixPath := '/tmp/lora_' + s;
  Result := Length(UnixPath) < UNIX_SOCK_PATH_MAX;
end;

function CreateUnixSocket(const APath: String; out LSock: LongInt): LongInt;
var
  addr: sockaddr_un;
begin
  Result := -1;
  LSock := -1;

  { Remove stale socket file if it exists }
  FpUnlink(PChar(APath));

  LSock := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  if LSock < 0 then
    Exit;

  FillChar(addr, SizeOf(addr), 0);
  addr.sun_family := AF_UNIX;
  StrPLCopy(addr.sun_path, APath, UNIX_SOCK_PATH_MAX - 1);

  if fpBind(LSock, @addr, SizeOf(addr)) <> 0 then
  begin
    FpClose(LSock);
    LSock := -1;
    Exit;
  end;

  if fpListen(LSock, 1) <> 0 then
  begin
    FpClose(LSock);
    LSock := -1;
    Exit;
  end;

  { Set non-blocking }
  FpFcntl(LSock, F_SETFL, FpFcntl(LSock, F_GETFL, 0) or O_NONBLOCK);
  Result := LSock;
end;

function ConnectUnixSocket(const APath: String): LongInt;
var
  addr: sockaddr_un;
  sock: LongInt;
begin
  Result := -1;

  sock := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  if sock < 0 then
    Exit;

  FillChar(addr, SizeOf(addr), 0);
  addr.sun_family := AF_UNIX;
  StrPLCopy(addr.sun_path, APath, UNIX_SOCK_PATH_MAX - 1);

  if fpConnect(sock, @addr, SizeOf(addr)) <> 0 then
  begin
    FpClose(sock);
    Exit;
  end;

  { Set non-blocking }
  FpFcntl(sock, F_SETFL, FpFcntl(sock, F_GETFL, 0) or O_NONBLOCK);
  Result := sock;
end;
{$ENDIF}

constructor TPipe.Create;
begin
  inherited Create;
  EndRun := 0;
  TxBytes := 0;
  CtlConnect := 0;
  PipeConnect := 0;
  {$IFDEF WINDOWS}
  hFile := INVALID_HANDLE_VALUE;
  hFileCtl := INVALID_HANDLE_VALUE;
  {$ENDIF}
  {$IFDEF OS2}
  hFile := 0;
  hFileCtl := 0;
  {$ENDIF}
  {$IFDEF UNIX}
  hFile := -1;
  hFileCtl := -1;
  hListen := -1;
  hListenCtl := -1;
  szPipePath[0] := #0;
  szCtlPath[0] := #0;
  {$ENDIF}
end;

destructor TPipe.Destroy;
begin
  PipeName[0] := #0;
  PipeCity[0] := #0;
  PipeLevel[0] := #0;
  TimeLeft := 0;
  Time_ := 0;

  {$IFDEF WINDOWS}
  if hFileCtl <> INVALID_HANDLE_VALUE then
    CloseHandle(hFileCtl);
  if hFile <> INVALID_HANDLE_VALUE then
    CloseHandle(hFile);
  {$ENDIF}
  {$IFDEF OS2}
  if hFileCtl <> 0 then
  begin
    DosDisConnectNPipe(hFileCtl);
    DosClose(hFileCtl);
  end;
  if hFile <> 0 then
  begin
    DosDisConnectNPipe(hFile);
    DosClose(hFile);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if hFileCtl >= 0 then
    FpClose(hFileCtl);
  if hFile >= 0 then
    FpClose(hFile);
  if hListenCtl >= 0 then
    FpClose(hListenCtl);
  if hListen >= 0 then
    FpClose(hListen);
  { Clean up socket files }
  if szPipePath[0] <> #0 then
    FpUnlink(@szPipePath[0]);
  if szCtlPath[0] <> #0 then
    FpUnlink(@szCtlPath[0]);
  {$ENDIF}
  inherited Destroy;
end;

procedure TPipe.BufferByte(AByte: Byte);
begin
  TxBuffer[TxBytes] := AByte;
  Inc(TxBytes);
  if TxBytes >= ComBase.TSIZE then
    UnbufferBytes;
end;

procedure TPipe.BufferBytes(ABytes: PByte; ALen: Word);
begin
  while (ALen > 0) and (EndRun = 0) do
  begin
    TxBuffer[TxBytes] := ABytes^;
    Inc(ABytes);
    Inc(TxBytes);
    if TxBytes >= ComBase.TSIZE then
      UnbufferBytes;
    Dec(ALen);
  end;
end;

function TPipe.BytesReady: Word;
{$IFDEF WINDOWS}
var
  Available: DWORD;
{$ENDIF}
{$IFDEF OS2}
var
  c: Char;
  p: PChar;
  data, Temp, pipeState: ULONG;
  Available: AVAILDATA;
{$ENDIF}
{$IFDEF UNIX}
var
  c: Byte;
  p: PChar;
  data: LongInt;
  fds: TFDSet;
  tv: TTimeVal;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF WINDOWS}
  if hFile <> INVALID_HANDLE_VALUE then
  begin
    EndRun := 0;
    Available := 0;
    if not PeekNamedPipe(hFile, nil, 0, nil, @Available, nil) then
      EndRun := 1;
    if Available > 0 then
      Result := 1;
  end;

  if Result = 0 then
    Sleep(1);
  {$ENDIF}

  {$IFDEF OS2}
  if hFile <> 0 then
  begin
    data := 0;
    DosPeekNPipe(hFile, @Temp, SizeOf(Temp), @data, @Available, @pipeState);
    if data > 0 then
      Result := 1;
    EndRun := 0;
    if pipeState = NP_STATE_CLOSING then
      EndRun := 1;
  end;

  if hFileCtl <> 0 then
  begin
    data := 0;
    DosPeekNPipe(hFileCtl, @Temp, SizeOf(Temp), @data, @Available, @pipeState);
    if data >= 2 then
    begin
      c := #0;
      DosRead(hFileCtl, @c, 1, @data);
      case Byte(c) of
        1: begin
          p := @PipeName[0];
          repeat
            c := #0;
            DosRead(hFileCtl, @c, 1, @data);
            p^ := c;
            Inc(p);
          until c = #0;
        end;
        2: begin
          p := @PipeCity[0];
          repeat
            c := #0;
            DosRead(hFileCtl, @c, 1, @data);
            p^ := c;
            Inc(p);
          until c = #0;
        end;
        3: begin
          p := @PipeLevel[0];
          repeat
            c := #0;
            DosRead(hFileCtl, @c, 1, @data);
            p^ := c;
            Inc(p);
          until c = #0;
        end;
        4: DosRead(hFileCtl, @TimeLeft, SizeOf(LongWord), @data);
        5: DosRead(hFileCtl, @Time_, SizeOf(LongWord), @data);
      end;
    end;
  end;

  if Result = 0 then
    DosSleep(1);
  {$ENDIF}

  {$IFDEF UNIX}
  if hFile >= 0 then
  begin
    EndRun := 0;
    fpFD_ZERO(fds);
    fpFD_SET(hFile, fds);
    tv.tv_sec := 0;
    tv.tv_usec := 0;
    if fpSelect(hFile + 1, @fds, nil, nil, @tv) > 0 then
    begin
      { Check if peer disconnected }
      data := FpRead(hFile, @c, 1);
      if data = 0 then
        EndRun := 1   { Peer closed connection }
      else if data > 0 then
      begin
        { Push byte back - store in rx buffer }
        RxBuffer[0] := c;
        RxBytes := 1;
        NextByte := @RxBuffer[0];
        Result := 1;
      end;
    end;
  end;

  { Check control socket for metadata }
  if hFileCtl >= 0 then
  begin
    fpFD_ZERO(fds);
    fpFD_SET(hFileCtl, fds);
    tv.tv_sec := 0;
    tv.tv_usec := 0;
    if fpSelect(hFileCtl + 1, @fds, nil, nil, @tv) > 0 then
    begin
      c := 0;
      data := FpRead(hFileCtl, @c, 1);
      if data > 0 then
      begin
        case c of
          1: begin
            p := @PipeName[0];
            repeat
              c := 0;
              data := FpRead(hFileCtl, @c, 1);
              if data > 0 then
              begin
                p^ := Char(c);
                Inc(p);
              end;
            until (c = 0) or (data <= 0);
          end;
          2: begin
            p := @PipeCity[0];
            repeat
              c := 0;
              data := FpRead(hFileCtl, @c, 1);
              if data > 0 then
              begin
                p^ := Char(c);
                Inc(p);
              end;
            until (c = 0) or (data <= 0);
          end;
          3: begin
            p := @PipeLevel[0];
            repeat
              c := 0;
              data := FpRead(hFileCtl, @c, 1);
              if data > 0 then
              begin
                p^ := Char(c);
                Inc(p);
              end;
            until (c = 0) or (data <= 0);
          end;
          4: FpRead(hFileCtl, @TimeLeft, SizeOf(LongWord));
          5: FpRead(hFileCtl, @Time_, SizeOf(LongWord));
        end;
      end;
    end;
  end;

  if Result = 0 then
    fpNanoSleep(@tv, nil);  { Brief yield }
  {$ENDIF}
end;

function TPipe.Carrier: Word;
{$IFDEF WINDOWS}
var
  Available: DWORD;
{$ENDIF}
{$IFDEF OS2}
var
  data, Temp, pipeState: ULONG;
  Available: AVAILDATA;
{$ENDIF}
{$IFDEF UNIX}
var
  fds: TFDSet;
  tv: TTimeVal;
  buf: Byte;
  n: LongInt;
{$ENDIF}
begin
  Result := 1;

  {$IFDEF WINDOWS}
  Available := 0;
  if hFileCtl <> INVALID_HANDLE_VALUE then
  begin
    if not PeekNamedPipe(hFileCtl, nil, 0, nil, @Available, nil) then
      Result := 0;
  end;
  if hFile <> INVALID_HANDLE_VALUE then
  begin
    if not PeekNamedPipe(hFile, nil, 0, nil, @Available, nil) then
      Result := 0;
  end;
  {$ENDIF}

  {$IFDEF OS2}
  if hFileCtl <> 0 then
  begin
    data := 0;
    DosPeekNPipe(hFileCtl, @Temp, SizeOf(Temp), @data, @Available, @pipeState);
    if pipeState = NP_STATE_CLOSING then
      Result := 0;
  end;
  if hFile <> 0 then
  begin
    data := 0;
    DosPeekNPipe(hFile, @Temp, SizeOf(Temp), @data, @Available, @pipeState);
    if pipeState = NP_STATE_CLOSING then
      Result := 0;
  end;
  {$ENDIF}

  {$IFDEF UNIX}
  if hFile >= 0 then
  begin
    { Use recv with MSG_PEEK | MSG_DONTWAIT to check if peer is still connected }
    n := fpRecv(hFile, @buf, 1, MSG_PEEK or MSG_DONTWAIT);
    if n = 0 then
      Result := 0;  { Peer closed connection }
  end;
  {$ENDIF}
end;

procedure TPipe.ClearInbound;
begin
  {$IFDEF UNIX}
  RxBytes := 0;
  {$ENDIF}
end;

procedure TPipe.ClearOutbound;
begin
  TxBytes := 0;
end;

function TPipe.Initialize(pszPipeName: PChar; pszCtlName: PChar; usInstances: Word): Word;
var
  TempFile: array[0..127] of Char;
{$IFDEF UNIX}
  UnixPath: String;
{$ENDIF}
begin
  Result := 0;
  CtlConnect := 0;
  PipeConnect := 0;

  {$IFDEF WINDOWS}
  hFileCtl := INVALID_HANDLE_VALUE;
  if StrLComp(pszCtlName, '\\.', 3) <> 0 then
  begin
    StrFmt(TempFile, '\\.\%s', [pszCtlName]);
    pszCtlName := TempFile;
  end;
  hFileCtl := CreateNamedPipe(pszCtlName,
    PIPE_ACCESS_DUPLEX or FILE_FLAG_WRITE_THROUGH,
    PIPE_TYPE_BYTE or PIPE_READMODE_BYTE or PIPE_NOWAIT,
    usInstances, ComBase.TSIZE * 2, ComBase.RSIZE, 1000, nil);

  hFile := INVALID_HANDLE_VALUE;
  if StrLComp(pszPipeName, '\\.', 3) <> 0 then
  begin
    StrFmt(TempFile, '\\.\%s', [pszPipeName]);
    pszPipeName := TempFile;
  end;
  hFile := CreateNamedPipe(pszPipeName,
    PIPE_ACCESS_DUPLEX or FILE_FLAG_WRITE_THROUGH,
    PIPE_TYPE_BYTE or PIPE_READMODE_BYTE or PIPE_NOWAIT,
    usInstances, ComBase.TSIZE * 2, ComBase.RSIZE, 1000, nil);
  if hFile <> INVALID_HANDLE_VALUE then
    Result := 1;
  {$ENDIF}

  {$IFDEF OS2}
  hFileCtl := 0;
  if StrLComp(pszCtlName, '\\.', 3) = 0 then
  begin
    StrCopy(TempFile, pszCtlName + 3);
    pszCtlName := TempFile;
  end;
  if DosCreateNPipe(pszCtlName, @hFileCtl, NP_ACCESS_DUPLEX,
    NP_NOWAIT or usInstances, ComBase.TSIZE, ComBase.RSIZE, 1000) <> 0 then
  begin
    hFileCtl := 0;
    CtlConnect := 1;
  end;

  hFile := 0;
  if StrLComp(pszPipeName, '\\.', 3) = 0 then
  begin
    StrCopy(TempFile, pszPipeName + 3);
    pszPipeName := TempFile;
  end;
  if DosCreateNPipe(pszPipeName, @hFile, NP_ACCESS_DUPLEX,
    NP_NOWAIT or usInstances, ComBase.TSIZE, ComBase.RSIZE, 1000) = 0 then
    Result := 1;
  {$ENDIF}

  {$IFDEF UNIX}
  { Create listening Unix domain sockets for both control and data pipes }
  hFileCtl := -1;
  hFile := -1;

  { Control socket }
  if TranslatePipePath(pszCtlName, UnixPath) then
  begin
    StrPLCopy(szCtlPath, UnixPath, SizeOf(szCtlPath) - 1);
    hListenCtl := -1;
    if CreateUnixSocket(UnixPath, hListenCtl) < 0 then
      CtlConnect := 1;
  end
  else
    CtlConnect := 1;

  { Data socket }
  if TranslatePipePath(pszPipeName, UnixPath) then
  begin
    StrPLCopy(szPipePath, UnixPath, SizeOf(szPipePath) - 1);
    hListen := -1;
    if CreateUnixSocket(UnixPath, hListen) >= 0 then
      Result := 1;
  end;
  {$ENDIF}
end;

function TPipe.ConnectServer(pszPipeName: PChar; pszCtlName: PChar): Word;
var
  TempFile: array[0..127] of Char;
{$IFDEF UNIX}
  UnixPath: String;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF WINDOWS}
  hFileCtl := INVALID_HANDLE_VALUE;
  if StrLComp(pszCtlName, '\\.', 3) <> 0 then
  begin
    StrFmt(TempFile, '\\.\%s', [pszCtlName]);
    pszCtlName := TempFile;
  end;
  hFileCtl := CreateFile(pszCtlName, GENERIC_READ or GENERIC_WRITE,
    0, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH, 0);

  hFile := INVALID_HANDLE_VALUE;
  if StrLComp(pszPipeName, '\\.', 3) <> 0 then
  begin
    StrFmt(TempFile, '\\.\%s', [pszPipeName]);
    pszPipeName := TempFile;
  end;
  hFile := CreateFile(pszPipeName, GENERIC_READ or GENERIC_WRITE,
    0, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH, 0);
  if hFile <> INVALID_HANDLE_VALUE then
    Result := 1;
  {$ENDIF}

  {$IFDEF OS2}
  var Action: ULONG;

  hFileCtl := 0;
  if StrLComp(pszCtlName, '\\.', 3) = 0 then
  begin
    StrCopy(TempFile, pszCtlName + 3);
    pszCtlName := TempFile;
  end;
  if DosOpen(pszCtlName, @hFileCtl, @Action, 0, FILE_NORMAL,
    FILE_OPEN, OPEN_ACCESS_READWRITE or OPEN_SHARE_DENYNONE, nil) <> 0 then
    hFileCtl := 0;

  hFile := 0;
  if StrLComp(pszPipeName, '\\.', 3) = 0 then
  begin
    StrCopy(TempFile, pszPipeName + 3);
    pszPipeName := TempFile;
  end;
  if DosOpen(pszPipeName, @hFile, @Action, 0, FILE_NORMAL,
    FILE_OPEN, OPEN_ACCESS_READWRITE or OPEN_SHARE_DENYNONE, nil) = 0 then
    Result := 1;
  {$ENDIF}

  {$IFDEF UNIX}
  { Connect to existing Unix domain sockets as client }
  hFileCtl := -1;
  if TranslatePipePath(pszCtlName, UnixPath) then
  begin
    StrPLCopy(szCtlPath, UnixPath, SizeOf(szCtlPath) - 1);
    hFileCtl := ConnectUnixSocket(UnixPath);
  end;

  hFile := -1;
  if TranslatePipePath(pszPipeName, UnixPath) then
  begin
    StrPLCopy(szPipePath, UnixPath, SizeOf(szPipePath) - 1);
    hFile := ConnectUnixSocket(UnixPath);
    if hFile >= 0 then
      Result := 1;
  end;
  {$ENDIF}
end;

function TPipe.ReadByte: Byte;
var
  c: Byte;
  bytesRead: {$IFDEF WINDOWS}DWORD{$ELSE}LongWord{$ENDIF};
begin
  c := 0;
  bytesRead := 0;

  {$IFDEF WINDOWS}
  if hFile <> INVALID_HANDLE_VALUE then
    ReadFile(hFile, c, 1, bytesRead, nil);
  {$ENDIF}
  {$IFDEF OS2}
  if hFile <> 0 then
    DosRead(hFile, @c, 1, @bytesRead);
  {$ENDIF}
  {$IFDEF UNIX}
  if hFile >= 0 then
  begin
    if RxBytes > 0 then
    begin
      c := NextByte^;
      Inc(NextByte);
      Dec(RxBytes);
      Result := c;
      Exit;
    end;
    bytesRead := FpRead(hFile, @c, 1);
  end;
  {$ENDIF}

  Result := c;
end;

function TPipe.ReadBytes(ABytes: PByte; ALen: Word): Word;
var
  bytesRead: {$IFDEF WINDOWS}DWORD{$ELSE}LongWord{$ENDIF};
begin
  bytesRead := 0;

  {$IFDEF WINDOWS}
  if hFile <> INVALID_HANDLE_VALUE then
    ReadFile(hFile, ABytes^, ALen, bytesRead, nil);
  {$ENDIF}
  {$IFDEF OS2}
  if hFile <> 0 then
    DosRead(hFile, ABytes, ALen, @bytesRead);
  {$ENDIF}
  {$IFDEF UNIX}
  if hFile >= 0 then
  begin
    { First drain any bytes from RxBuffer (from BytesReady peek) }
    if RxBytes > 0 then
    begin
      if ALen <= RxBytes then
      begin
        Move(NextByte^, ABytes^, ALen);
        Dec(RxBytes, ALen);
        Inc(NextByte, ALen);
        Result := ALen;
        Exit;
      end
      else
      begin
        Move(NextByte^, ABytes^, RxBytes);
        Inc(ABytes, RxBytes);
        Dec(ALen, RxBytes);
        bytesRead := RxBytes;
        RxBytes := 0;
      end;
    end;
    { Read remaining from socket }
    if ALen > 0 then
    begin
      var n: LongInt;
      n := FpRead(hFile, ABytes, ALen);
      if n > 0 then
        Inc(bytesRead, n);
    end;
  end;
  {$ENDIF}

  Result := Word(bytesRead);
end;

procedure TPipe.SendByte(AByte: Byte);
var
  written: {$IFDEF WINDOWS}DWORD{$ELSE}LongWord{$ENDIF};
begin
  {$IFDEF WINDOWS}
  if (hFile <> INVALID_HANDLE_VALUE) and (EndRun = 0) then
    repeat
      WriteFile(hFile, AByte, 1, written, nil);
    until written = 1;
  {$ENDIF}
  {$IFDEF OS2}
  if (hFile <> 0) and (EndRun = 0) then
  begin
    DosSetNPHState(hFile, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFile, @AByte, 1, @written);
    DosSetNPHState(hFile, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if (hFile >= 0) and (EndRun = 0) then
    FpWrite(hFile, @AByte, 1);
  {$ENDIF}
end;

procedure TPipe.SendBytes(ABytes: PByte; ALen: Word);
var
  written: {$IFDEF WINDOWS}DWORD{$ELSE}LongWord{$ENDIF};
begin
  {$IFDEF WINDOWS}
  if (hFile <> INVALID_HANDLE_VALUE) and (EndRun = 0) then
    repeat
      WriteFile(hFile, ABytes^, ALen, written, nil);
      Inc(ABytes, written);
      Dec(ALen, written);
    until (ALen = 0) or (EndRun <> 0);
  {$ENDIF}
  {$IFDEF OS2}
  if hFile <> 0 then
  begin
    DosSetNPHState(hFile, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFile, ABytes, ALen, @written);
    DosSetNPHState(hFile, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if (hFile >= 0) and (EndRun = 0) then
  begin
    while (ALen > 0) and (EndRun = 0) do
    begin
      written := FpWrite(hFile, ABytes, ALen);
      if written > 0 then
      begin
        Inc(ABytes, written);
        Dec(ALen, written);
      end;
    end;
  end;
  {$ENDIF}
end;

procedure TPipe.UnbufferBytes;
var
  Written: {$IFDEF WINDOWS}DWORD{$ELSE}LongWord{$ENDIF};
  {$IFDEF WINDOWS}
  p: PByte;
  {$ENDIF}
begin
  {$IFDEF WINDOWS}
  if (hFile <> INVALID_HANDLE_VALUE) and (TxBytes > 0) and (EndRun = 0) then
  begin
    p := @TxBuffer[0];
    repeat
      WriteFile(hFile, p^, TxBytes, Written, nil);
      Inc(p, Written);
      if Written < TxBytes then
        Sleep(10);
      Dec(TxBytes, Word(Written));
    until (TxBytes = 0) or (EndRun <> 0);
  end;
  {$ENDIF}
  {$IFDEF OS2}
  if (hFile <> 0) and (TxBytes > 0) and (EndRun = 0) then
  begin
    DosSetNPHState(hFile, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFile, @TxBuffer[0], TxBytes, @Written);
    TxBytes := 0;
    DosSetNPHState(hFile, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if (hFile >= 0) and (TxBytes > 0) and (EndRun = 0) then
  begin
    { Temporarily set blocking for reliable write }
    FpFcntl(hFile, F_SETFL, FpFcntl(hFile, F_GETFL, 0) and (not O_NONBLOCK));
    Written := FpWrite(hFile, @TxBuffer[0], TxBytes);
    TxBytes := 0;
    FpFcntl(hFile, F_SETFL, FpFcntl(hFile, F_GETFL, 0) or O_NONBLOCK);
  end;
  {$ENDIF}
end;

function TPipe.WaitClient: Word;
{$IFDEF UNIX}
var
  fds: TFDSet;
  tv: TTimeVal;
  addr: sockaddr_un;
  addrLen: TSockLen;
  newSock: LongInt;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF WINDOWS}
  if hFileCtl <> INVALID_HANDLE_VALUE then
    ConnectNamedPipe(hFileCtl, nil);
  ConnectNamedPipe(hFile, nil);
  if GetLastError = ERROR_PIPE_CONNECTED then
    Result := 1;
  {$ENDIF}

  {$IFDEF OS2}
  if (hFileCtl <> 0) and (CtlConnect = 0) then
  begin
    if DosConnectNPipe(hFileCtl) = 0 then
      CtlConnect := 1;
  end;
  if (hFile <> 0) and (PipeConnect = 0) then
  begin
    if DosConnectNPipe(hFile) = 0 then
      PipeConnect := 1;
  end;
  if (CtlConnect <> 0) and (PipeConnect <> 0) then
    Result := 1;
  {$ENDIF}

  {$IFDEF UNIX}
  { Non-blocking accept on listening sockets }
  if (hListenCtl >= 0) and (CtlConnect = 0) then
  begin
    fpFD_ZERO(fds);
    fpFD_SET(hListenCtl, fds);
    tv.tv_sec := 0;
    tv.tv_usec := 0;
    if fpSelect(hListenCtl + 1, @fds, nil, nil, @tv) > 0 then
    begin
      addrLen := SizeOf(addr);
      newSock := fpAccept(hListenCtl, @addr, @addrLen);
      if newSock >= 0 then
      begin
        hFileCtl := newSock;
        FpFcntl(hFileCtl, F_SETFL, FpFcntl(hFileCtl, F_GETFL, 0) or O_NONBLOCK);
        CtlConnect := 1;
      end;
    end;
  end;

  if (hListen >= 0) and (PipeConnect = 0) then
  begin
    fpFD_ZERO(fds);
    fpFD_SET(hListen, fds);
    tv.tv_sec := 0;
    tv.tv_usec := 0;
    if fpSelect(hListen + 1, @fds, nil, nil, @tv) > 0 then
    begin
      addrLen := SizeOf(addr);
      newSock := fpAccept(hListen, @addr, @addrLen);
      if newSock >= 0 then
      begin
        hFile := newSock;
        FpFcntl(hFile, F_SETFL, FpFcntl(hFile, F_GETFL, 0) or O_NONBLOCK);
        PipeConnect := 1;
      end;
    end;
  end;

  if (CtlConnect <> 0) and (PipeConnect <> 0) then
    Result := 1;
  {$ENDIF}
end;

procedure TPipe.SetName(AName: PChar);
var
  written: LongWord;
  tag: Byte;
begin
  {$IFDEF OS2}
  if hFileCtl <> 0 then
  begin
    DosSetNPHState(hFileCtl, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFileCtl, PChar(#$01), 1, @written);
    DosWrite(hFileCtl, AName, StrLen(AName) + 1, @written);
    DosSetNPHState(hFileCtl, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF WINDOWS}
  if hFileCtl <> INVALID_HANDLE_VALUE then
  begin
    tag := 1;
    WriteFile(hFileCtl, tag, 1, written, nil);
    WriteFile(hFileCtl, AName^, StrLen(AName) + 1, written, nil);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if hFileCtl >= 0 then
  begin
    tag := 1;
    FpWrite(hFileCtl, @tag, 1);
    FpWrite(hFileCtl, AName, StrLen(AName) + 1);
  end;
  {$ENDIF}
end;

procedure TPipe.SetCity(AName: PChar);
var
  written: LongWord;
  tag: Byte;
begin
  {$IFDEF OS2}
  if hFileCtl <> 0 then
  begin
    DosSetNPHState(hFileCtl, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFileCtl, PChar(#$02), 1, @written);
    DosWrite(hFileCtl, AName, StrLen(AName) + 1, @written);
    DosSetNPHState(hFileCtl, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF WINDOWS}
  if hFileCtl <> INVALID_HANDLE_VALUE then
  begin
    tag := 2;
    WriteFile(hFileCtl, tag, 1, written, nil);
    WriteFile(hFileCtl, AName^, StrLen(AName) + 1, written, nil);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if hFileCtl >= 0 then
  begin
    tag := 2;
    FpWrite(hFileCtl, @tag, 1);
    FpWrite(hFileCtl, AName, StrLen(AName) + 1);
  end;
  {$ENDIF}
end;

procedure TPipe.SetLevel(ALevel: PChar);
var
  written: LongWord;
  tag: Byte;
begin
  {$IFDEF OS2}
  if hFileCtl <> 0 then
  begin
    DosSetNPHState(hFileCtl, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFileCtl, PChar(#$03), 1, @written);
    DosWrite(hFileCtl, ALevel, StrLen(ALevel) + 1, @written);
    DosSetNPHState(hFileCtl, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF WINDOWS}
  if hFileCtl <> INVALID_HANDLE_VALUE then
  begin
    tag := 3;
    WriteFile(hFileCtl, tag, 1, written, nil);
    WriteFile(hFileCtl, ALevel^, StrLen(ALevel) + 1, written, nil);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if hFileCtl >= 0 then
  begin
    tag := 3;
    FpWrite(hFileCtl, @tag, 1);
    FpWrite(hFileCtl, ALevel, StrLen(ALevel) + 1);
  end;
  {$ENDIF}
end;

procedure TPipe.SetTimeLeft(ASeconds: LongWord);
var
  written: LongWord;
  tag: Byte;
begin
  {$IFDEF OS2}
  if hFileCtl <> 0 then
  begin
    DosSetNPHState(hFileCtl, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFileCtl, PChar(#$04), 1, @written);
    DosWrite(hFileCtl, @ASeconds, SizeOf(LongWord), @written);
    DosSetNPHState(hFileCtl, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF WINDOWS}
  if hFileCtl <> INVALID_HANDLE_VALUE then
  begin
    tag := 4;
    WriteFile(hFileCtl, tag, 1, written, nil);
    WriteFile(hFileCtl, ASeconds, SizeOf(LongWord), written, nil);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if hFileCtl >= 0 then
  begin
    tag := 4;
    FpWrite(hFileCtl, @tag, 1);
    FpWrite(hFileCtl, @ASeconds, SizeOf(LongWord));
  end;
  {$ENDIF}
end;

procedure TPipe.SetTime(ASeconds: LongWord);
var
  written: LongWord;
  tag: Byte;
begin
  {$IFDEF OS2}
  if hFileCtl <> 0 then
  begin
    DosSetNPHState(hFileCtl, NP_WAIT or NP_READMODE_BYTE);
    DosWrite(hFileCtl, PChar(#$05), 1, @written);
    DosWrite(hFileCtl, @ASeconds, SizeOf(LongWord), @written);
    DosSetNPHState(hFileCtl, NP_NOWAIT or NP_READMODE_BYTE);
  end;
  {$ENDIF}
  {$IFDEF WINDOWS}
  if hFileCtl <> INVALID_HANDLE_VALUE then
  begin
    tag := 5;
    WriteFile(hFileCtl, tag, 1, written, nil);
    WriteFile(hFileCtl, ASeconds, SizeOf(LongWord), written, nil);
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  if hFileCtl >= 0 then
  begin
    tag := 5;
    FpWrite(hFileCtl, @tag, 1);
    FpWrite(hFileCtl, @ASeconds, SizeOf(LongWord));
  end;
  {$ENDIF}
end;

{$ELSE}
{ DOS - No IPC support (single-tasking OS) }
interface
implementation
{$ENDIF}

end.
