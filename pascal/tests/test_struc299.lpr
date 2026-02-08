{
  FastWay BBS v1.0.0
  Test program for Struc299 unit - packed record sizes and field layout
  Validates that packed records match the C struct sizes exactly,
  which is critical for binary file compatibility.
}

program test_struc299;

{$MODE OBJFPC}
{$H+}
{$PACKRECORDS 1}

uses
  SysUtils, Defs, Struc299;

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

procedure CheckSize(const TypeName: String; Actual, Expected: Integer);
begin
  if Actual = Expected then
  begin
    WriteLn(Format('  PASS: SizeOf(%s) = %d', [TypeName, Actual]));
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn(Format('  FAIL: SizeOf(%s) = %d, expected %d', [TypeName, Actual, Expected]));
    Inc(TestsFailed);
  end;
end;

procedure TestCommonRecordSizes;
begin
  WriteLn;
  WriteLn('=== Common Record Sizes ===');

  { ADDR from Defs.pas }
  CheckSize('ADDR', SizeOf(ADDR), 40);  { 4*Word(8) + Domain[32] }
  CheckSize('MAILADDRESS', SizeOf(MAILADDRESS), 42); { 5*Word(10) + Domain[32] }
end;

procedure TestFidoNetRecordSizes;
begin
  WriteLn;
  WriteLn('=== FidoNet Packet Record Sizes ===');

  { PKT2HDR - FTS-0001 Type 2 packet header }
  CheckSize('PKT2HDR', SizeOf(PKT2HDR), 58);
  { PKT22HDR - FSC-0048 Type 2.2 extension }
  CheckSize('PKT22HDR', SizeOf(PKT22HDR), 58);
  { PKTMSGHDR - packed message header in .PKT }
  CheckSize('PKTMSGHDR', SizeOf(PKTMSGHDR), 14);
end;

procedure TestUserRecordSizes;
begin
  WriteLn;
  WriteLn('=== User Record Sizes ===');

  { USER_REC - main user data record }
  { The C struct is 864 bytes }
  CheckSize('USER_REC', SizeOf(USER_REC), 864);
  { UINDEX - user index record }
  CheckSize('UINDEX', SizeOf(UINDEX), 8);
end;

procedure TestMessageRecordSizes;
begin
  WriteLn;
  WriteLn('=== Message Record Sizes ===');

  { MESSAGE_REC - message area data }
  CheckSize('MESSAGE_REC', SizeOf(MESSAGE_REC), 512);
  { MSGINDEX - message area index }
  CheckSize('INDEX', SizeOf(INDEX), 4);
  { MSGTAGS - last-read tags }
  CheckSize('MSGTAGS', SizeOf(MSGTAGS), 48);
  { MDATE - message date }
  CheckSize('MDATE', SizeOf(MDATE), 7);
end;

procedure TestFileRecordSizes;
begin
  WriteLn;
  WriteLn('=== File Record Sizes ===');

  { FILEDATA_REC }
  CheckSize('FILEDATA_REC', SizeOf(FILEDATA_REC), 512);
  { FILEINDEX }
  CheckSize('FILEINDEX', SizeOf(FILEINDEX), 4);
end;

procedure TestConfigRecordSizes;
begin
  WriteLn;
  WriteLn('=== Config Record Sizes ===');

  { CONFIG_REC - main system config }
  CheckSize('CONFIG_REC', SizeOf(CONFIG_REC), 8192);
end;

procedure TestHudsonRecordSizes;
begin
  WriteLn;
  WriteLn('=== Hudson Message Base Record Sizes ===');

  { HMSGIDX - Hudson message index }
  CheckSize('HMSGIDX', SizeOf(HMSGIDX), 5);
  { HMSGTOIDX - Hudson to-name index }
  CheckSize('HMSGTOIDX', SizeOf(HMSGTOIDX), 36);
  { HMSGHDR - Hudson message header }
  CheckSize('HMSGHDR', SizeOf(HMSGHDR), 249);
end;

procedure TestSquishRecordSizes;
begin
  WriteLn;
  WriteLn('=== Squish Message Base Record Sizes ===');

  { SQBASE - Squish base header }
  CheckSize('SQBASE', SizeOf(SQBASE), 256);
  { SQIDX - Squish index entry }
  CheckSize('SQIDX', SizeOf(SQIDX), 12);
  { SQHDR - Squish message frame header }
  CheckSize('SQHDR', SizeOf(SQHDR), 28);
  { XMSG - Squish message header }
  CheckSize('XMSG', SizeOf(XMSG), 238);
end;

procedure TestOkFileRecordSize;
begin
  WriteLn;
  WriteLn('=== OkFile Record Sizes ===');

  CheckSize('OKFILE_REC', SizeOf(OKFILE_REC), 195);
end;

procedure TestFieldLayout;
var
  FAddr: ADDR;
  MAddr: MAILADDRESS;
  Pkt: PKT2HDR;
begin
  WriteLn;
  WriteLn('=== Field Layout Validation ===');

  { Verify ADDR field offsets by filling and checking }
  FillChar(FAddr, SizeOf(FAddr), 0);
  FAddr.Zone := $1234;
  FAddr.Net := $5678;
  FAddr.Node := $9ABC;
  FAddr.Point := $DEF0;
  Check('ADDR.Zone at offset 0', PWord(@FAddr)^ = $1234);
  Check('ADDR.Net at offset 2', PWord(PByte(@FAddr) + 2)^ = $5678);
  Check('ADDR.Node at offset 4', PWord(PByte(@FAddr) + 4)^ = $9ABC);
  Check('ADDR.Point at offset 6', PWord(PByte(@FAddr) + 6)^ = $DEF0);

  { Verify PKT2HDR first fields }
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.OrigNode := $1111;
  Pkt.DestNode := $2222;
  Pkt.Year := $3333;
  Check('PKT2HDR.OrigNode at offset 0', PWord(@Pkt)^ = $1111);
  Check('PKT2HDR.DestNode at offset 2', PWord(PByte(@Pkt) + 2)^ = $2222);
  Check('PKT2HDR.Year at offset 4', PWord(PByte(@Pkt) + 4)^ = $3333);

  { Verify MAILADDRESS layout }
  FillChar(MAddr, SizeOf(MAddr), 0);
  MAddr.Zone := 1;
  MAddr.Net := 2320;
  MAddr.Node := 105;
  MAddr.Point := 0;
  StrCopy(MAddr.Domain, 'fidonet');
  MAddr.FakeNet := 9999;
  Check('MAILADDRESS.Zone at offset 0', MAddr.Zone = 1);
  Check('MAILADDRESS.FakeNet at offset 40', PWord(PByte(@MAddr) + 40)^ = 9999);
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn;
  WriteLn('FastWay BBS - Struc299 Unit Test Suite');
  WriteLn('======================================');
  WriteLn('Validates packed record sizes match C struct binary layout');

  TestCommonRecordSizes;
  TestFidoNetRecordSizes;
  TestUserRecordSizes;
  TestMessageRecordSizes;
  TestFileRecordSizes;
  TestConfigRecordSizes;
  TestHudsonRecordSizes;
  TestSquishRecordSizes;
  TestOkFileRecordSize;
  TestFieldLayout;

  WriteLn;
  WriteLn('======================================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
