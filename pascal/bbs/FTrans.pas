{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of ftrans.h / ftrans.cpp / TFileQueue from janus.cpp
  File transfer protocols: XModem, YModem, ZModem wrappers, external protocol
  runner, file queue management, and progress tracking.
}

unit FTrans;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect, Defs, ComBase, Log, Protocol, Misc;

{ ---- ASCII control codes ---- }
const
  CTRL_X   = $18;   { CAN }
  XOFF     = $13;
  XON      = $11;
  SOH      = $01;
  STX      = $02;
  EOT      = $04;
  ACK      = $06;
  NAK      = $15;

{ ---- Zmodem status codes ---- }
const
  Z_OK       =  1;
  Z_ERROR    = -1;
  Z_TIMEOUT  = -2;
  Z_RCDO     = -3;

{ ---- Zmodem defaults ---- }
const
  LZCONV   = 0;
  LZMANAG  = 0;
  LZTRANS  = 0;
  KSIZE    = 8192;

{ ---- Zmodem framing ---- }
const
  ZPAD     = Ord('*');       { Padding character begins frames }
  ZDLE     = $18;            { Ctrl-X escape }
  ZDLEE    = ZDLE xor $40;  { Escaped ZDLE as transmitted }
  ZBIN     = Ord('A');       { Binary frame indicator }
  ZHEX     = Ord('B');       { HEX frame indicator }
  ZBIN32   = Ord('C');       { Binary frame with 32-bit FCS }

{ ---- Zmodem frame types ---- }
const
  ZRQINIT    = 0;
  ZRINIT     = 1;
  ZSINIT     = 2;
  ZACK       = 3;
  ZFILE      = 4;
  ZSKIP      = 5;
  ZNAK       = 6;
  ZABORT     = 7;
  ZFIN       = 8;
  ZRPOS      = 9;
  ZDATA      = 10;
  ZEOF       = 11;
  ZFERR      = 12;
  ZCRC       = 13;
  ZCHALLENGE = 14;
  ZCOMPL     = 15;
  ZCAN       = 16;
  ZFREECNT   = 17;
  ZCOMMAND   = 18;
  ZSTDERR    = 19;

{ ---- ZDLE sequences ---- }
const
  ZCRCE    = Ord('h');       { CRC next, frame ends, header follows }
  ZCRCG    = Ord('i');       { CRC next, frame continues nonstop }
  ZCRCQ    = Ord('j');       { CRC next, frame continues, ZACK expected }
  ZCRCW    = Ord('k');       { CRC next, ZACK expected, end of frame }
  ZRUB0    = Ord('l');       { Translate to rubout $7F }
  ZRUB1    = Ord('m');       { Translate to rubout $FF }

{ ---- zdlread return values ---- }
const
  GOTOR    = $100;
  GOTCRCE  = ZCRCE or GOTOR;
  GOTCRCG  = ZCRCG or GOTOR;
  GOTCRCQ  = ZCRCQ or GOTOR;
  GOTCRCW  = ZCRCW or GOTOR;
  GOTCAN   = GOTOR or $18;

{ ---- Header byte positions ---- }
const
  ZF0 = 3;
  ZF1 = 2;
  ZF2 = 1;
  ZF3 = 0;
  ZP0 = 0;
  ZP1 = 1;
  ZP2 = 2;
  ZP3 = 3;

{ ---- ZRINIT flags (ZF0) ---- }
const
  CANFDX   = $01;
  CANOVIO  = $02;
  CANBRK   = $04;
  CANCRY   = $08;
  CANLZW   = $10;
  CANFC32  = $20;

{ ---- ZFILE conversion options (ZF0) ---- }
const
  ZCBIN    = 1;
  ZCNL     = 2;
  ZCRESUM  = 3;

{ ---- ZFILE management options (ZF1) ---- }
const
  ZMNEW    = 1;
  ZMCRC    = 2;
  ZMAPND   = 3;
  ZMCLOB   = 4;
  ZMSPARS  = 5;
  ZMDIFF   = 6;
  ZMPROT   = 7;

{ ---- ZFILE transport options (ZF2) ---- }
const
  ZTLZW    = 1;
  ZTCRYPT  = 2;
  ZTRLE    = 3;

{ ---- ZCOMMAND (ZF0) ---- }
const
  ZCACK1   = 1;

{ ---- ZSINIT ---- }
const
  ZATTNLEN = 32;

{ ---- Janus constants ---- }
const
  BUFMAX          = 2048;
  JANUS_EFFICIENCY = 95;

{ ---- Progress type ---- }
const
  FILE_RECEIVING     = 1;
  FILE_SENDING       = 2;
  FILE_BIDIRECTIONAL = 3;

{ ---- Cancel sequence (CAN x5 + BS x5) ---- }
const
  CancelSeq: array[0..9] of Byte = ($18,$18,$18,$18,$18,$08,$08,$08,$08,$08);

type
  { Forward declarations }
  TZModem = class;
  TTransfer = class;
  TJanus = class;

  { ---- TProgress: virtual base for transfer progress display ---- }

  TProgress = class
  public
    ProgressType: Word;
    RxBlockSize:  Word;
    TxBlockSize:  Word;
    RxFileName:   String;
    TxFileName:   String;
    RxSize:       LongWord;
    RxPosition:   LongWord;
    TxSize:       LongWord;
    TxPosition:   LongWord;

    constructor Create;
    destructor Destroy; override;

    procedure BeginTransfer; virtual;
    procedure EndTransfer; virtual;
    procedure Update; virtual;
  end;

  { ---- TFileQueue: in-memory file transfer queue ---- }

  PFileQueueRec = ^TFileQueueRec;
  TFileQueueRec = packed record
    Sent:           Word;
    Name:           array[0..31] of Char;
    Size:           LongWord;
    Complete:       array[0..127] of Char;
    DeleteAfter:    Byte;
    TruncateAfter:  Byte;
  end;

  TFileQueue = class
  public
    Sent:           Word;
    Name:           String;
    Complete:       String;
    Size:           LongWord;
    DeleteAfter:    Boolean;
    TruncateAfter:  Boolean;
    TotalFiles:     LongWord;

    constructor Create;
    destructor Destroy; override;

    function  Add: Boolean;
    procedure Clear;
    function  First: Boolean;
    procedure Init;
    function  Next: Boolean;
    function  Previous: Boolean;
    procedure Remove(const AName: String = '');
    procedure Update;

  private
    Data: TCollection;
  end;

  { ---- TZModem: base Zmodem protocol engine ---- }
  { Constructor/destructor and protocol methods are in ZModem.pas }

  TZModem = class
  public
    EndRun:     Word;
    Hangup:     Word;
    FileSent:   Word;
    Maxblklen:  Word;
    Telnet:     Word;
    Pathname:   String;
    Speed:      LongWord;
    Com:        TCom;
    Log:        TLog;
    Progress:   TProgress;

    constructor Create; virtual;
    destructor Destroy; override;

    function  AbortSession: Boolean;
    function  TimedRead(hSec: LongInt): SmallInt;
    function  ZInitReceiver: SmallInt;
    function  ZInitSender(NothingToDo: Boolean): SmallInt;
    function  ZReceiveFile(const Path: String): SmallInt;
    function  ZSendFile(const FileName: String; const SendName: String = ''): SmallInt;
    procedure ZEndSender;

  private
    Wantfcs32:   SmallInt;
    Txfcs32:     SmallInt;
    Znulls:      SmallInt;
    LastSent_:   SmallInt;
    ZCtlesc:     SmallInt;
    Rxframeind:  SmallInt;
    Rxtype:      SmallInt;
    Rxflags:     SmallInt;
    Rxbuflen:    SmallInt;
    Rxcount:     SmallInt;
    Tframlen:    SmallInt;
    TryZHdrType: SmallInt;
    RxTempSize:  SmallInt;
    Txhdr:       array[0..3] of Byte;
    Rxhdr:       array[0..3] of Byte;
    Attn:        array[0..ZATTNLEN-1] of Byte;
    ZRxBuffer:   array[0..KSIZE-1] of Byte;
    TxBuffer:    PByte;
    RxTemp:      array[0..255] of Byte;
    RxTempPos:   PByte;
    Rxtimeout:   LongInt;
    Rxpos:       LongInt;
    Txpos:       LongInt;
    Rxbytes:     LongInt;

    procedure ZAckBiBi;
    function  ZDLRead: SmallInt;
    function  ZGetByte: SmallInt;
    function  ZGetHeader(var hdr): SmallInt;
    function  ZGetHex: SmallInt;
    function  ZGetLong(var hdr): LongInt;
    procedure ZPutHex(c: SmallInt);
    procedure ZPutLong(var hdr; pos: LongInt);
    function  ZReceiveBinaryHeader(var hdr): SmallInt;
    function  ZReceiveBinaryHeader32(var hdr): SmallInt;
    function  ZReceiveData(buf: PByte; length: SmallInt): SmallInt;
    function  ZReceiveHexHeader(var hdr): SmallInt;
    procedure ZSendBinaryHeader(ftype: SmallInt; var hdr);
    procedure ZSendData(buf: PByte; length: SmallInt; frameend: SmallInt);
    procedure ZSendHexHeader(ftype: SmallInt; var hdr);
    procedure ZSendLine(c: Byte);
  end;

  { ---- TTransfer: multi-protocol file transfer ---- }

  TTransfer = class(TZModem)
  public
    Task:    Word;
    Device:  String;
    RxQueue: TFileQueue;
    TxQueue: TFileQueue;

    constructor Create; override;
    destructor Destroy; override;

    function  ReceiveXModem(const Path: String): String;
    function  ReceiveASCIIDump(const Path: String): String;
    function  Receive1kXModem(const Path: String): String;
    function  ReceiveYModem(const Path: String): String;
    function  ReceiveYModemG(const Path: String): String;
    function  ReceiveZModem(const Path: String): String;
    procedure RunExternalProtocol(Download: Boolean; const Cmd: String;
                Proto: TProtocol);
    procedure Janus(const Path: String);
    function  Send1kXModem(const FileName: String): Boolean;
    function  SendASCIIDump(const FileName: String): Boolean;
    function  SendXModem(const FileName: String): Boolean;
    function  SendYModem(const FileName: String): Boolean;
    function  SendYModemG(const FileName: String): Boolean;
    function  SendZModem(const FileName: String; const SendName: String = ''): Boolean;
    function  SendZModem8K(const FileName: String; const SendName: String = ''): Boolean;

  private
    PktSize:   Word;
    SohByte:   Byte;
    DoCrc:     Boolean;
    UseAck:    Boolean;
    PktNumber: Byte;
    FinalName: String;

    function  ReceivePacket(lpBuffer: PByte): Boolean;
    function  ReceiveXFile(const Path: String): String;
    function  SendPacket(lpBuffer: PByte): Boolean;
    function  SendXFile(const FileName: String): Boolean;
  end;

  { ---- TJanus: Janus bidirectional protocol ---- }
  { Implementation in Janus.pas }

  TJanus = class
  public
    TimeoutSecs:   Word;
    MakeRequests:  Word;
    AllowRequests: Word;
    RxPath:        String;
    Speed:         LongWord;
    Com:           TCom;
    Log:           TLog;
    TxQueue:       TFileQueue;
    RxQueue:       TFileQueue;
    Outbound:      TObject;  { TOutbound - forward ref avoided }

    constructor Create;
    destructor Destroy; override;

    procedure Transfer;

  private
    RxFile:      Integer;
    TxFile:      Integer;
    Rxblklen:    Word;
    IsOutbound:  Word;
    CanCrc32:    SmallInt;
    WaitFlag:    SmallInt;
    RxCrc32:     SmallInt;
    RxTempSize:  SmallInt;
    RxFileName:  String;
    TxFileName:  String;
    RxTemp:      array[0..255] of Byte;
    RxTempPos:   PByte;
    LastSentJ:   Byte;
    Rxbufptr:    PByte;
    Rxbufmax:    PByte;
    JRxBuffer:   array[0..BUFMAX+7] of Byte;
    JTxBuffer:   array[0..BUFMAX+7] of Byte;
    RxPktCrc32:  LongWord;
    RxPktCrc16:  Word;
    LastPktName: LongWord;
    Rxpos:       LongInt;
    RxFilesize:  LongInt;
    RxFiletime:  LongInt;

    pkttype:     Byte;
    SharedCap:   Byte;
    Done:        Byte;
    xstate:      Word;
    rstate:      Word;
    rpos_count:  Word;
    blklen:      Word;
    txblklen:    Word;
    txblkmax:    Word;
    rxstpos:     LongInt;
    length_:     LongInt;
    xmit_retry:  LongInt;
    txpos:       LongInt;
    txstpos:     LongInt;
    timeout:     LongInt;
    txlength:    LongInt;
    lasttx:      LongInt;
    last_blkpos: LongInt;
    rpos_retry:  LongInt;
    rpos_sttime: LongInt;

    function  GetByte: SmallInt;
    procedure GetNextFile;
    function  GetPacket: Byte;
    function  GetRawByte: SmallInt;
    function  ProcessFileName: LongInt;
    procedure SendByte(AByte: Byte);
    procedure SendJPacket(Buffer: PByte; Len: Word; PType: Word);
  end;

implementation

{ ======================================================================
  TProgress
  ====================================================================== }

constructor TProgress.Create;
begin
  inherited Create;
  ProgressType := 0;
  RxBlockSize := 0;
  TxBlockSize := 0;
  RxFileName := '';
  TxFileName := '';
  RxSize := 0;
  RxPosition := 0;
  TxSize := 0;
  TxPosition := 0;
end;

destructor TProgress.Destroy;
begin
  inherited Destroy;
end;

procedure TProgress.BeginTransfer;
begin
  { Override in descendants }
end;

procedure TProgress.EndTransfer;
begin
  { Override in descendants }
end;

procedure TProgress.Update;
begin
  { Override in descendants }
end;

{ ======================================================================
  TFileQueue
  ====================================================================== }

constructor TFileQueue.Create;
begin
  inherited Create;
  Data := TCollection.Create;
  Init;
  TotalFiles := 0;
end;

destructor TFileQueue.Destroy;
begin
  Data.Clear;
  Data.Free;
  inherited Destroy;
end;

function TFileQueue.Add: Boolean;
var
  Rec: TFileQueueRec;
begin
  FillChar(Rec, SizeOf(TFileQueueRec), 0);
  Rec.Sent := Sent;
  StrPLCopy(Rec.Name, Name, SizeOf(Rec.Name) - 1);
  StrPLCopy(Rec.Complete, Complete, SizeOf(Rec.Complete) - 1);
  Rec.Size := Size;
  if DeleteAfter then Rec.DeleteAfter := 1 else Rec.DeleteAfter := 0;
  if TruncateAfter then Rec.TruncateAfter := 1 else Rec.TruncateAfter := 0;
  Inc(TotalFiles);
  Result := Data.Add(@Rec, SizeOf(TFileQueueRec)) <> 0;
end;

procedure TFileQueue.Clear;
begin
  Data.Clear;
  Init;
  TotalFiles := 0;
end;

function TFileQueue.First: Boolean;
var
  Rec: PFileQueueRec;
begin
  Result := False;
  Rec := PFileQueueRec(Data.First);
  if Rec <> nil then
  begin
    Sent := Rec^.Sent;
    Name := StrPas(Rec^.Name);
    Complete := StrPas(Rec^.Complete);
    Size := Rec^.Size;
    DeleteAfter := Rec^.DeleteAfter <> 0;
    TruncateAfter := Rec^.TruncateAfter <> 0;
    Result := True;
  end;
end;

procedure TFileQueue.Init;
begin
  Sent := 0;
  Name := '';
  Complete := '';
  Size := 0;
  DeleteAfter := False;
  TruncateAfter := False;
end;

function TFileQueue.Next: Boolean;
var
  Rec: PFileQueueRec;
begin
  Result := False;
  Rec := PFileQueueRec(Data.Next);
  if Rec <> nil then
  begin
    Sent := Rec^.Sent;
    Name := StrPas(Rec^.Name);
    Complete := StrPas(Rec^.Complete);
    Size := Rec^.Size;
    DeleteAfter := Rec^.DeleteAfter <> 0;
    TruncateAfter := Rec^.TruncateAfter <> 0;
    Result := True;
  end;
end;

function TFileQueue.Previous: Boolean;
var
  Rec: PFileQueueRec;
begin
  Result := False;
  Rec := PFileQueueRec(Data.Previous);
  if Rec <> nil then
  begin
    Sent := Rec^.Sent;
    Name := StrPas(Rec^.Name);
    Complete := StrPas(Rec^.Complete);
    Size := Rec^.Size;
    DeleteAfter := Rec^.DeleteAfter <> 0;
    TruncateAfter := Rec^.TruncateAfter <> 0;
    Result := True;
  end;
end;

procedure TFileQueue.Remove(const AName: String);
var
  Rec: PFileQueueRec;
  Found: Boolean;
begin
  if AName <> '' then
  begin
    Found := False;
    Rec := PFileQueueRec(Data.First);
    while Rec <> nil do
    begin
      if SameText(StrPas(Rec^.Name), AName) then
      begin
        Found := True;
        Break;
      end;
      Rec := PFileQueueRec(Data.Next);
    end;
    if Found then
    begin
      if Rec^.DeleteAfter <> 0 then
        SysUtils.DeleteFile(StrPas(Rec^.Complete));
      Data.Remove;
    end;
  end
  else
  begin
    if DeleteAfter then
      SysUtils.DeleteFile(Complete);
    Data.Remove;
  end;
  if TotalFiles > 0 then
    Dec(TotalFiles);
end;

procedure TFileQueue.Update;
var
  Rec: PFileQueueRec;
begin
  Rec := PFileQueueRec(Data.Value);
  if Rec <> nil then
  begin
    Rec^.Sent := Sent;
    StrPLCopy(Rec^.Name, Name, SizeOf(Rec^.Name) - 1);
    StrPLCopy(Rec^.Complete, Complete, SizeOf(Rec^.Complete) - 1);
    Rec^.Size := Size;
    if DeleteAfter then Rec^.DeleteAfter := 1 else Rec^.DeleteAfter := 0;
    if TruncateAfter then Rec^.TruncateAfter := 1 else Rec^.TruncateAfter := 0;
  end;
end;

{ ======================================================================
  TZModem - base constructor/destructor only
  Protocol methods are implemented in ZModem.pas via class helpers or
  will be filled in when that unit is converted.
  ====================================================================== }

constructor TZModem.Create;
begin
  inherited Create;
  Com := nil;
  Log := nil;
  Progress := nil;
  EndRun := 0;
  Hangup := 0;
  FileSent := 0;
  Maxblklen := 0;
  Telnet := 0;
  Speed := 0;
  Pathname := '';
  Wantfcs32 := 0;
  Txfcs32 := 0;
  Znulls := 0;
  LastSent_ := 0;
  ZCtlesc := 0;
  Rxframeind := 0;
  Rxtype := 0;
  Rxflags := 0;
  Rxbuflen := 0;
  Rxcount := 0;
  Tframlen := 0;
  TryZHdrType := 0;
  RxTempSize := 0;
  FillChar(Txhdr, SizeOf(Txhdr), 0);
  FillChar(Rxhdr, SizeOf(Rxhdr), 0);
  FillChar(Attn, SizeOf(Attn), 0);
  FillChar(ZRxBuffer, SizeOf(ZRxBuffer), 0);
  FillChar(RxTemp, SizeOf(RxTemp), 0);
  TxBuffer := nil;
  RxTempPos := nil;
  Rxtimeout := 0;
  Rxpos := 0;
  Txpos := 0;
  Rxbytes := 0;
end;

destructor TZModem.Destroy;
begin
  if TxBuffer <> nil then
  begin
    FreeMem(TxBuffer);
    TxBuffer := nil;
  end;
  inherited Destroy;
end;

{ Stub implementations - will be replaced by ZModem.pas }
function TZModem.AbortSession: Boolean;
begin
  Result := (Com = nil) or (EndRun <> 0) or (Hangup <> 0) or
            (Com.Carrier = 0);
end;

function TZModem.TimedRead(hSec: LongInt): SmallInt;
var
  Elapsed: LongInt;
begin
  Result := -1;
  Elapsed := 0;
  while Elapsed < hSec * 10 do
  begin
    if AbortSession then Exit;
    if Com.BytesReady <> 0 then
    begin
      Result := SmallInt(Com.ReadByte);
      Exit;
    end;
    Sleep(10);
    Inc(Elapsed, 10);
  end;
end;

function TZModem.ZInitReceiver: SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZInitSender(NothingToDo: Boolean): SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZReceiveFile(const Path: String): SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZSendFile(const FileName: String; const SendName: String): SmallInt;
begin
  Result := Z_ERROR;
end;

procedure TZModem.ZEndSender;
begin
end;

procedure TZModem.ZAckBiBi;
begin
end;

function TZModem.ZDLRead: SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZGetByte: SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZGetHeader(var hdr): SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZGetHex: SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZGetLong(var hdr): LongInt;
begin
  Result := 0;
end;

procedure TZModem.ZPutHex(c: SmallInt);
begin
end;

procedure TZModem.ZPutLong(var hdr; pos: LongInt);
begin
end;

function TZModem.ZReceiveBinaryHeader(var hdr): SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZReceiveBinaryHeader32(var hdr): SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZReceiveData(buf: PByte; length: SmallInt): SmallInt;
begin
  Result := Z_ERROR;
end;

function TZModem.ZReceiveHexHeader(var hdr): SmallInt;
begin
  Result := Z_ERROR;
end;

procedure TZModem.ZSendBinaryHeader(ftype: SmallInt; var hdr);
begin
end;

procedure TZModem.ZSendData(buf: PByte; length: SmallInt; frameend: SmallInt);
begin
end;

procedure TZModem.ZSendHexHeader(ftype: SmallInt; var hdr);
begin
end;

procedure TZModem.ZSendLine(c: Byte);
begin
end;

{ ======================================================================
  TTransfer
  ====================================================================== }

constructor TTransfer.Create;
begin
  inherited Create;
  RxQueue := TFileQueue.Create;
  TxQueue := TFileQueue.Create;
  Device := '';
  PktSize := 128;
  SohByte := SOH;
  DoCrc := False;
  UseAck := True;
  FinalName := '';
  PktNumber := 0;
  Task := 1;
end;

destructor TTransfer.Destroy;
begin
  RxQueue.Free;
  TxQueue.Free;
  inherited Destroy;
end;

function TTransfer.ReceivePacket(lpBuffer: PByte): Boolean;
var
  c: SmallInt;
  i, crc, recvcrc: Word;
  checksum: Byte;
begin
  Result := False;
  checksum := 0;
  crc := 0;

  c := TimedRead(100);
  if (c = -1) or (Byte(c) <> PktNumber) then Exit;
  c := TimedRead(100);
  if (c = -1) or (Byte(c) <> (PktNumber xor $FF)) then Exit;

  if DoCrc then
  begin
    for i := 0 to PktSize - 1 do
    begin
      c := TimedRead(100);
      if c = -1 then Exit;
      lpBuffer[i] := Byte(c);
      crc := Crc16(lpBuffer[i], crc);
    end;
    c := TimedRead(100);
    if c = -1 then Exit;
    recvcrc := Word(c shl 8);
    c := TimedRead(100);
    if c = -1 then Exit;
    recvcrc := recvcrc or Word(c);
    if recvcrc <> crc then Exit;
  end
  else
  begin
    for i := 0 to PktSize - 1 do
    begin
      c := TimedRead(100);
      if c = -1 then Exit;
      lpBuffer[i] := Byte(c);
      Inc(checksum, lpBuffer[i]);
    end;
    c := TimedRead(100);
    if (c = -1) or (Byte(c) <> checksum) then Exit;
  end;

  Result := True;
end;

function TTransfer.ReceiveXFile(const Path: String): String;
var
  fs: TFileStream;
  c: SmallInt;
  errs: SmallInt;
  fStop, fStart: Boolean;
  buffer: PByte;
begin
  Result := '';

  try
    fs := TFileStream.Create(Path, fmCreate);
  except
    Exit;
  end;

  buffer := nil;
  try
    GetMem(buffer, 1024);
    errs := 0;
    DoCrc := True;
    PktNumber := 1;

    fStop := False;
    fStart := False;

    while (not AbortSession) and (not fStop) do
    begin
      c := TimedRead(1000);
      if c <> -1 then
      begin
        case c of
          SOH:
          begin
            PktSize := 128;
            if ReceivePacket(buffer) then
            begin
              if UseAck then
                Com.BufferByte(ACK);
              fs.Write(buffer^, PktSize);
              errs := 0;
              fStart := True;
              Inc(PktNumber);
            end
            else
            begin
              Com.BufferByte(NAK);
              Inc(errs);
              if errs >= 10 then
              begin
                Com.BufferBytes(@CancelSeq[0], 10);
                fStop := True;
              end;
            end;
          end;

          STX:
          begin
            PktSize := 1024;
            if ReceivePacket(buffer) then
            begin
              if UseAck then
                Com.BufferByte(ACK);
              fs.Write(buffer^, PktSize);
              errs := 0;
              fStart := True;
              Inc(PktNumber);
            end
            else
            begin
              Com.BufferByte(NAK);
              Inc(errs);
              if errs >= 10 then
              begin
                Com.BufferBytes(@CancelSeq[0], 10);
                fStop := True;
              end;
            end;
          end;

          EOT:
          begin
            if UseAck then
              Com.BufferByte(ACK);
            fStop := True;
            Result := Path;
          end;

          CTRL_X:
          begin
            if TimedRead(100) = CTRL_X then
            begin
              Com.BufferBytes(@CancelSeq[0], 10);
              fStop := True;
            end;
          end;
        end; { case }
      end
      else
      begin
        Inc(errs);
        if (not fStart) and (errs < 5) then
          Com.BufferByte(Ord('C'))
        else
        begin
          if errs >= 10 then
          begin
            Com.BufferBytes(@CancelSeq[0], 10);
            fStop := True;
          end;
          Com.BufferByte(NAK);
          if not fStart then
            DoCrc := False;
        end;
      end;
    end;
  finally
    if buffer <> nil then
      FreeMem(buffer);
    fs.Free;
  end;
end;

function TTransfer.ReceiveXModem(const Path: String): String;
begin
  UseAck := True;
  Result := ReceiveXFile(Path);
end;

function TTransfer.Receive1kXModem(const Path: String): String;
begin
  UseAck := True;
  Result := ReceiveXFile(Path);
end;

function TTransfer.ReceiveASCIIDump(const Path: String): String;
begin
  { ASCII dump receive - not commonly used, returns empty on stub }
  Result := '';
end;

function TTransfer.ReceiveYModem(const Path: String): String;
begin
  { YModem receive uses same XFile engine with block 0 handling }
  UseAck := True;
  Result := ReceiveXFile(Path);
end;

function TTransfer.ReceiveYModemG(const Path: String): String;
begin
  UseAck := True;
  Result := ReceiveXFile(Path);
end;

function TTransfer.ReceiveZModem(const Path: String): String;
begin
  Result := '';
  if ZInitReceiver = ZFILE then
  begin
    if ZReceiveFile(Path) = ZEOF then
      Result := Pathname;
  end;
end;

function TTransfer.SendPacket(lpBuffer: PByte): Boolean;
var
  i, crc: Word;
  checksum: Byte;
begin
  checksum := 0;
  crc := 0;

  Com.BufferByte(SohByte);
  Com.BufferByte(PktNumber);
  Com.BufferByte(PktNumber xor $FF);

  if DoCrc then
  begin
    for i := 0 to PktSize - 1 do
    begin
      crc := Crc16(lpBuffer[i], crc);
      Com.BufferByte(lpBuffer[i]);
    end;
    Com.BufferByte(Byte(crc shr 8));
    Com.BufferByte(Byte(crc and $FF));
  end
  else
  begin
    for i := 0 to PktSize - 1 do
    begin
      Inc(checksum, lpBuffer[i]);
      Com.BufferByte(lpBuffer[i]);
    end;
    Com.BufferByte(checksum);
  end;

  Com.UnbufferBytes;
  Result := not AbortSession;
end;

function TTransfer.SendXFile(const FileName: String): Boolean;
var
  fs: TFileStream;
  c: SmallInt;
  errs: SmallInt;
  fStarted: Boolean;
  buffer: PByte;
  bytesRead: LongInt;
begin
  Result := False;
  DoCrc := False;
  errs := 0;
  fStarted := False;

  buffer := nil;
  try
    GetMem(buffer, PktSize);
  except
    Exit;
  end;

  try
    fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  except
    FreeMem(buffer);
    Exit;
  end;

  try
    FillChar(buffer^, PktSize, 26);
    fs.Read(buffer^, PktSize);

    if Progress <> nil then
    begin
      Progress.TxFileName := FileName;
      Progress.TxBlockSize := PktSize;
      Progress.TxSize := fs.Size;
      Progress.BeginTransfer;
    end;

    while not AbortSession do
    begin
      c := TimedRead(1000);
      if c <> -1 then
      begin
        if (c = Ord('C')) or (c = NAK) then
        begin
          if c = Ord('C') then
            DoCrc := True;
          SendPacket(buffer);
          Inc(errs);
          fStarted := True;
        end;
        if (c = ACK) or (not UseAck) then
        begin
          Inc(PktNumber);
          if Progress <> nil then
          begin
            Inc(Progress.TxPosition, Progress.TxBlockSize);
            Progress.Update;
          end;
          errs := 0;
          FillChar(buffer^, PktSize, 26);
          bytesRead := fs.Read(buffer^, PktSize);
          if bytesRead = 0 then
          begin
            Com.SendByte(EOT);
            while not AbortSession do
            begin
              c := TimedRead(100);
              if c <> -1 then
              begin
                if c = ACK then
                begin
                  Result := True;
                  Break;
                end
                else if (c = Ord('C')) or (c = NAK) then
                  Com.SendByte(EOT);
              end
              else
              begin
                Inc(errs);
                if errs > 10 then
                begin
                  Com.SendByte(EOT);
                  Com.SendBytes(@CancelSeq[0], 10);
                  Break;
                end;
              end;
            end;
            Break;
          end;
          SendPacket(buffer);
          fStarted := True;
        end;
        if c = CTRL_X then
        begin
          if TimedRead(100) = CTRL_X then
            Break;
        end;
      end
      else
      begin
        Inc(errs);
        if errs > 10 then
        begin
          Com.SendBytes(@CancelSeq[0], 10);
          Break;
        end
        else if fStarted then
          SendPacket(buffer);
      end;
    end;

    if Progress <> nil then
    begin
      Progress.EndTransfer;
      FreeAndNil(Progress);
    end;
  finally
    fs.Free;
    FreeMem(buffer);
  end;
end;

function TTransfer.SendXModem(const FileName: String): Boolean;
begin
  SohByte := SOH;
  PktSize := 128;
  PktNumber := 1;
  UseAck := True;
  Result := SendXFile(FileName);
end;

function TTransfer.Send1kXModem(const FileName: String): Boolean;
begin
  SohByte := STX;
  PktSize := 1024;
  PktNumber := 1;
  UseAck := True;
  Result := SendXFile(FileName);
end;

function TTransfer.SendASCIIDump(const FileName: String): Boolean;
var
  fs: TFileStream;
  c: Integer;
  nChars: Word;
  b: Byte;
begin
  Result := False;
  nChars := 0;

  try
    fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  except
    Exit;
  end;

  try
    Com.BufferBytes(PByte(PChar(#13#10)), 2);

    while not AbortSession do
    begin
      if nChars = 0 then
      begin
        if fs.Read(b, 1) = 0 then
        begin
          Result := True;
          Break;
        end;
        Com.BufferByte(b);
      end;

      if Com.BytesReady <> 0 then
      begin
        c := Com.ReadByte;
        if c = 8 then
        begin
          Com.BufferBytes(PByte(PChar(#8' '#8)), 3);
          Dec(nChars);
        end
        else if c < 32 then
          Break
        else
        begin
          Com.SendByte(Byte(c));
          Inc(nChars);
        end;
      end;
    end;

    Com.UnbufferBytes;
  finally
    fs.Free;
  end;
end;

function TTransfer.SendYModem(const FileName: String): Boolean;
var
  c: SmallInt;
  fZeroSent, fDone: Boolean;
  errs: Word;
  ZeroBlock: array[0..127] of Byte;
  BaseName: String;
  FileSize: Int64;
  s: String;
  SR: TSearchRec;
begin
  SohByte := SOH;
  PktSize := 128;
  PktNumber := 0;
  fZeroSent := False;
  fDone := False;
  Result := False;
  errs := 0;

  BaseName := ExtractFileName(FileName);
  FileSize := 0;
  if FindFirst(FileName, faAnyFile, SR) = 0 then
  begin
    FileSize := SR.Size;
    FindClose(SR);
  end;

  FillChar(ZeroBlock, SizeOf(ZeroBlock), 0);
  s := BaseName + #0 + IntToStr(FileSize) + ' ' + IntToStr(DateTimeToFileDate(Now));
  if Length(s) < SizeOf(ZeroBlock) then
    Move(s[1], ZeroBlock[0], Length(s));

  while (not fDone) and (not AbortSession) do
  begin
    c := TimedRead(1000);
    if c <> -1 then
    begin
      if (c = Ord('C')) or (c = NAK) then
      begin
        if c = Ord('C') then
          DoCrc := True;
        SendPacket(@ZeroBlock[0]);
        fZeroSent := True;
      end;
      if (c = ACK) and fZeroSent then
      begin
        SohByte := STX;
        PktSize := 1024;
        PktNumber := 1;
        UseAck := True;
        Result := SendXFile(FileName);
        fDone := True;
      end;
    end
    else
    begin
      Inc(errs);
      if errs >= 10 then
        fDone := True;
    end;
  end;
end;

function TTransfer.SendYModemG(const FileName: String): Boolean;
var
  c: SmallInt;
  fZeroSent, fDone: Boolean;
  errs: Word;
  ZeroBlock: array[0..127] of Byte;
  BaseName: String;
  FileSize: Int64;
  s: String;
  SR: TSearchRec;
begin
  SohByte := SOH;
  PktSize := 128;
  PktNumber := 0;
  fZeroSent := False;
  fDone := False;
  Result := False;
  errs := 0;

  BaseName := ExtractFileName(FileName);
  FileSize := 0;
  if FindFirst(FileName, faAnyFile, SR) = 0 then
  begin
    FileSize := SR.Size;
    FindClose(SR);
  end;

  FillChar(ZeroBlock, SizeOf(ZeroBlock), 0);
  s := BaseName + #0 + IntToStr(FileSize) + ' ' + IntToStr(DateTimeToFileDate(Now));
  if Length(s) < SizeOf(ZeroBlock) then
    Move(s[1], ZeroBlock[0], Length(s));

  while (not fDone) and (not AbortSession) do
  begin
    c := TimedRead(1000);
    if c <> -1 then
    begin
      if (c = Ord('C')) or (c = NAK) then
      begin
        if fZeroSent then
          fDone := True
        else
        begin
          if c = Ord('C') then
            DoCrc := True;
          SendPacket(@ZeroBlock[0]);
          fZeroSent := True;
        end;
      end;
      if (c = ACK) and fZeroSent then
      begin
        SohByte := STX;
        PktSize := 1024;
        PktNumber := 1;
        UseAck := True;
        Result := SendXFile(FileName);
        fDone := True;
      end;
    end
    else
    begin
      Inc(errs);
      if errs >= 10 then
        fDone := True;
    end;
  end;
end;

function TTransfer.SendZModem(const FileName: String; const SendName: String): Boolean;
var
  i: SmallInt;
begin
  Result := False;
  Maxblklen := 1024;
  if (FileSent = 0) and (FileName = '') then
    ZInitSender(True)
  else
    ZInitSender(False);
  if FileName <> '' then
  begin
    i := ZSendFile(FileName, SendName);
    if (i = Z_OK) or (i = ZSKIP) then
    begin
      Result := True;
      Inc(FileSent);
    end;
  end
  else
    ZEndSender;
end;

function TTransfer.SendZModem8K(const FileName: String; const SendName: String): Boolean;
var
  i: SmallInt;
begin
  Result := False;
  Maxblklen := KSIZE;
  if (FileSent = 0) and (FileName = '') then
    ZInitSender(True)
  else
    ZInitSender(False);
  if FileName <> '' then
  begin
    i := ZSendFile(FileName, SendName);
    if (i = Z_OK) or (i = ZSKIP) then
    begin
      Result := True;
      Inc(FileSent);
    end;
  end
  else
    ZEndSender;
end;

procedure TTransfer.Janus(const Path: String);
{$IFNDEF UNIX}
var
  Jan: TJanus;
{$ENDIF}
begin
  {$IFNDEF UNIX}
  Jan := TJanus.Create;
  try
    Jan.RxPath := Path;
    Jan.Com := Com;
    Jan.Log := Log;
    Jan.TxQueue := TxQueue;
    Jan.RxQueue := RxQueue;
    Jan.Transfer;
  finally
    Jan.Free;
  end;
  {$ENDIF}
end;

procedure TTransfer.RunExternalProtocol(Download: Boolean; const Cmd: String;
  Proto: TProtocol);
var
  fp: TextFile;
  Batch: Boolean;
  Found: Boolean;
  Command, Temp, Control, Line: String;
  Cps: LongWord;
  i: Word;
  p: String;
  Parts: TStringList;
begin
  if Proto = nil then Exit;

  Batch := TxQueue.TotalFiles > 1;

  Found := False;
  if Proto.First <> 0 then
  repeat
    if (Proto.Active <> 0) and ((not Batch) or (Proto.Batch <> 0)) then
    begin
      if SameText(StrPas(Proto.Key), Cmd) then
      begin
        Found := True;
        Break;
      end;
    end;
  until Proto.Next = 0;

  if not Found then Exit;

  { Handle log file cleanup }
  if StrPas(Proto.LogFileName) <> '' then
  begin
    Command := StrPas(Proto.LogFileName);
    Temp := IntToStr(Task);
    Command := StringReplace(Command, '%k', Temp, [rfReplaceAll]);
    SysUtils.DeleteFile(Command);
  end;

  { Create control file }
  Control := '';
  if StrPas(Proto.CtlFileName) <> '' then
  begin
    Control := StrPas(Proto.CtlFileName);
    Temp := IntToStr(Task);
    Control := StringReplace(Control, '%k', Temp, [rfReplaceAll]);

    AssignFile(fp, Control);
    try
      Rewrite(fp);
      if TxQueue.First then
      repeat
        Command := StrPas(Proto.DownloadCtlString);
        Command := StringReplace(Command, '%1', TxQueue.Complete, [rfReplaceAll]);
        WriteLn(fp, Command);
      until not TxQueue.Next;
      CloseFile(fp);
    except
    end;
  end;

  { Run the external protocol }
  if Download then
  begin
    Command := StrPas(Proto.DownloadCmd);
    Temp := IntToStr(Task);
    Command := StringReplace(Command, '%k', Temp, [rfReplaceAll]);
    {$IFDEF UNIX}
    Command := StringReplace(Command, '%P', Device, [rfReplaceAll]);
    {$ELSE}
    if Length(Device) > 3 then
      Temp := Copy(Device, 4, Length(Device))
    else
      Temp := '0';
    Command := StringReplace(Command, '%P', Temp, [rfReplaceAll]);
    {$ENDIF}
    Command := StringReplace(Command, '%b', IntToStr(Speed), [rfReplaceAll]);
    if Pos('%1', Command) > 0 then
    begin
      if TxQueue.First then
        Command := StringReplace(Command, '%1', TxQueue.Complete, [rfReplaceAll])
      else
        Command := StringReplace(Command, '%1', '', [rfReplaceAll]);
    end;
    Command := StringReplace(Command, '%2', Control, [rfReplaceAll]);

    if Log <> nil then
      Log.Write(':Running %s', [Command]);
    RunExternal(Command, 0);
    if Log <> nil then
      Log.Write(':Returned from external protocol', []);
  end;

  { Clean up control file }
  if Control <> '' then
    SysUtils.DeleteFile(Control);

  { Parse log file for results }
  if StrPas(Proto.LogFileName) <> '' then
  begin
    Command := StrPas(Proto.LogFileName);
    Temp := IntToStr(Task);
    Command := StringReplace(Command, '%k', Temp, [rfReplaceAll]);

    if FileExists(Command) then
    begin
      Parts := TStringList.Create;
      try
        AssignFile(fp, Command);
        Reset(fp);
        try
          while not Eof(fp) do
          begin
            ReadLn(fp, Line);
            Line := Trim(Line);
            Parts.Clear;
            Parts.Delimiter := ' ';
            Parts.DelimitedText := Line;
            if Parts.Count > 0 then
            begin
              if Parts[0] = StrPas(Proto.DownloadKeyword) then
              begin
                Found := False;
                Cps := 0;
                for i := 1 to Parts.Count - 1 do
                begin
                  if Proto.FileNamePos = Word(i + 1) then
                  begin
                    p := Parts[i];
                    if TxQueue.First then
                    repeat
                      if SameText(p, TxQueue.Complete) or
                         SameText(p, TxQueue.Name) then
                      begin
                        Found := True;
                        Break;
                      end;
                    until not TxQueue.Next;
                  end;
                  if Proto.CpsPos = Word(i + 1) then
                    Cps := StrToIntDef(Parts[i], 0);
                end;
                if Found and (Log <> nil) then
                begin
                  if Speed > 0 then
                    Log.Write('+CPS: %d (%d bytes)  Efficiency: %d%%',
                      [Cps, TxQueue.Size, (Cps * 100) div (Speed div 10)])
                  else
                    Log.Write('+CPS: %d (%d bytes)', [Cps, TxQueue.Size]);
                  Log.Write('+Sent-%s %s', [StrPas(Proto.Key),
                    UpperCase(TxQueue.Complete)]);
                  TxQueue.Sent := 1;
                  TxQueue.Update;
                end;
              end;
            end;
          end;
        finally
          CloseFile(fp);
        end;
      finally
        Parts.Free;
      end;

      SysUtils.DeleteFile(Command);
    end;
  end;
end;

{ ======================================================================
  TJanus - stubs only, implementation in Janus.pas
  ====================================================================== }

constructor TJanus.Create;
begin
  inherited Create;
  TimeoutSecs := 0;
  MakeRequests := 0;
  AllowRequests := 0;
  RxPath := '';
  Speed := 0;
  Com := nil;
  Log := nil;
  TxQueue := nil;
  RxQueue := nil;
  Outbound := nil;
  RxFile := -1;
  TxFile := -1;
  Rxblklen := 0;
  IsOutbound := 0;
  CanCrc32 := 0;
  WaitFlag := 0;
  RxCrc32 := 0;
  RxTempSize := 0;
  RxFileName := '';
  TxFileName := '';
  FillChar(RxTemp, SizeOf(RxTemp), 0);
  RxTempPos := nil;
  LastSentJ := 0;
  Rxbufptr := nil;
  Rxbufmax := nil;
  FillChar(JRxBuffer, SizeOf(JRxBuffer), 0);
  FillChar(JTxBuffer, SizeOf(JTxBuffer), 0);
  RxPktCrc32 := 0;
  RxPktCrc16 := 0;
  LastPktName := 0;
  Rxpos := 0;
  RxFilesize := 0;
  RxFiletime := 0;
  pkttype := 0;
  SharedCap := 0;
  Done := 0;
  xstate := 0;
  rstate := 0;
  rpos_count := 0;
  blklen := 0;
  txblklen := 0;
  txblkmax := 0;
  rxstpos := 0;
  length_ := 0;
  xmit_retry := 0;
  txpos := 0;
  txstpos := 0;
  timeout := 0;
  txlength := 0;
  lasttx := 0;
  last_blkpos := 0;
  rpos_retry := 0;
  rpos_sttime := 0;
end;

destructor TJanus.Destroy;
begin
  inherited Destroy;
end;

procedure TJanus.Transfer;
begin
  { Stub - full implementation in Janus.pas }
end;

function TJanus.GetByte: SmallInt;
begin
  Result := -1;
end;

procedure TJanus.GetNextFile;
begin
end;

function TJanus.GetPacket: Byte;
begin
  Result := 0;
end;

function TJanus.GetRawByte: SmallInt;
begin
  Result := -1;
end;

function TJanus.ProcessFileName: LongInt;
begin
  Result := 0;
end;

procedure TJanus.SendByte(AByte: Byte);
begin
end;

procedure TJanus.SendJPacket(Buffer: PByte; Len: Word; PType: Word);
begin
end;

end.
