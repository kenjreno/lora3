{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of address.cpp - TAddress class
  Manages FidoNet-style addresses (zone:net/node.point@domain).
  Stores address list in memory via TCollection, persists to address.dat.
}

unit Address;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc299, Collect;

type
  TAddress = class
  public
    Zone:    Word;
    Net:     Word;
    Node:    Word;
    Point:   Word;
    FakeNet: Word;
    Domain:  array[0..31] of Char;
    Str:     array[0..63] of Char;

    constructor Create; virtual;
    destructor Destroy; override;

    function  Add: SmallInt;
    function  Add(pszAddress: PChar): SmallInt;
    function  Add(usZone, usNet, usNode: Word; usPoint: Word = 0;
                  pszDomain: PChar = nil): SmallInt;
    procedure Clear;
    procedure Delete;
    function  First: SmallInt;
    function  Load(pszFile: PChar): Word;
    function  Merge(pszFile: PChar): Word;
    function  Next: SmallInt;
    procedure Parse(pszAddress: PChar);
    procedure Update;
    function  Save(pszFile: PChar): Word;

  private
    List: TCollection;
    procedure FormatString;
  end;

implementation

constructor TAddress.Create;
begin
  inherited Create;
  List := TCollection.Create;
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  FakeNet := 0;
  Domain[0] := #0;
  Str[0] := #0;
end;

destructor TAddress.Destroy;
begin
  List.Clear;
  List.Free;
  inherited Destroy;
end;

procedure TAddress.FormatString;
begin
  if Point <> 0 then
    StrPCopy(Str, Format('%u:%u/%u.%u', [Zone, Net, Node, Point]))
  else
    StrPCopy(Str, Format('%u:%u/%u', [Zone, Net, Node]));
  if Domain[0] <> #0 then
  begin
    StrCat(Str, '@');
    StrCat(Str, Domain);
  end;
end;

function TAddress.Add: SmallInt;
begin
  Result := Add(Zone, Net, Node, Point, Domain);
end;

function TAddress.Add(pszAddress: PChar): SmallInt;
var
  S: String;
  p, AtPos, DotPos, ColonPos, SlashPos: Integer;
begin
  Result := 0;
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  FakeNet := 0;
  Domain[0] := #0;

  if pszAddress = nil then
    Exit;

  S := StrPas(pszAddress);
  if S = '' then
    Exit;

  { Extract @domain first if present }
  AtPos := Pos('@', S);
  if AtPos > 0 then
  begin
    StrPCopy(Domain, Copy(S, AtPos + 1, Length(S) - AtPos));
    S := Copy(S, 1, AtPos - 1);
  end;

  { Parse zone:net/node.point }
  ColonPos := Pos(':', S);
  if ColonPos > 0 then
  begin
    Zone := Word(StrToIntDef(Copy(S, 1, ColonPos - 1), 0));
    System.Delete(S, 1, ColonPos);
  end;

  SlashPos := Pos('/', S);
  if SlashPos > 0 then
  begin
    Net := Word(StrToIntDef(Copy(S, 1, SlashPos - 1), 0));
    System.Delete(S, 1, SlashPos);
  end;

  { Check for .point }
  DotPos := Pos('.', S);
  if DotPos > 0 then
  begin
    Node := Word(StrToIntDef(Copy(S, 1, DotPos - 1), 0));
    Point := Word(StrToIntDef(Copy(S, DotPos + 1, Length(S) - DotPos), 0));
  end
  else
    Node := Word(StrToIntDef(S, 0));

  Result := Add(Zone, Net, Node, Point, Domain);
end;

function TAddress.Add(usZone, usNet, usNode: Word; usPoint: Word;
                      pszDomain: PChar): SmallInt;
var
  Addr: MAILADDRESS;
  Check: PMAILADDRESS;
begin
  Result := 1;

  { Check for duplicates }
  Check := PMAILADDRESS(List.First);
  while Check <> nil do
  begin
    if (Check^.Zone = usZone) and (Check^.Net = usNet) and
       (Check^.Node = usNode) and (Check^.Point = usPoint) then
    begin
      Result := 0;
      Exit;
    end;
    Check := PMAILADDRESS(List.Next);
  end;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.Zone := usZone;
  Addr.Net := usNet;
  Addr.Node := usNode;
  Addr.Point := usPoint;
  if pszDomain <> nil then
    StrCopy(Addr.Domain, pszDomain);

  Result := SmallInt(List.Add(@Addr, SizeOf(MAILADDRESS)));
end;

procedure TAddress.Clear;
begin
  List.Clear;
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  FakeNet := 0;
  Domain[0] := #0;
  Str[0] := #0;
end;

procedure TAddress.Delete;
begin
  List.Remove;
end;

function TAddress.First: SmallInt;
var
  Addr: PMAILADDRESS;
begin
  Result := 0;
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  FakeNet := 0;
  Domain[0] := #0;
  Str[0] := #0;

  Addr := PMAILADDRESS(List.First);
  if Addr <> nil then
  begin
    Zone := Addr^.Zone;
    Net := Addr^.Net;
    Node := Addr^.Node;
    Point := Addr^.Point;
    StrCopy(Domain, Addr^.Domain);
    FakeNet := Addr^.FakeNet;
    FormatString;
    Result := 1;
  end;
end;

function TAddress.Load(pszFile: PChar): Word;
begin
  List.Clear;
  Result := Merge(pszFile);
end;

function TAddress.Merge(pszFile: PChar): Word;
var
  fs: TFileStream;
  FilePath: String;
  Addr: MAILADDRESS;
begin
  Result := 0;
  FilePath := IncludeTrailingPathDelimiter(StrPas(pszFile)) + 'address.dat';

  if not FileExists(FilePath) then
    Exit;

  try
    fs := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
    try
      Result := 1;
      while fs.Read(Addr, SizeOf(MAILADDRESS)) = SizeOf(MAILADDRESS) do
        List.Add(@Addr, SizeOf(MAILADDRESS));
    finally
      fs.Free;
    end;
  except
    Result := 0;
  end;
end;

function TAddress.Next: SmallInt;
var
  Addr: PMAILADDRESS;
begin
  Result := 0;

  Addr := PMAILADDRESS(List.Next);
  if Addr <> nil then
  begin
    Zone := Addr^.Zone;
    Net := Addr^.Net;
    Node := Addr^.Node;
    Point := Addr^.Point;
    StrCopy(Domain, Addr^.Domain);
    FakeNet := Addr^.FakeNet;
    FormatString;
    Result := 1;
  end;
end;

procedure TAddress.Parse(pszAddress: PChar);
var
  S, Part: String;
  AtPos, DotPos, ColonPos, SlashPos: Integer;
begin
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  FakeNet := 0;
  Domain[0] := #0;

  if pszAddress = nil then
    Exit;

  S := StrPas(pszAddress);
  if S = '' then
    Exit;

  { Extract @domain first }
  AtPos := Pos('@', S);
  if AtPos > 0 then
  begin
    StrPCopy(Domain, Copy(S, AtPos + 1, Length(S) - AtPos));
    S := Copy(S, 1, AtPos - 1);
  end;

  { Parse zone:net/node.point with wildcard support }
  ColonPos := Pos(':', S);
  if ColonPos > 0 then
  begin
    Zone := Word(StrToIntDef(Copy(S, 1, ColonPos - 1), 0));
    System.Delete(S, 1, ColonPos);
  end;

  SlashPos := Pos('/', S);
  if SlashPos > 0 then
  begin
    Part := Copy(S, 1, SlashPos - 1);
    if SameText(Part, 'all') or (Part = '*') then
      Net := 65535
    else
      Net := Word(StrToIntDef(Part, 0));
    System.Delete(S, 1, SlashPos);
  end;

  { Check for .point }
  DotPos := Pos('.', S);
  if DotPos > 0 then
  begin
    Part := Copy(S, 1, DotPos - 1);
    if SameText(Part, 'all') or (Part = '*') then
      Node := 65535
    else
      Node := Word(StrToIntDef(Part, 0));
    Part := Copy(S, DotPos + 1, Length(S) - DotPos);
    if SameText(Part, 'all') or (Part = '*') then
      Point := 65535
    else
      Point := Word(StrToIntDef(Part, 0));
  end
  else
  begin
    if SameText(S, 'all') or (S = '*') then
    begin
      Node := 65535;
      if Net = 0 then
        Net := 65535;
    end
    else
      Node := Word(StrToIntDef(S, 0));
  end;

  FormatString;
end;

procedure TAddress.Update;
var
  Addr: PMAILADDRESS;
begin
  Addr := PMAILADDRESS(List.Value);
  if Addr <> nil then
  begin
    Addr^.Zone := Zone;
    Addr^.Net := Net;
    Addr^.Node := Node;
    Addr^.Point := Point;
    StrCopy(Addr^.Domain, Domain);
    Addr^.FakeNet := FakeNet;
  end;

  FormatString;
end;

function TAddress.Save(pszFile: PChar): Word;
var
  fs: TFileStream;
  FilePath: String;
  Addr: PMAILADDRESS;
begin
  Result := 0;
  FilePath := IncludeTrailingPathDelimiter(StrPas(pszFile)) + 'address.dat';

  try
    fs := TFileStream.Create(FilePath, fmCreate);
    try
      Result := 1;
      Addr := PMAILADDRESS(List.First);
      while Addr <> nil do
      begin
        fs.Write(Addr^, SizeOf(MAILADDRESS));
        Addr := PMAILADDRESS(List.Next);
      end;
    finally
      fs.Free;
    end;
  except
    Result := 0;
  end;
end;

end.
