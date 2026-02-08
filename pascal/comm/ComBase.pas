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

  FreePascal conversion of combase.h - TCom abstract base class
}

unit ComBase;

{$MODE OBJFPC}
{$H+}

interface

uses
  Defs;

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

implementation

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

end.
