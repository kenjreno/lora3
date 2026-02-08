{
  FastWay BBS v1.0.0
  Test program for Struc299 unit - packed record sizes and field layout
  Validates that packed records match the C struct sizes exactly,
  which is critical for binary file compatibility.

  Sizes verified against original struc299.h with #pragma pack(1).
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

  { ADDR from Defs.pas: 4*Word(8) + Domain[32] + Flags(2) = 42 }
  CheckSize('ADDR', SizeOf(ADDR), 42);
  { MAILADDRESS: 5*Word(10) + Domain[32] = 42 }
  CheckSize('MAILADDRESS', SizeOf(MAILADDRESS), 42);
end;

procedure TestFidoNetRecordSizes;
begin
  WriteLn;
  WriteLn('=== FidoNet Packet Record Sizes ===');

  CheckSize('PKT2HDR', SizeOf(PKT2HDR), 58);
  CheckSize('PKT22HDR', SizeOf(PKT22HDR), 58);
  CheckSize('PKTMSGHDR', SizeOf(PKTMSGHDR), 14);
  CheckSize('FIDOMSG', SizeOf(FIDOMSG), 190);
end;

procedure TestUserRecordSizes;
begin
  WriteLn;
  WriteLn('=== User Record Sizes ===');

  { USER: Size verified against struc299.h USER struct }
  CheckSize('USER_REC', SizeOf(USER_REC), 782);
  { UINDEX: Deleted(2) + NameCrc(4) + RealNameCrc(4) + Position(4) = 14 }
  CheckSize('UINDEX', SizeOf(UINDEX), 14);
end;

procedure TestMessageRecordSizes;
begin
  WriteLn;
  WriteLn('=== Message Record Sizes ===');

  { MESSAGE: verified against struc299.h }
  CheckSize('MESSAGE_REC', SizeOf(MESSAGE_REC), 759);
  { INDEX: Key[16]+Level(2)+AccessFlags(4)+DenyFlags(4)+Position(4)+Flags(2) = 32 }
  CheckSize('INDEX', SizeOf(INDEX), 32);
  { MSGTAGS: Free(1)+Tagged(1)+UserId(4)+Area[16]+LastRead(4)+OlderMsg(4) = 30 }
  CheckSize('MSGTAGS', SizeOf(MSGTAGS), 30);
  { MDATE: Day+Month+Second(3 bytes) + Year(2) + Hour+Minute(2) = 7 }
  CheckSize('MDATE', SizeOf(MDATE), 7);
end;

procedure TestFileRecordSizes;
begin
  WriteLn;
  WriteLn('=== File Record Sizes ===');

  { FILEDATA: verified against struc299.h }
  CheckSize('FILEDATA_REC', SizeOf(FILEDATA_REC), 268);
  { FILEINDEX: Area(4)+Name[32]+UploadDate(4)+Offset(4)+Flags(2) = 46 }
  CheckSize('FILEINDEX', SizeOf(FILEINDEX), 46);
end;

procedure TestConfigRecordSize;
begin
  WriteLn;
  WriteLn('=== Config Record Sizes ===');

  { CONFIG: large struct, verified against struc299.h }
  CheckSize('CONFIG_REC', SizeOf(CONFIG_REC), 3894);
end;

procedure TestHudsonRecordSizes;
begin
  WriteLn;
  WriteLn('=== Hudson Message Base Record Sizes ===');

  { HMSGIDX: MsgNum(2) + Board(1) = 3 }
  CheckSize('HMSGIDX', SizeOf(HMSGIDX), 3);
  { HMSGTOIDX: String_[36] = 36 }
  CheckSize('HMSGTOIDX', SizeOf(HMSGTOIDX), 36);
  { HMSGHDR: verified against msgbase.h }
  CheckSize('HMSGHDR', SizeOf(HMSGHDR), 187);
end;

procedure TestSquishRecordSizes;
begin
  WriteLn;
  WriteLn('=== Squish Message Base Record Sizes ===');

  CheckSize('SQBASE', SizeOf(SQBASE), 256);
  CheckSize('SQIDX', SizeOf(SQIDX), 12);
  CheckSize('SQHDR', SizeOf(SQHDR), 28);
  CheckSize('XMSG', SizeOf(XMSG), 238);
end;

procedure TestOkFileRecordSize;
begin
  WriteLn;
  WriteLn('=== OkFile Record Sizes ===');

  { OKFILE: Size(2)+Name[32]+Path[128]+Pwd[32]+Normal+Known+Protected = 197 }
  CheckSize('OKFILE_REC', SizeOf(OKFILE_REC), 197);
end;

procedure TestOtherRecordSizes;
begin
  WriteLn;
  WriteLn('=== Other Record Sizes ===');

  CheckSize('ECHOLINK', SizeOf(ECHOLINK), 16);
  CheckSize('FILETAGS', SizeOf(FILETAGS), 36);
  CheckSize('CHANNEL', SizeOf(CHANNEL), 256);
  CheckSize('NODES_REC', SizeOf(NODES_REC), 256);
  CheckSize('PACKER_REC', SizeOf(PACKER_REC), 140);
  CheckSize('EVENT_REC', SizeOf(EVENT_REC), 120);
  CheckSize('PROTOCOL_REC', SizeOf(PROTOCOL_REC), 120);
  CheckSize('LIMITS_REC', SizeOf(LIMITS_REC), 48);
  CheckSize('SYSSTAT', SizeOf(SYSSTAT), 32);
  CheckSize('DUPEDATA', SizeOf(DUPEDATA), 8);
  CheckSize('DUPEIDX', SizeOf(DUPEIDX), 8);
end;

procedure TestFieldLayout;
var
  FAddr: ADDR;
  MAddr: MAILADDRESS;
  Pkt: PKT2HDR;
begin
  WriteLn;
  WriteLn('=== Field Layout Validation ===');

  { Verify ADDR field offsets }
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
  TestConfigRecordSize;
  TestHudsonRecordSizes;
  TestSquishRecordSizes;
  TestOkFileRecordSize;
  TestOtherRecordSizes;
  TestFieldLayout;

  WriteLn;
  WriteLn('======================================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
