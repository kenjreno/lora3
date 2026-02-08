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
  Named pipe communication for OS/2 and Windows NT.
  Uses platform IFDEFs for OS/2 and Windows API calls.
}

unit LoraNpipe;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils,
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF OS2}
  DosCalls, Os2Def,
  {$ENDIF}
  LoraDefs, LoraComBase;

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
  end;

implementation

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
  inherited Destroy;
end;

procedure TPipe.BufferByte(AByte: Byte);
begin
  TxBuffer[TxBytes] := AByte;
  Inc(TxBytes);
  if TxBytes >= TSIZE then
    UnbufferBytes;
end;

procedure TPipe.BufferBytes(ABytes: PByte; ALen: Word);
begin
  while (ALen > 0) and (EndRun = 0) do
  begin
    TxBuffer[TxBytes] := ABytes^;
    Inc(ABytes);
    Inc(TxBytes);
    if TxBytes >= TSIZE then
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
end;

procedure TPipe.ClearInbound;
begin
end;

procedure TPipe.ClearOutbound;
begin
  TxBytes := 0;
end;

function TPipe.Initialize(pszPipeName: PChar; pszCtlName: PChar; usInstances: Word): Word;
var
  TempFile: array[0..127] of Char;
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
    usInstances, TSIZE * 2, RSIZE, 1000, nil);

  hFile := INVALID_HANDLE_VALUE;
  if StrLComp(pszPipeName, '\\.', 3) <> 0 then
  begin
    StrFmt(TempFile, '\\.\%s', [pszPipeName]);
    pszPipeName := TempFile;
  end;
  hFile := CreateNamedPipe(pszPipeName,
    PIPE_ACCESS_DUPLEX or FILE_FLAG_WRITE_THROUGH,
    PIPE_TYPE_BYTE or PIPE_READMODE_BYTE or PIPE_NOWAIT,
    usInstances, TSIZE * 2, RSIZE, 1000, nil);
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
    NP_NOWAIT or usInstances, TSIZE, RSIZE, 1000) <> 0 then
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
    NP_NOWAIT or usInstances, TSIZE, RSIZE, 1000) = 0 then
    Result := 1;
  {$ENDIF}
end;

function TPipe.ConnectServer(pszPipeName: PChar; pszCtlName: PChar): Word;
var
  TempFile: array[0..127] of Char;
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
end;

function TPipe.WaitClient: Word;
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
end;

procedure TPipe.SetName(AName: PChar);
{$IFDEF OS2}
var
  written: LongWord;
{$ENDIF}
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
end;

procedure TPipe.SetCity(AName: PChar);
{$IFDEF OS2}
var
  written: LongWord;
{$ENDIF}
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
end;

procedure TPipe.SetLevel(ALevel: PChar);
{$IFDEF OS2}
var
  written: LongWord;
{$ENDIF}
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
end;

procedure TPipe.SetTimeLeft(ASeconds: LongWord);
{$IFDEF OS2}
var
  written: LongWord;
{$ENDIF}
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
end;

procedure TPipe.SetTime(ASeconds: LongWord);
{$IFDEF OS2}
var
  written: LongWord;
{$ENDIF}
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
end;

end.
