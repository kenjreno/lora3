{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion: Abstract message base class
}

unit MsgBase;

{$MODE OBJFPC}
{$H+}

interface

uses
  Collect, Struc299;

type
  TMsgBase = class
  public
    Id: LongWord;
    Current: LongWord;
    From_: array[0..63] of Char;
    To_: array[0..63] of Char;
    Subject_: array[0..71] of Char;
    Crash: Byte;
    Direct: Byte;
    FileAttach: Byte;
    FileRequest: Byte;
    Hold: Byte;
    Immediate: Byte;
    Intransit: Byte;
    KillSent: Byte;
    Local_: Byte;
    Private_: Byte;
    ReceiptRequest: Byte;
    Received: Byte;
    Sent: Byte;
    Written: MDATE;
    Arrived: MDATE;
    FromAddress: array[0..63] of Char;
    ToAddress: array[0..63] of Char;
    Reply: LongWord;
    Original: LongWord;
    Text: TCollection;

    constructor Create;
    destructor Destroy; override;

    function Add: Boolean; virtual; abstract;
    function AddFrom(MsgBase: TMsgBase): Boolean; virtual; abstract;
    function AddText(var MsgText: TCollection): Boolean; virtual; abstract;
    procedure Close; virtual; abstract;
    function Delete(ulMsg: LongWord): Boolean; virtual; abstract;
    function Highest: LongWord; virtual; abstract;
    function GetHWM(var ulMsg: LongWord): Boolean; virtual; abstract;
    function Lock(ulTimeout: LongWord = 0): Boolean; virtual; abstract;
    function Lowest: LongWord; virtual; abstract;
    function MsgnToUid(ulMsg: LongWord): LongWord; virtual; abstract;
    procedure New; virtual; abstract;
    function Next(var ulMsg: LongWord): Boolean; virtual; abstract;
    function Number: LongWord; virtual; abstract;
    procedure Pack; virtual; abstract;
    function Previous(var ulMsg: LongWord): Boolean; virtual; abstract;
    function ReadHeader(ulMsg: LongWord): Boolean; virtual; abstract;
    function ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt = 79): Boolean; virtual; abstract;
    function ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt = 79): Boolean; virtual; abstract;
    procedure SetHWM(ulMsg: LongWord); virtual; abstract;
    function UidToMsgn(ulMsg: LongWord): LongWord; virtual; abstract;
    procedure UnLock; virtual; abstract;
    function WriteHeader(ulMsg: LongWord): Boolean; virtual; abstract;

  protected
    szBuff: array[0..MAX_LINE_LENGTH] of Char;
    szLine: array[0..MAX_LINE_LENGTH] of Char;
    szWrp: array[0..MAX_LINE_LENGTH] of Char;
    pLine: PChar;
    pBuff: PChar;

    { Helper: copy fields from another message base }
    procedure CopyHeaderFrom(MsgBase: TMsgBase);
  end;

implementation

constructor TMsgBase.Create;
begin
  inherited Create;
  Text := TCollection.Create;
  Id := 0;
  Current := 0;
  Reply := 0;
  Original := 0;
  FillChar(From_, SizeOf(From_), 0);
  FillChar(To_, SizeOf(To_), 0);
  FillChar(Subject_, SizeOf(Subject_), 0);
  FillChar(FromAddress, SizeOf(FromAddress), 0);
  FillChar(ToAddress, SizeOf(ToAddress), 0);
  FillChar(Written, SizeOf(Written), 0);
  FillChar(Arrived, SizeOf(Arrived), 0);
  Crash := 0;
  Direct := 0;
  FileAttach := 0;
  FileRequest := 0;
  Hold := 0;
  Immediate := 0;
  Intransit := 0;
  KillSent := 0;
  Local_ := 0;
  Private_ := 0;
  ReceiptRequest := 0;
  Received := 0;
  Sent := 0;
  pLine := nil;
  pBuff := nil;
end;

destructor TMsgBase.Destroy;
begin
  Text.Free;
  inherited Destroy;
end;

procedure TMsgBase.CopyHeaderFrom(MsgBase: TMsgBase);
begin
  Move(MsgBase.From_, From_, SizeOf(From_));
  Move(MsgBase.To_, To_, SizeOf(To_));
  Move(MsgBase.Subject_, Subject_, SizeOf(Subject_));
  Move(MsgBase.FromAddress, FromAddress, SizeOf(FromAddress));
  Move(MsgBase.ToAddress, ToAddress, SizeOf(ToAddress));
  Written := MsgBase.Written;
  Arrived := MsgBase.Arrived;
  Original := MsgBase.Original;
  Reply := MsgBase.Reply;
  Crash := MsgBase.Crash;
  Direct := MsgBase.Direct;
  FileAttach := MsgBase.FileAttach;
  FileRequest := MsgBase.FileRequest;
  Hold := MsgBase.Hold;
  Immediate := MsgBase.Immediate;
  Intransit := MsgBase.Intransit;
  KillSent := MsgBase.KillSent;
  Local_ := MsgBase.Local_;
  Private_ := MsgBase.Private_;
  ReceiptRequest := MsgBase.ReceiptRequest;
  Received := MsgBase.Received;
  Sent := MsgBase.Sent;
end;

end.
