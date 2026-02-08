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

  FreePascal conversion of screen.cpp - TScreen class
  Replaces CXL windowing with direct ANSI terminal output.
}

unit LoraScreen;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, BaseUnix,
  LoraDefs, LoraComBase;

type
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
  end;

implementation

constructor TScreen.Create;
begin
  inherited Create;
  AnsiState := #0;
  Prec := #0;
  Attr := BLACK or _LGREY;
  RxBytes := 0;
  RxPosition := 0;
  Counter := 0;
  Running := 0;
end;

destructor TScreen.Destroy;
begin
  Write(#27'[0m');
  Write(#27'[?25h');
  inherited Destroy;
end;

function TScreen.BytesReady: Word;
var
  c: Byte;
  i: LongInt;
begin
  Result := 0;

  i := FpRead(0, @c, 1);
  if i > 0 then
  begin
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
      if ((ch >= 'A') and (ch <= 'Z')) or ((ch >= 'a') and (ch <= 'z')) then
      begin
        case ch of
          'm': begin
            Write(#27'[');
            for i := 0 to Count do
            begin
              if i > 0 then Write(';');
              Write(Params[i]);
            end;
            Write('m');
          end;
          'A': begin
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'A');
          end;
          'B': begin
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'B');
          end;
          'C': begin
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'C');
          end;
          'D': begin
            if Params[0] = 0 then Params[0] := 1;
            Write(#27'[', Params[0], 'D');
          end;
          'n': begin
            if Params[0] = 6 then
            begin
              RxBuffer[RxBytes] := $1B; Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('['); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('0'); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte(';'); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('0'); Inc(RxBytes);
              RxBuffer[RxBytes] := Byte('h'); Inc(RxBytes);
              RxPosition := 0;
            end;
          end;
          'f', 'H': begin
            Write(#27'[', Params[0], ';', Params[1], 'H');
          end;
          'J': begin
            if Params[0] = 2 then
              Write(#27'[2J');
          end;
          'K': begin
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
    else if AByte = 12 then
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

  Write(#27'[2J');
  Write(#27'[?25h');
  Flush(Output);

  Result := 1;
end;

function TScreen.ReadByte: Byte;
var
  c: Byte;
begin
  if RxBytes = 0 then
  begin
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
  Write(#27']0;', AName, #7);
  Flush(Output);
end;

procedure TScreen.SetCity(AName: PChar);
begin
end;

procedure TScreen.SetLevel(ALevel: PChar);
begin
end;

procedure TScreen.SetTimeLeft(ASeconds: LongWord);
begin
end;

procedure TScreen.SetTime(ASeconds: LongWord);
begin
end;

end.
