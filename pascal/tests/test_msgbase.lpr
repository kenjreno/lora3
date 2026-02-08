{
  FastWay BBS v1.0.0
  Test program for msgbase units - JamMsg, Squish, FidoSdm, Hudson, Packet
  Tests message base creation, writing, reading, and navigation.
}

program test_msgbase;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Classes, DateUtils, Defs, Struc299, Jam, Collect,
  MsgBase, JamMsg, Squish, FidoSdm, Hudson, Packet, Dupes;

var
  TestsPassed, TestsFailed: Integer;
  TmpDir: String;

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

procedure SetupTmpDir;
begin
  TmpDir := GetTempDir(False) + 'fwbbs_test_msg';
  ForceDirectories(TmpDir);
end;

procedure CleanupTmpDir;
var
  SR: TSearchRec;
begin
  if FindFirst(TmpDir + DirectorySeparator + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
        DeleteFile(TmpDir + DirectorySeparator + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RemoveDir(TmpDir);
end;

{ Helper: write a test message to any msgbase }
procedure WriteTestMessage(Msg: TMsgBase; MsgNum: Integer);
var
  Text: TCollection;
  NowDT: TDateTime;
  yr, mo, dy, hr, mn, sc, ms: Word;
begin
  NowDT := Now;
  DecodeDate(NowDT, yr, mo, dy);
  DecodeTime(NowDT, hr, mn, sc, ms);

  StrCopy(Msg.From_, PChar(Format('Test Sender %d', [MsgNum])));
  StrCopy(Msg.To_, PChar(Format('Test Rcpt %d', [MsgNum])));
  StrCopy(Msg.Subject_, PChar(Format('Test Subject %d', [MsgNum])));

  Msg.Written.Year := yr;
  Msg.Written.Month := mo;
  Msg.Written.Day := dy;
  Msg.Written.Hour := hr;
  Msg.Written.Minute := mn;
  Msg.Written.Second := sc;

  Msg.Arrived := Msg.Written;

  Text := TCollection.Create;
  try
    Text.Add(PChar(Format('This is test message number %d.', [MsgNum])));
    Text.Add(PChar('Second line of text.'));
    Text.Add(PChar('--- Test Origin'));
    Msg.New_;
    Msg.WriteHeader(0);
    Msg.WriteText(Text);
  finally
    Text.Free;
  end;
end;

{ ---- JAM Tests ---- }

procedure TestJamMsg;
var
  Msg: TJamMsg;
  BasePath: String;
  Text: TCollection;
  P: PChar;
  Count: Integer;
begin
  WriteLn;
  WriteLn('=== JAM Message Base Tests ===');

  BasePath := TmpDir + DirectorySeparator + 'jamtest';

  Msg := TJamMsg.Create;
  try
    Check('JAM Open creates base', Msg.Open(BasePath));
    Check('JAM .jhr exists', FileExists(BasePath + '.jhr'));
    Check('JAM .jdt exists', FileExists(BasePath + '.jdt'));
    Check('JAM .jdx exists', FileExists(BasePath + '.jdx'));
    Check('JAM .jlr exists', FileExists(BasePath + '.jlr'));

    Check('JAM Number = 0 initially', Msg.Number = 0);

    { Write messages }
    WriteTestMessage(Msg, 1);
    WriteTestMessage(Msg, 2);
    WriteTestMessage(Msg, 3);

    Msg.Close;
  finally
    Msg.Free;
  end;

  { Re-open and read }
  Msg := TJamMsg.Create;
  try
    Check('JAM re-open', Msg.Open(BasePath));
    Check('JAM Number = 3', Msg.Number = 3);
    Check('JAM Lowest >= 1', Msg.Lowest >= 1);
    Check('JAM Highest >= 3', Msg.Highest >= 3);

    { Read first message }
    Check('JAM ReadHeader(Lowest)', Msg.ReadHeader(Msg.Lowest));
    Check('JAM From starts with Test Sender', Pos('Test Sender', StrPas(Msg.From_)) = 1);
    Check('JAM To starts with Test Rcpt', Pos('Test Rcpt', StrPas(Msg.To_)) = 1);
    Check('JAM Subject starts with Test Subject', Pos('Test Subject', StrPas(Msg.Subject_)) = 1);

    { Read text }
    Text := TCollection.Create;
    try
      Msg.ReadText(Text);
      Count := 0;
      P := PChar(Text.First);
      while P <> nil do
      begin
        Inc(Count);
        P := PChar(Text.Next);
      end;
      Check('JAM ReadText returns lines', Count > 0);
    finally
      Text.Free;
    end;

    { Navigate }
    Check('JAM Next from lowest', Msg.Next(Msg.Lowest));

    Msg.Close;
  finally
    Msg.Free;
  end;
end;

{ ---- Squish Tests ---- }

procedure TestSquish;
var
  Msg: TSquish;
  BasePath: String;
begin
  WriteLn;
  WriteLn('=== Squish Message Base Tests ===');

  BasePath := TmpDir + DirectorySeparator + 'sqtest';

  Msg := TSquish.Create;
  try
    Check('Squish Open creates base', Msg.Open(BasePath));
    Check('Squish .sqd exists', FileExists(BasePath + '.sqd'));
    Check('Squish .sqi exists', FileExists(BasePath + '.sqi'));

    Check('Squish Number = 0', Msg.Number = 0);

    WriteTestMessage(Msg, 1);
    WriteTestMessage(Msg, 2);

    Msg.Close;
  finally
    Msg.Free;
  end;

  { Re-open and read }
  Msg := TSquish.Create;
  try
    Check('Squish re-open', Msg.Open(BasePath));
    Check('Squish Number = 2', Msg.Number = 2);

    Check('Squish ReadHeader', Msg.ReadHeader(Msg.Lowest));
    Check('Squish From has content', StrLen(Msg.From_) > 0);
    Check('Squish Subject has content', StrLen(Msg.Subject_) > 0);

    Msg.Close;
  finally
    Msg.Free;
  end;
end;

{ ---- FidoSDM Tests ---- }

procedure TestFidoSdm;
var
  Msg: TFidoSdm;
  MsgPath: String;
begin
  WriteLn;
  WriteLn('=== Fido *.MSG (SDM) Tests ===');

  MsgPath := TmpDir + DirectorySeparator + 'fidosdm';
  ForceDirectories(MsgPath);

  Msg := TFidoSdm.Create;
  try
    Check('FidoSdm Open', Msg.Open(MsgPath));
    Check('FidoSdm Number = 0', Msg.Number = 0);

    WriteTestMessage(Msg, 1);
    WriteTestMessage(Msg, 2);

    Msg.Close;
  finally
    Msg.Free;
  end;

  { Re-open and verify }
  Msg := TFidoSdm.Create;
  try
    Check('FidoSdm re-open', Msg.Open(MsgPath));
    Check('FidoSdm Number = 2', Msg.Number = 2);
    Check('FidoSdm 1.msg exists', FileExists(MsgPath + DirectorySeparator + '1.msg'));

    Check('FidoSdm ReadHeader', Msg.ReadHeader(Msg.Lowest));
    Check('FidoSdm From has content', StrLen(Msg.From_) > 0);

    Msg.Close;
  finally
    Msg.Free;
  end;

  { Cleanup subdirectory files }
  DeleteFile(MsgPath + DirectorySeparator + '1.msg');
  DeleteFile(MsgPath + DirectorySeparator + '2.msg');
  RemoveDir(MsgPath);
end;

{ ---- TDupes Tests ---- }

procedure TestDupes;
var
  D: TDupes;
  DupeFile: String;
begin
  WriteLn;
  WriteLn('=== TDupes Tests ===');

  DupeFile := TmpDir + DirectorySeparator + 'dupes.dat';

  D := TDupes.Create;
  try
    D.MaxEntries := 100;

    { First check should not be duplicate }
    Check('First entry not duplicate', not D.Check($DEADBEEF));
    Check('Second entry not duplicate', not D.Check($CAFEBABE));
    Check('Third entry not duplicate', not D.Check($12345678));

    { Re-checking same values should find duplicates }
    Check('Duplicate found for DEADBEEF', D.Check($DEADBEEF));
    Check('Duplicate found for CAFEBABE', D.Check($CAFEBABE));

    { New value still not duplicate }
    Check('New value not duplicate', not D.Check($AAAAAAAA));
  finally
    D.Free;
  end;
end;

{ ---- Packet Tests ---- }

procedure TestPacket;
var
  Pkt: TPacket;
  PktFile: String;
begin
  WriteLn;
  WriteLn('=== Packet (.PKT) Tests ===');

  PktFile := TmpDir + DirectorySeparator + 'test.pkt';

  Pkt := TPacket.Create;
  try
    { Create a new packet }
    Check('Packet Open for write', Pkt.Open(PktFile));

    { Set header addresses }
    Pkt.FromAddress.Zone := 1;
    Pkt.FromAddress.Net := 2320;
    Pkt.FromAddress.Node := 105;
    Pkt.ToAddress.Zone := 1;
    Pkt.ToAddress.Net := 2320;
    Pkt.ToAddress.Node := 200;

    Pkt.Close;
    Check('PKT file created', FileExists(PktFile));
  finally
    Pkt.Free;
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn;
  WriteLn('FastWay BBS - Message Base Test Suite');
  WriteLn('=====================================');

  SetupTmpDir;
  try
    TestJamMsg;
    TestSquish;
    TestFidoSdm;
    TestDupes;
    TestPacket;
  finally
    CleanupTmpDir;
  end;

  WriteLn;
  WriteLn('=====================================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
