{
  FastWay BBS v1.0.0
  Test program for Collect unit - TCollection linked list
}

program test_collect;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Defs, Collect;

var
  TestsPassed, TestsFailed: Integer;

procedure Check(const TestName: String; Condition: Boolean);
begin
  if Condition then
  begin
    WriteLn('  PASS: ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('  FAIL: ', TestName);
    Inc(TestsFailed);
  end;
end;

procedure TestEmptyCollection;
var
  C: TCollection;
begin
  WriteLn;
  WriteLn('=== Empty Collection Tests ===');

  C := TCollection.Create;
  try
    Check('New collection has 0 elements', C.Elements = 0);
    Check('First on empty returns nil', C.First = nil);
    Check('Last on empty returns nil', C.Last = nil);
    Check('Next on empty returns nil', C.Next = nil);
    Check('Previous on empty returns nil', C.Previous = nil);
    Check('Value on empty returns nil', C.Value = nil);
  finally
    C.Free;
  end;
end;

procedure TestAddPointer;
var
  C: TCollection;
  A, B, D: LongWord;
  P: PLongWord;
begin
  WriteLn;
  WriteLn('=== Add Pointer Tests ===');

  A := $DEADBEEF;
  B := $CAFEBABE;
  D := $12345678;

  C := TCollection.Create;
  try
    Check('Add returns 1', C.Add(@A) = 1);
    Check('Elements = 1 after add', C.Elements = 1);

    Check('Add second returns 1', C.Add(@B) = 1);
    Check('Elements = 2', C.Elements = 2);

    Check('Add third returns 1', C.Add(@D) = 1);
    Check('Elements = 3', C.Elements = 3);

    { Navigate }
    P := PLongWord(C.First);
    Check('First returns first item', (P <> nil) and (P^ = $DEADBEEF));

    P := PLongWord(C.Next);
    Check('Next returns second item', (P <> nil) and (P^ = $CAFEBABE));

    P := PLongWord(C.Next);
    Check('Next returns third item', (P <> nil) and (P^ = $12345678));

    Check('Next past end returns nil', C.Next = nil);

    { Reverse navigation }
    P := PLongWord(C.Last);
    Check('Last returns third item', (P <> nil) and (P^ = $12345678));

    P := PLongWord(C.Previous);
    Check('Previous returns second item', (P <> nil) and (P^ = $CAFEBABE));

    P := PLongWord(C.Previous);
    Check('Previous returns first item', (P <> nil) and (P^ = $DEADBEEF));

    Check('Previous past start returns nil', C.Previous = nil);
  finally
    C.Free;
  end;
end;

procedure TestAddString;
var
  C: TCollection;
  P: PChar;
begin
  WriteLn;
  WriteLn('=== Add String (PChar) Tests ===');

  C := TCollection.Create;
  try
    Check('Add string returns 1', C.Add(PChar('Hello')) = 1);
    Check('Add string returns 1', C.Add(PChar('World')) = 1);
    Check('Add string returns 1', C.Add(PChar('Test')) = 1);
    Check('Elements = 3', C.Elements = 3);

    { Strings are COPIED into the collection }
    P := PChar(C.First);
    Check('First string is Hello', (P <> nil) and (StrComp(P, 'Hello') = 0));

    P := PChar(C.Next);
    Check('Second string is World', (P <> nil) and (StrComp(P, 'World') = 0));

    P := PChar(C.Next);
    Check('Third string is Test', (P <> nil) and (StrComp(P, 'Test') = 0));

    Check('Next past end nil', C.Next = nil);
  finally
    C.Free;
  end;
end;

procedure TestAddData;
var
  C: TCollection;
  Data1, Data2: LongWord;
  P: PLongWord;
begin
  WriteLn;
  WriteLn('=== Add Data (Copy) Tests ===');

  Data1 := $11223344;
  Data2 := $55667788;

  C := TCollection.Create;
  try
    Check('Add data returns 1', C.Add(@Data1, SizeOf(Data1)) = 1);
    Check('Add data returns 1', C.Add(@Data2, SizeOf(Data2)) = 1);

    { Data should be copied, so changing originals doesn't affect collection }
    Data1 := $AAAAAAAA;
    Data2 := $BBBBBBBB;

    P := PLongWord(C.First);
    Check('First data is original value', (P <> nil) and (P^ = $11223344));

    P := PLongWord(C.Next);
    Check('Second data is original value', (P <> nil) and (P^ = $55667788));
  finally
    C.Free;
  end;
end;

procedure TestInsert;
var
  C: TCollection;
  P: PChar;
begin
  WriteLn;
  WriteLn('=== Insert Tests ===');

  C := TCollection.Create;
  try
    { Add first and second }
    C.Add(PChar('First'));
    C.Add(PChar('Third'));

    { Navigate to first, then insert after it }
    C.First;
    C.Insert(PChar('Second'));

    { Verify order: First, Second, Third }
    P := PChar(C.First);
    Check('After insert, first is First', (P <> nil) and (StrComp(P, 'First') = 0));

    P := PChar(C.Next);
    Check('After insert, second is Second', (P <> nil) and (StrComp(P, 'Second') = 0));

    P := PChar(C.Next);
    Check('After insert, third is Third', (P <> nil) and (StrComp(P, 'Third') = 0));

    Check('Elements = 3', C.Elements = 3);
  finally
    C.Free;
  end;
end;

procedure TestRemove;
var
  C: TCollection;
  P: PChar;
begin
  WriteLn;
  WriteLn('=== Remove Tests ===');

  C := TCollection.Create;
  try
    C.Add(PChar('Alpha'));
    C.Add(PChar('Beta'));
    C.Add(PChar('Gamma'));
    Check('Elements = 3 before remove', C.Elements = 3);

    { Navigate to middle and remove it }
    C.First;
    C.Next;
    C.Remove;
    Check('Elements = 2 after remove', C.Elements = 2);

    { Verify remaining: Alpha, Gamma }
    P := PChar(C.First);
    Check('First after remove is Alpha', (P <> nil) and (StrComp(P, 'Alpha') = 0));

    P := PChar(C.Next);
    Check('Second after remove is Gamma', (P <> nil) and (StrComp(P, 'Gamma') = 0));

    Check('No more after Gamma', C.Next = nil);
  finally
    C.Free;
end;

  { Test remove from single element list }
  C := TCollection.Create;
  try
    C.Add(PChar('Only'));
    C.First;
    C.Remove;
    Check('Remove single: Elements = 0', C.Elements = 0);
    Check('Remove single: First nil', C.First = nil);
  finally
    C.Free;
  end;

  { Test remove first element }
  C := TCollection.Create;
  try
    C.Add(PChar('First'));
    C.Add(PChar('Second'));
    C.First;
    C.Remove;
    Check('Remove first: Elements = 1', C.Elements = 1);

    P := PChar(C.First);
    Check('Remove first: remaining is Second', (P <> nil) and (StrComp(P, 'Second') = 0));
  finally
    C.Free;
  end;

  { Test remove last element }
  C := TCollection.Create;
  try
    C.Add(PChar('First'));
    C.Add(PChar('Second'));
    C.Last;
    C.Remove;
    Check('Remove last: Elements = 1', C.Elements = 1);

    P := PChar(C.First);
    Check('Remove last: remaining is First', (P <> nil) and (StrComp(P, 'First') = 0));
  finally
    C.Free;
  end;
end;

procedure TestClear;
var
  C: TCollection;
begin
  WriteLn;
  WriteLn('=== Clear Tests ===');

  C := TCollection.Create;
  try
    C.Add(PChar('One'));
    C.Add(PChar('Two'));
    C.Add(PChar('Three'));
    Check('Elements = 3 before clear', C.Elements = 3);

    C.Clear;
    Check('Elements = 0 after clear', C.Elements = 0);
    Check('First nil after clear', C.First = nil);

    { Can add again after clear }
    C.Add(PChar('New'));
    Check('Elements = 1 after re-add', C.Elements = 1);
    Check('First after re-add works', PChar(C.First) <> nil);
  finally
    C.Free;
  end;
end;

procedure TestReplace;
var
  C: TCollection;
  P: PChar;
begin
  WriteLn;
  WriteLn('=== Replace Tests ===');

  C := TCollection.Create;
  try
    C.Add(PChar('Original'));
    C.Add(PChar('Keep'));

    { Replace first element }
    C.First;
    C.Replace(PChar('Replaced'));

    P := PChar(C.First);
    Check('Replace changes value', (P <> nil) and (StrComp(P, 'Replaced') = 0));

    P := PChar(C.Next);
    Check('Replace keeps other elements', (P <> nil) and (StrComp(P, 'Keep') = 0));

    Check('Elements unchanged', C.Elements = 2);
  finally
    C.Free;
  end;
end;

procedure TestLargeCollection;
var
  C: TCollection;
  i: Integer;
  P: PChar;
  S: String;
begin
  WriteLn;
  WriteLn('=== Large Collection Tests ===');

  C := TCollection.Create;
  try
    for i := 0 to 99 do
    begin
      S := Format('Item %d', [i]);
      C.Add(PChar(S));
    end;
    Check('100 elements added', C.Elements = 100);

    P := PChar(C.First);
    Check('First of 100 is Item 0', (P <> nil) and (StrComp(P, 'Item 0') = 0));

    P := PChar(C.Last);
    Check('Last of 100 is Item 99', (P <> nil) and (StrComp(P, 'Item 99') = 0));

    { Walk forward and count }
    i := 0;
    P := PChar(C.First);
    while P <> nil do
    begin
      Inc(i);
      P := PChar(C.Next);
    end;
    Check('Forward walk counts 100', i = 100);

    { Walk backward and count }
    i := 0;
    P := PChar(C.Last);
    while P <> nil do
    begin
      Inc(i);
      P := PChar(C.Previous);
    end;
    Check('Backward walk counts 100', i = 100);
  finally
    C.Free;
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn;
  WriteLn('FastWay BBS - Collect Unit Test Suite');
  WriteLn('=====================================');

  TestEmptyCollection;
  TestAddPointer;
  TestAddString;
  TestAddData;
  TestInsert;
  TestRemove;
  TestClear;
  TestReplace;
  TestLargeCollection;

  WriteLn;
  WriteLn('=====================================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
