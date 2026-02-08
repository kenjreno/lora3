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
  Uses Synapse synaser for cross-platform serial (Windows/Linux/OS2).
  DOS uses FOSSIL driver via INT 14h.
}

unit Serial;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils,
  {$IFDEF MSDOS}
  Dos,
  {$ELSE}
  synaser,
  {$ENDIF}
  Defs, ComBase;

{$IFDEF MSDOS}
const
  { FOSSIL INT 14h function codes }
  FOSSIL_SETBAUD    = $00;
  FOSSIL_TXCHAR     = $01;
  FOSSIL_RXCHAR     = $02;
  FOSSIL_STATUS     = $03;
  FOSSIL_INIT       = $04;
  FOSSIL_DEINIT     = $05;
  FOSSIL_DTR        = $06;
  FOSSIL_PURGE_OUT  = $09;
  FOSSIL_PURGE_IN   = $0A;
  FOSSIL_BLOCKREAD  = $18;
  FOSSIL_BLOCKWRITE = $19;

  { FOSSIL status bits (AH register from STATUS call) }
  FOSSIL_RX_READY   = $01;  { Data ready in receive buffer }
  FOSSIL_TX_READY   = $20;  { Room in transmit buffer }
  FOSSIL_DCD_ON     = $80;  { Carrier detect }

  { FOSSIL baud rate encoding for AH=$00 }
  FOSSIL_BAUD_300   = $43;
  FOSSIL_BAUD_1200  = $83;
  FOSSIL_BAUD_2400  = $A3;
  FOSSIL_BAUD_4800  = $C3;
  FOSSIL_BAUD_9600  = $E3;
  FOSSIL_BAUD_19200 = $03;  { Extended: some FOSSILs }
  FOSSIL_BAUD_38400 = $23;  { Extended: some FOSSILs }
{$ENDIF}

type
  TSerial = class(TCom)
  public
    Device:   array[0..31] of Char;
    Speed:    LongWord;
    DataBits: Word;
    StopBits: Word;
    Parity:   Char;

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
    {$IFDEF MSDOS}
    FPort: Word;        { COM port number (0=COM1, 1=COM2, etc.) }
    FInitialized: Boolean;
    {$ELSE}
    FSer: TBlockSerial;
    {$ENDIF}
  end;

implementation

{$IFDEF MSDOS}
procedure FossilCall(AH_Func: Byte; DX_Port: Word; var Regs: Registers);
begin
  FillChar(Regs, SizeOf(Regs), 0);
  Regs.AH := AH_Func;
  Regs.DX := DX_Port;
  Intr($14, Regs);
end;
{$ENDIF}

constructor TSerial.Create;
begin
  inherited Create;
  {$IFDEF MSDOS}
  FPort := 1;  { COM2 default, same as original }
  FInitialized := False;
  {$ELSE}
  FSer := nil;
  {$ENDIF}
  {$IFDEF UNIX}
  StrPCopy(Device, '/dev/modem');
  {$ELSE}
  StrPCopy(Device, 'COM2');
  {$ENDIF}
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
  {$IFDEF MSDOS}
  if FInitialized then
  begin
    var Regs: Registers;
    FossilCall(FOSSIL_DEINIT, FPort, Regs);
    FInitialized := False;
  end;
  {$ELSE}
  if FSer <> nil then
  begin
    FSer.CloseSocket;
    FSer.Free;
    FSer := nil;
  end;
  {$ENDIF}
  inherited Destroy;
end;

procedure TSerial.BufferByte(AByte: Byte);
begin
  TxBuffer[TxBytes] := AByte;
  Inc(TxBytes);
  if TxBytes >= ComBase.TSIZE then
    UnbufferBytes;
end;

procedure TSerial.BufferBytes(ABytes: PByte; ALen: Word);
var
  ToCopy: Word;
begin
  if (ALen > 0) and (EndRun = 0) then
  begin
    repeat
      if TxBytes < ComBase.TSIZE then
      begin
        ToCopy := ALen;
        if ToCopy > ComBase.TSIZE - TxBytes then
          ToCopy := ComBase.TSIZE - TxBytes;
        Move(ABytes^, TxBuffer[TxBytes], ToCopy);
        Inc(ABytes, ToCopy);
        Inc(TxBytes, ToCopy);
        Dec(ALen, ToCopy);
      end;
      if TxBytes >= ComBase.TSIZE then
        UnbufferBytes;
    until (ALen = 0) or (EndRun <> 0);
  end;
end;

function TSerial.BytesReady: Word;
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ELSE}
var
  i: LongInt;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF MSDOS}
  if FInitialized then
  begin
    if RxBytes > 0 then
      Result := 1
    else
    begin
      FossilCall(FOSSIL_STATUS, FPort, Regs);
      if (Regs.AH and FOSSIL_RX_READY) <> 0 then
        Result := 1;
    end;
  end;
  {$ELSE}
  if FSer <> nil then
  begin
    if RxBytes > 0 then
      Result := 1
    else
    begin
      if FSer.CanRead(0) then
      begin
        i := FSer.RecvBufferEx(@RxBuffer[0], ComBase.RSIZE, 0);
        if i > 0 then
        begin
          RxBytes := Word(i);
          NextByte := @RxBuffer[0];
          Result := 1;
        end;
      end;
    end;
  end;
  {$ENDIF}
end;

function TSerial.Carrier: Word;
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ENDIF}
begin
  {$IFDEF MSDOS}
  if FInitialized then
  begin
    FossilCall(FOSSIL_STATUS, FPort, Regs);
    if (Regs.AH and FOSSIL_DCD_ON) <> 0 then
      Result := 1
    else
      Result := 0;
  end
  else
    Result := 0;
  {$ELSE}
  if FSer <> nil then
  begin
    if FSer.DCD then
      Result := 1
    else
      Result := 0;
  end
  else
    Result := 0;
  {$ENDIF}
end;

procedure TSerial.ClearInbound;
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ENDIF}
begin
  RxBytes := 0;
  {$IFDEF MSDOS}
  if FInitialized then
    FossilCall(FOSSIL_PURGE_IN, FPort, Regs);
  {$ELSE}
  if FSer <> nil then
    FSer.Purge;
  {$ENDIF}
end;

procedure TSerial.ClearOutbound;
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ENDIF}
begin
  TxBytes := 0;
  {$IFDEF MSDOS}
  if FInitialized then
    FossilCall(FOSSIL_PURGE_OUT, FPort, Regs);
  {$ELSE}
  if FSer <> nil then
    FSer.Purge;
  {$ENDIF}
end;

function TSerial.Initialize: Word;
{$IFDEF MSDOS}
var
  Regs: Registers;
  PortStr: String;
{$ELSE}
var
  ParityChar: Char;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF MSDOS}
  { Parse COM port number from Device field }
  PortStr := UpCase(StrPas(Device));
  if (Length(PortStr) >= 4) and (Copy(PortStr, 1, 3) = 'COM') then
    FPort := Ord(PortStr[4]) - Ord('1')
  else
    FPort := 1;  { Default COM2 }

  { Initialize FOSSIL driver }
  FossilCall(FOSSIL_INIT, FPort, Regs);
  if Regs.AX = $1954 then  { FOSSIL signature }
  begin
    FInitialized := True;
    SetParameters(Speed, DataBits, Byte(Parity), StopBits);
    Result := 1;
  end;
  {$ELSE}
  FSer := TBlockSerial.Create;
  FSer.Connect(StrPas(Device));
  if FSer.LastError = 0 then
  begin
    { Map parity character }
    ParityChar := Parity;
    if ParityChar = #0 then
      ParityChar := 'N';

    FSer.Config(Speed, DataBits, ParityChar, SB1, False, True);
    if FSer.LastError = 0 then
    begin
      FSer.DTR := True;
      FSer.RTS := True;
      Result := 1;
    end;
  end;

  if (Result = 0) and (FSer <> nil) then
  begin
    FSer.Free;
    FSer := nil;
  end;
  {$ENDIF}
end;

function TSerial.ReadByte: Byte;
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ELSE}
var
  i: LongInt;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF MSDOS}
  if FInitialized then
  begin
    if RxBytes = 0 then
    begin
      repeat
        FossilCall(FOSSIL_STATUS, FPort, Regs);
        if (Regs.AH and FOSSIL_RX_READY) <> 0 then
        begin
          FossilCall(FOSSIL_RXCHAR, FPort, Regs);
          RxBuffer[0] := Regs.AL;
          RxBytes := 1;
          NextByte := @RxBuffer[0];
        end;
      until (RxBytes > 0) or (EndRun <> 0);
    end;
  end;
  {$ELSE}
  if FSer <> nil then
  begin
    if RxBytes = 0 then
    begin
      repeat
        i := FSer.RecvBufferEx(@RxBuffer[0], ComBase.RSIZE, 100);
        if i > 0 then
        begin
          RxBytes := Word(i);
          NextByte := @RxBuffer[0];
        end;
      until (RxBytes > 0) or (EndRun <> 0);
    end;
  end;
  {$ENDIF}

  if RxBytes > 0 then
  begin
    Result := NextByte^;
    Inc(NextByte);
    Dec(RxBytes);
  end;
end;

function TSerial.ReadBytes(ABytes: PByte; ALen: Word): Word;
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ELSE}
var
  i: LongInt;
{$ENDIF}
  Max: Word;
begin
  Max := 0;

  {$IFDEF MSDOS}
  if FInitialized then
  begin
    if RxBytes = 0 then
    begin
      repeat
        FossilCall(FOSSIL_STATUS, FPort, Regs);
        if (Regs.AH and FOSSIL_RX_READY) <> 0 then
        begin
          FossilCall(FOSSIL_RXCHAR, FPort, Regs);
          RxBuffer[0] := Regs.AL;
          RxBytes := 1;
          NextByte := @RxBuffer[0];
        end;
      until (RxBytes > 0) or (EndRun <> 0);
    end;
  end;
  {$ELSE}
  if FSer <> nil then
  begin
    if RxBytes = 0 then
    begin
      repeat
        i := FSer.RecvBufferEx(@RxBuffer[0], ComBase.RSIZE, 100);
        if i > 0 then
        begin
          RxBytes := Word(i);
          NextByte := @RxBuffer[0];
        end;
      until (RxBytes > 0) or (EndRun <> 0);
    end;
  end;
  {$ENDIF}

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
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ENDIF}
begin
  {$IFDEF MSDOS}
  if FInitialized then
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    Regs.AH := FOSSIL_DTR;
    Regs.AL := Byte(fStatus <> 0);
    Regs.DX := FPort;
    Intr($14, Regs);
  end;
  {$ELSE}
  if FSer <> nil then
    FSer.DTR := (fStatus <> 0);
  {$ENDIF}
end;

procedure TSerial.SetRTS(fStatus: Word);
begin
  {$IFNDEF MSDOS}
  if FSer <> nil then
    FSer.RTS := (fStatus <> 0);
  {$ENDIF}
  { FOSSIL doesn't have a standard RTS control function }
end;

procedure TSerial.SetParameters(ulSpeed: LongWord; nData: Word; nParity: Byte; nStop: Word);
{$IFDEF MSDOS}
var
  Regs: Registers;
  BaudCode: Byte;
{$ELSE}
var
  ParityChar: Char;
  StopBitsVal: Byte;
{$ENDIF}
begin
  {$IFDEF MSDOS}
  if FInitialized then
  begin
    { FOSSIL standard baud rate encoding in AL register }
    case ulSpeed of
      300:   BaudCode := FOSSIL_BAUD_300;
      1200:  BaudCode := FOSSIL_BAUD_1200;
      2400:  BaudCode := FOSSIL_BAUD_2400;
      4800:  BaudCode := FOSSIL_BAUD_4800;
      9600:  BaudCode := FOSSIL_BAUD_9600;
      19200: BaudCode := FOSSIL_BAUD_19200;
      38400: BaudCode := FOSSIL_BAUD_38400;
    else
      BaudCode := FOSSIL_BAUD_9600;
    end;

    { Encode data bits (bits 0-1): 00=5, 01=6, 10=7, 11=8 }
    BaudCode := (BaudCode and $FC) or (Byte(nData - 5) and $03);
    { Encode stop bits (bit 2): 0=1stop, 1=2stop }
    if nStop = 2 then
      BaudCode := BaudCode or $04;
    { Encode parity (bits 3-4): 00=none, 01=odd, 11=even }
    if Char(nParity) = 'O' then
      BaudCode := BaudCode or $08
    else if Char(nParity) = 'E' then
      BaudCode := BaudCode or $18;

    FillChar(Regs, SizeOf(Regs), 0);
    Regs.AH := FOSSIL_SETBAUD;
    Regs.AL := BaudCode;
    Regs.DX := FPort;
    Intr($14, Regs);
  end;
  {$ELSE}
  if FSer <> nil then
  begin
    ParityChar := Char(nParity);
    if ParityChar = #0 then
      ParityChar := 'N';
    if nStop = 2 then
      StopBitsVal := SB2
    else
      StopBitsVal := SB1;
    FSer.Config(ulSpeed, nData, ParityChar, StopBitsVal, False, True);
  end;
  {$ENDIF}
end;

procedure TSerial.SendByte(AByte: Byte);
{$IFDEF MSDOS}
var
  Regs: Registers;
{$ENDIF}
begin
  {$IFDEF MSDOS}
  if FInitialized and (EndRun = 0) then
  begin
    repeat
      FillChar(Regs, SizeOf(Regs), 0);
      Regs.AH := FOSSIL_TXCHAR;
      Regs.AL := AByte;
      Regs.DX := FPort;
      Intr($14, Regs);
    until (Regs.AX <> 0) or (EndRun <> 0) or (Carrier = 0);
  end;
  {$ELSE}
  if (FSer <> nil) and (EndRun = 0) then
    FSer.SendByte(LongInt(AByte));
  {$ENDIF}
end;

procedure TSerial.SendBytes(ABytes: PByte; ALen: Word);
begin
  {$IFDEF MSDOS}
  if FInitialized and (EndRun = 0) then
  begin
    while (ALen > 0) and (EndRun = 0) and (Carrier <> 0) do
    begin
      SendByte(ABytes^);
      Inc(ABytes);
      Dec(ALen);
    end;
  end;
  {$ELSE}
  if (FSer <> nil) and (EndRun = 0) then
    FSer.SendBuffer(ABytes, ALen);
  {$ENDIF}
end;

procedure TSerial.UnbufferBytes;
begin
  if (TxBytes > 0) and (EndRun = 0) then
  begin
    {$IFDEF MSDOS}
    SendBytes(@TxBuffer[0], TxBytes);
    TxBytes := 0;
    {$ELSE}
    if FSer <> nil then
    begin
      FSer.SendBuffer(@TxBuffer[0], TxBytes);
      TxBytes := 0;
    end;
    {$ENDIF}
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
