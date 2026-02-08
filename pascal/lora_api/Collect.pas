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

  FreePascal conversion of collect.h / collect.cpp
}

unit Collect;

{$MODE OBJFPC}
{$H+}

interface

uses
  Defs;

type
  PLDATA = ^LDATA;
  LDATA = record
    Previous: PLDATA;
    Next:     PLDATA;
    Value:    Pointer;
    Data:     array[0..0] of Char;
  end;

  TCollection = class
  public
    Elements: Word;

    constructor Create;
    destructor Destroy; override;

    function  Add(lpData: Pointer): Word; overload;
    function  Add(lpData: PChar): Word; overload;
    function  Add(lpData: Pointer; usSize: Word): Word; overload;
    procedure Clear;
    function  First: Pointer;
    function  Insert(lpData: Pointer): Word; overload;
    function  Insert(lpData: PChar): Word; overload;
    function  Insert(lpData: Pointer; usSize: Word): Word; overload;
    function  Last: Pointer;
    function  Next: Pointer;
    function  Previous: Pointer;
    procedure Remove;
    function  Replace(lpData: Pointer): Word; overload;
    function  Replace(lpData: PChar): Word; overload;
    function  Replace(lpData: Pointer; usSize: Word): Word; overload;
    function  Value: Pointer;

  private
    List: PLDATA;
  end;

implementation

{ TCollection }

constructor TCollection.Create;
begin
  inherited Create;
  List := nil;
  Elements := 0;
end;

destructor TCollection.Destroy;
begin
  while List <> nil do
    Remove;
  inherited Destroy;
end;

function TCollection.Add(lpData: Pointer): Word;
var
  NewNode: PLDATA;
begin
  Result := 0;
  NewNode := GetMem(SizeOf(LDATA));
  if NewNode <> nil then
  begin
    FillChar(NewNode^, SizeOf(LDATA), 0);
    NewNode^.Value := lpData;

    if List <> nil then
    begin
      while List^.Next <> nil do
        List := List^.Next;

      NewNode^.Previous := List;
      NewNode^.Next := List^.Next;
      if NewNode^.Next <> nil then
        NewNode^.Next^.Previous := NewNode;
      List^.Next := NewNode;
    end;

    Inc(Elements);
    List := NewNode;
    Result := 1;
  end;
end;

function TCollection.Add(lpData: PChar): Word;
begin
  Result := Add(Pointer(lpData), Word(StrLen(lpData) + 1));
end;

function TCollection.Add(lpData: Pointer; usSize: Word): Word;
var
  NewNode: PLDATA;
  AllocSize: LongWord;
begin
  Result := 0;
  AllocSize := SizeOf(LDATA) + usSize;
  NewNode := GetMem(AllocSize);
  if NewNode <> nil then
  begin
    FillChar(NewNode^, AllocSize, 0);
    Move(lpData^, NewNode^.Data[0], usSize);
    NewNode^.Value := @NewNode^.Data[0];

    if List <> nil then
    begin
      while List^.Next <> nil do
        List := List^.Next;

      NewNode^.Previous := List;
      NewNode^.Next := List^.Next;
      if NewNode^.Next <> nil then
        NewNode^.Next^.Previous := NewNode;
      List^.Next := NewNode;
    end;

    Inc(Elements);
    List := NewNode;
    Result := 1;
  end;
end;

procedure TCollection.Clear;
begin
  while List <> nil do
    Remove;
  Elements := 0;
end;

function TCollection.First: Pointer;
begin
  Result := nil;
  if List <> nil then
  begin
    while List^.Previous <> nil do
      List := List^.Previous;
    Result := List^.Value;
  end;
end;

function TCollection.Insert(lpData: Pointer): Word;
var
  NewNode: PLDATA;
begin
  Result := 0;
  NewNode := GetMem(SizeOf(LDATA));
  if NewNode <> nil then
  begin
    FillChar(NewNode^, SizeOf(LDATA), 0);
    NewNode^.Value := lpData;

    if List <> nil then
    begin
      NewNode^.Previous := List;
      NewNode^.Next := List^.Next;
      if NewNode^.Next <> nil then
        NewNode^.Next^.Previous := NewNode;
      List^.Next := NewNode;
    end;

    Inc(Elements);
    List := NewNode;
    Result := 1;
  end;
end;

function TCollection.Insert(lpData: PChar): Word;
begin
  Result := Insert(Pointer(lpData), Word(StrLen(lpData) + 1));
end;

function TCollection.Insert(lpData: Pointer; usSize: Word): Word;
var
  NewNode: PLDATA;
  AllocSize: LongWord;
begin
  Result := 0;
  AllocSize := SizeOf(LDATA) + usSize;
  NewNode := GetMem(AllocSize);
  if NewNode <> nil then
  begin
    FillChar(NewNode^, AllocSize, 0);
    Move(lpData^, NewNode^.Data[0], usSize);
    NewNode^.Value := @NewNode^.Data[0];

    if List <> nil then
    begin
      NewNode^.Previous := List;
      NewNode^.Next := List^.Next;
      if NewNode^.Next <> nil then
        NewNode^.Next^.Previous := NewNode;
      List^.Next := NewNode;
    end;

    Inc(Elements);
    List := NewNode;
    Result := 1;
  end;
end;

function TCollection.Last: Pointer;
begin
  Result := nil;
  if List <> nil then
  begin
    while List^.Next <> nil do
      List := List^.Next;
    Result := List^.Value;
  end;
end;

function TCollection.Next: Pointer;
begin
  Result := nil;
  if List <> nil then
  begin
    if List^.Next <> nil then
    begin
      List := List^.Next;
      Result := List^.Value;
    end;
  end;
end;

function TCollection.Previous: Pointer;
begin
  Result := nil;
  if List <> nil then
  begin
    if List^.Previous <> nil then
    begin
      List := List^.Previous;
      Result := List^.Value;
    end;
  end;
end;

procedure TCollection.Remove;
var
  Temp: PLDATA;
begin
  if List <> nil then
  begin
    if List^.Previous <> nil then
      List^.Previous^.Next := List^.Next;
    if List^.Next <> nil then
      List^.Next^.Previous := List^.Previous;
    Temp := List;
    if List^.Next <> nil then
      List := List^.Next
    else if List^.Previous <> nil then
      List := List^.Previous
    else
      List := nil;
    FreeMem(Temp);
    Dec(Elements);
  end;
end;

function TCollection.Replace(lpData: Pointer): Word;
var
  NewNode: PLDATA;
begin
  Result := 0;
  if List <> nil then
  begin
    NewNode := GetMem(SizeOf(LDATA));
    if NewNode <> nil then
    begin
      FillChar(NewNode^, SizeOf(LDATA), 0);
      NewNode^.Value := lpData;
      NewNode^.Next := List^.Next;
      NewNode^.Previous := List^.Previous;

      if NewNode^.Next <> nil then
        NewNode^.Next^.Previous := NewNode;
      if NewNode^.Previous <> nil then
        NewNode^.Previous^.Next := NewNode;

      FreeMem(List);
      List := NewNode;
      Result := 1;
    end;
  end;
end;

function TCollection.Replace(lpData: PChar): Word;
begin
  Result := Replace(Pointer(lpData), Word(StrLen(lpData) + 1));
end;

function TCollection.Replace(lpData: Pointer; usSize: Word): Word;
var
  NewNode: PLDATA;
  AllocSize: LongWord;
begin
  Result := 0;
  if List <> nil then
  begin
    AllocSize := SizeOf(LDATA) + usSize;
    NewNode := GetMem(AllocSize);
    if NewNode <> nil then
    begin
      FillChar(NewNode^, AllocSize, 0);
      Move(lpData^, NewNode^.Data[0], usSize);
      NewNode^.Value := @NewNode^.Data[0];
      NewNode^.Next := List^.Next;
      NewNode^.Previous := List^.Previous;

      if NewNode^.Next <> nil then
        NewNode^.Next^.Previous := NewNode;
      if NewNode^.Previous <> nil then
        NewNode^.Previous^.Next := NewNode;

      FreeMem(List);
      List := NewNode;
      Result := 1;
    end;
  end;
end;

function TCollection.Value: Pointer;
begin
  if List = nil then
    Result := nil
  else
    Result := List^.Value;
end;

end.
