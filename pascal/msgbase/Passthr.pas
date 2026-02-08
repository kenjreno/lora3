{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of passthr.cpp
  Passthrough message base - no storage, just holds data in memory
}

unit Passthr;

{$MODE OBJFPC}
{$H+}

interface

uses
  Collect, Struc299, MsgBase;

type
  TPassthr = class(TMsgBase)
  public
    constructor Create;
    destructor Destroy; override;

    function Add: Boolean; override;
    function AddFrom(AMsgBase: TMsgBase): Boolean; override;
    function AddText(var MsgText: TCollection): Boolean; override;
    procedure Close; override;
    function Delete(ulMsg: LongWord): Boolean; override;
    function Highest: LongWord; override;
    function GetHWM(var ulMsg: LongWord): Boolean; override;
    function Lock(ulTimeout: LongWord = 0): Boolean; override;
    function Lowest: LongWord; override;
    function MsgnToUid(ulMsg: LongWord): LongWord; override;
    procedure New; override;
    function Next(var ulMsg: LongWord): Boolean; override;
    function Number: LongWord; override;
    procedure Pack; override;
    function Previous(var ulMsg: LongWord): Boolean; override;
    function ReadHeader(ulMsg: LongWord): Boolean; override;
    function ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt = 79): Boolean; override;
    function ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt = 79): Boolean; override;
    procedure SetHWM(ulMsg: LongWord); override;
    function UidToMsgn(ulMsg: LongWord): LongWord; override;
    procedure UnLock; override;
    function WriteHeader(ulMsg: LongWord): Boolean; override;
  end;

implementation

constructor TPassthr.Create;
begin
  inherited Create;
  Id := 0;
end;

destructor TPassthr.Destroy;
begin
  inherited Destroy;
end;

function TPassthr.Add: Boolean;
begin
  Result := AddText(Text);
end;

function TPassthr.AddFrom(AMsgBase: TMsgBase): Boolean;
begin
  New;
  CopyHeaderFrom(AMsgBase);
  { Passthrough copies FromAddress/ToAddress only if non-empty }
  if AMsgBase.FromAddress[0] <> #0 then
    Move(AMsgBase.FromAddress, FromAddress, SizeOf(FromAddress));
  if AMsgBase.ToAddress[0] <> #0 then
    Move(AMsgBase.ToAddress, ToAddress, SizeOf(ToAddress));
  Result := AddText(AMsgBase.Text);
end;

function TPassthr.AddText(var MsgText: TCollection): Boolean;
var
  p: PChar;
begin
  Text.Clear;
  p := PChar(MsgText.First);
  while p <> nil do
  begin
    Text.Add(p);
    p := PChar(MsgText.Next);
  end;
  Result := True;
end;

procedure TPassthr.Close;
begin
  { Nothing to close }
end;

function TPassthr.Delete(ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

function TPassthr.GetHWM(var ulMsg: LongWord): Boolean;
begin
  ulMsg := 0;
  Result := True;
end;

function TPassthr.Highest: LongWord;
begin
  Result := 0;
end;

function TPassthr.Lock(ulTimeout: LongWord): Boolean;
begin
  Result := True;
end;

function TPassthr.Lowest: LongWord;
begin
  Result := 0;
end;

function TPassthr.MsgnToUid(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TPassthr.New;
begin
  From_[0] := #0;
  To_[0] := #0;
  Subject_[0] := #0;
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
  FillChar(Written, SizeOf(Written), 0);
  Written.Month := 1;
  FillChar(Arrived, SizeOf(Arrived), 0);
  Arrived.Month := 1;
  Original := 0;
  Reply := 0;
  Text.Clear;
end;

function TPassthr.Next(var ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

function TPassthr.Number: LongWord;
begin
  Result := 0;
end;

procedure TPassthr.Pack;
begin
  { Nothing to pack }
end;

function TPassthr.Previous(var ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

function TPassthr.ReadHeader(ulMsg: LongWord): Boolean;
begin
  Result := True;
end;

function TPassthr.ReadMsgDefault(ulMsg: LongWord; nWidth: SmallInt): Boolean;
begin
  Result := ReadMsg(ulMsg, Text, nWidth);
end;

function TPassthr.ReadMsg(ulMsg: LongWord; var MsgText: TCollection; nWidth: SmallInt): Boolean;
begin
  Result := True;
end;

procedure TPassthr.SetHWM(ulMsg: LongWord);
begin
  { Nothing to do }
end;

function TPassthr.UidToMsgn(ulMsg: LongWord): LongWord;
begin
  Result := ulMsg;
end;

procedure TPassthr.UnLock;
begin
  { Nothing to do }
end;

function TPassthr.WriteHeader(ulMsg: LongWord): Boolean;
begin
  Result := False;
end;

end.
