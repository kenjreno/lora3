{
  FastWay BBS v1.0.0
  Test program for Address unit - TAddress FidoNet address handling
}

program test_address;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Defs, Struc299, Collect, Address;

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

procedure TestParse;
var
  Addr: TAddress;
begin
  WriteLn;
  WriteLn('=== Parse Tests ===');

  Addr := TAddress.Create;
  try
    { Full address with point }
    Addr.Parse(PChar('1:2320/105.1'));
    Check('Parse zone', Addr.Zone = 1);
    Check('Parse net', Addr.Net = 2320);
    Check('Parse node', Addr.Node = 105);
    Check('Parse point', Addr.Point = 1);
    Check('Parse formats string', StrPas(Addr.Str) = '1:2320/105.1');

    { Address without point }
    Addr.Parse(PChar('2:280/464'));
    Check('Parse no point: zone', Addr.Zone = 2);
    Check('Parse no point: net', Addr.Net = 280);
    Check('Parse no point: node', Addr.Node = 464);
    Check('Parse no point: point=0', Addr.Point = 0);
    Check('Parse no point: string', StrPas(Addr.Str) = '2:280/464');

    { Address with domain }
    Addr.Parse(PChar('1:2320/105@fidonet'));
    Check('Parse domain: zone', Addr.Zone = 1);
    Check('Parse domain: net', Addr.Net = 2320);
    Check('Parse domain: node', Addr.Node = 105);
    Check('Parse domain: string', Pos('@fidonet', StrPas(Addr.Str)) > 0);

    { Wildcard addresses }
    Addr.Parse(PChar('1:*/0'));
    Check('Parse wildcard net: net=65535', Addr.Net = 65535);

    Addr.Parse(PChar('1:2320/*'));
    Check('Parse wildcard node: node=65535', Addr.Node = 65535);

    Addr.Parse(PChar('1:all/all'));
    Check('Parse all net: net=65535', Addr.Net = 65535);
    Check('Parse all node: node=65535', Addr.Node = 65535);

    { Empty / nil }
    Addr.Parse(PChar(''));
    Check('Parse empty: zone=0', Addr.Zone = 0);

    Addr.Parse(nil);
    Check('Parse nil: zone=0', Addr.Zone = 0);
  finally
    Addr.Free;
  end;
end;

procedure TestAddAndNavigate;
var
  Addr: TAddress;
begin
  WriteLn;
  WriteLn('=== Add and Navigate Tests ===');

  Addr := TAddress.Create;
  try
    { Add three addresses }
    Check('Add 1st returns 1', Addr.Add(PChar('1:2320/105')) = 1);
    Check('Add 2nd returns 1', Addr.Add(PChar('2:280/464')) = 1);
    Check('Add 3rd returns 1', Addr.Add(PChar('3:633/260')) = 1);

    { Navigate forward }
    Check('First returns 1', Addr.First = 1);
    Check('First is 1:2320/105', (Addr.Zone = 1) and (Addr.Net = 2320) and (Addr.Node = 105));

    Check('Next returns 1', Addr.Next = 1);
    Check('Second is 2:280/464', (Addr.Zone = 2) and (Addr.Net = 280) and (Addr.Node = 464));

    Check('Next returns 1', Addr.Next = 1);
    Check('Third is 3:633/260', (Addr.Zone = 3) and (Addr.Net = 633) and (Addr.Node = 260));

    Check('Next past end returns 0', Addr.Next = 0);
  finally
    Addr.Free;
  end;
end;

procedure TestDuplicateDetection;
var
  Addr: TAddress;
begin
  WriteLn;
  WriteLn('=== Duplicate Detection Tests ===');

  Addr := TAddress.Create;
  try
    Check('First add returns 1', Addr.Add(PChar('1:2320/105')) = 1);
    Check('Duplicate add returns 0', Addr.Add(PChar('1:2320/105')) = 0);
    Check('Different addr returns 1', Addr.Add(PChar('1:2320/106')) = 1);
  finally
    Addr.Free;
  end;
end;

procedure TestClearAndDelete;
var
  Addr: TAddress;
begin
  WriteLn;
  WriteLn('=== Clear and Delete Tests ===');

  Addr := TAddress.Create;
  try
    Addr.Add(PChar('1:2320/105'));
    Addr.Add(PChar('2:280/464'));

    Addr.Clear;
    Check('After clear First returns 0', Addr.First = 0);
    Check('After clear Zone=0', Addr.Zone = 0);

    { Add again after clear }
    Check('Add after clear works', Addr.Add(PChar('3:633/260')) = 1);
    Check('First after re-add works', Addr.First = 1);
    Check('Re-added addr correct', Addr.Zone = 3);
  finally
    Addr.Free;
  end;
end;

procedure TestSaveAndLoad;
var
  Addr, Addr2: TAddress;
  TmpDir: String;
begin
  WriteLn;
  WriteLn('=== Save and Load Tests ===');

  TmpDir := GetTempDir(False) + 'fwbbs_test_addr';
  ForceDirectories(TmpDir);

  Addr := TAddress.Create;
  Addr2 := TAddress.Create;
  try
    { Add addresses and save }
    Addr.Add(PChar('1:2320/105'));
    Addr.Add(PChar('2:280/464'));
    Addr.Add(PChar('3:633/260.5'));
    Check('Save returns 1', Addr.Save(PChar(TmpDir)) = 1);
    Check('address.dat exists', FileExists(TmpDir + DirectorySeparator + 'address.dat'));

    { Load into fresh object }
    Check('Load returns 1', Addr2.Load(PChar(TmpDir)) = 1);

    Addr2.First;
    Check('Loaded 1st zone', Addr2.Zone = 1);
    Check('Loaded 1st net', Addr2.Net = 2320);
    Check('Loaded 1st node', Addr2.Node = 105);

    Addr2.Next;
    Check('Loaded 2nd zone', Addr2.Zone = 2);
    Check('Loaded 2nd net', Addr2.Net = 280);

    Addr2.Next;
    Check('Loaded 3rd zone', Addr2.Zone = 3);
    Check('Loaded 3rd node', Addr2.Node = 260);
    Check('Loaded 3rd point', Addr2.Point = 5);
  finally
    Addr.Free;
    Addr2.Free;
    { Cleanup }
    DeleteFile(TmpDir + DirectorySeparator + 'address.dat');
    RemoveDir(TmpDir);
  end;
end;

procedure TestUpdate;
var
  Addr: TAddress;
begin
  WriteLn;
  WriteLn('=== Update Tests ===');

  Addr := TAddress.Create;
  try
    Addr.Add(PChar('1:2320/105'));
    Addr.First;

    { Modify current and update }
    Addr.Node := 999;
    Addr.Update;

    { Re-read to verify }
    Addr.First;
    Check('Update changes node', Addr.Node = 999);
    Check('Update preserves zone', Addr.Zone = 1);
    Check('Update preserves net', Addr.Net = 2320);
  finally
    Addr.Free;
  end;
end;

procedure TestAddVariants;
var
  Addr: TAddress;
begin
  WriteLn;
  WriteLn('=== Add Variant Tests ===');

  Addr := TAddress.Create;
  try
    { Add by components }
    Check('Add(zone,net,node) returns 1', Addr.Add(1, 2320, 105) = 1);
    Addr.First;
    Check('Add components: zone', Addr.Zone = 1);
    Check('Add components: net', Addr.Net = 2320);
    Check('Add components: node', Addr.Node = 105);

    { Add with point }
    Check('Add(z,n,n,p) returns 1', Addr.Add(2, 280, 464, 3) = 1);

    { Add current (copies Zone/Net/Node/Point fields) }
    Addr.Zone := 4;
    Addr.Net := 100;
    Addr.Node := 200;
    Addr.Point := 0;
    Check('Add current returns 1', Addr.Add = 1);
  finally
    Addr.Free;
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn;
  WriteLn('FastWay BBS - Address Unit Test Suite');
  WriteLn('=====================================');

  TestParse;
  TestAddAndNavigate;
  TestDuplicateDetection;
  TestClearAndDelete;
  TestSaveAndLoad;
  TestUpdate;
  TestAddVariants;

  WriteLn;
  WriteLn('=====================================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
