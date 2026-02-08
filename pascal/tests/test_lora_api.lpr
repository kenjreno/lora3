{
  FastWay BBS v1.0.0
  Test program for lora_api units - User, OkFile, Log, Config, MsgData
  Tests file-based operations with temp directory creation/cleanup.
}

program test_lora_api;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Classes, Defs, Struc299, Collect, Address,
  Config, User, OkFile, Log, MsgData;

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
  TmpDir := GetTempDir(False) + 'fwbbs_test';
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

{ ---- TLog Tests ---- }

procedure TestLog;
var
  L: TLog;
  LogFile: String;
  fs: TFileStream;
  Buf: String;
begin
  WriteLn;
  WriteLn('=== TLog Tests ===');

  LogFile := TmpDir + DirectorySeparator + 'test.log';

  L := TLog.Create;
  try
    Check('Log.Open returns nonzero', L.Open(PChar(LogFile)) <> 0);
    L.Write(PChar('Test message %d'), [42]);
    L.Write(PChar('Simple message'));
    L.WriteBlank;
  finally
    L.Free;
  end;

  Check('Log file created', FileExists(LogFile));

  { Read back and verify content }
  fs := TFileStream.Create(LogFile, fmOpenRead);
  try
    SetLength(Buf, fs.Size);
    if fs.Size > 0 then
      fs.Read(Buf[1], fs.Size);
    Check('Log contains test message', Pos('Test message 42', Buf) > 0);
    Check('Log contains simple message', Pos('Simple message', Buf) > 0);
  finally
    fs.Free;
  end;
end;

{ ---- TOkFile Tests ---- }

procedure TestOkFile;
var
  OK: TOkFile;
begin
  WriteLn;
  WriteLn('=== TOkFile Tests ===');

  OK := TOkFile.Create(PChar(TmpDir));
  try
    { Add an entry }
    StrCopy(OK.Name, 'TESTFILE');
    StrCopy(OK.Path, '/files/test');
    StrCopy(OK.Pwd, '');
    OK.Normal := Char(1);
    OK.Known := Char(1);
    OK.Protected_ := Char(0);
    OK.Add;

    { Add another }
    StrCopy(OK.Name, 'ANOTHER');
    StrCopy(OK.Path, '/files/other');
    OK.Normal := Char(1);
    OK.Known := Char(0);
    OK.Add;

    Check('okfile.dat created', FileExists(TmpDir + DirectorySeparator + 'okfile.dat'));
  finally
    OK.Free;
  end;

  { Read back }
  OK := TOkFile.Create(PChar(TmpDir));
  try
    Check('First returns nonzero', OK.First <> 0);
    Check('First name is TESTFILE', StrComp(OK.Name, 'TESTFILE') = 0);
    Check('First path is /files/test', StrComp(OK.Path, '/files/test') = 0);

    Check('Next returns nonzero', OK.Next <> 0);
    Check('Second name is ANOTHER', StrComp(OK.Name, 'ANOTHER') = 0);

    Check('Next past end returns 0', OK.Next = 0);

    { Read by name }
    Check('Read TESTFILE found', OK.Read(PChar('TESTFILE')) <> 0);
    Check('Read path correct', StrComp(OK.Path, '/files/test') = 0);

    Check('Read nonexistent returns 0', OK.Read(PChar('MISSING')) = 0);
  finally
    OK.Free;
  end;
end;

{ ---- TUser Tests ---- }

procedure TestUser;
var
  U: TUser;
  UserFile: String;
begin
  WriteLn;
  WriteLn('=== TUser Tests ===');

  UserFile := TmpDir + DirectorySeparator + 'users';

  U := TUser.Create(UserFile);
  try
    { Add a user }
    U.Clear;
    U.Name := 'SYSOP';
    U.RealName := 'System Operator';
    U.City := 'Test City';
    U.Level := 32000;
    U.SetPassword('secret');
    Check('Add user returns True', U.Add);

    { Add another user }
    U.Clear;
    U.Name := 'GUEST';
    U.RealName := 'Guest User';
    U.City := 'Guest City';
    U.Level := 10;
    U.SetPassword('guest');
    Check('Add second user returns True', U.Add);

    Check('users.dat created', FileExists(UserFile + '.dat'));
    Check('users.idx created', FileExists(UserFile + '.idx'));
  finally
    U.Free;
  end;

  { Read back }
  U := TUser.Create(UserFile);
  try
    { Navigate }
    Check('First returns True', U.First);
    Check('First user is SYSOP', U.Name = 'SYSOP');
    Check('SYSOP real name', U.RealName = 'System Operator');
    Check('SYSOP city', U.City = 'Test City');
    Check('SYSOP level', U.Level = 32000);

    Check('Next returns True', U.Next);
    Check('Second user is GUEST', U.Name = 'GUEST');
    Check('GUEST level', U.Level = 10);

    Check('Next past end returns False', not U.Next);

    { Lookup by name }
    Check('GetData SYSOP', U.GetData('SYSOP'));
    Check('GetData SYSOP level', U.Level = 32000);

    Check('GetData GUEST', U.GetData('GUEST'));
    Check('GetData GUEST level', U.Level = 10);

    Check('GetData unknown returns False', not U.GetData('NOBODY'));

    { Password check }
    U.GetData('SYSOP');
    Check('Correct password', U.CheckPassword('secret'));
    Check('Wrong password', not U.CheckPassword('wrong'));

    { Update }
    U.GetData('GUEST');
    U.Level := 50;
    Check('Update returns True', U.Update);

    { Re-read to verify update }
    U.GetData('GUEST');
    Check('Updated level persisted', U.Level = 50);

    { Delete }
    U.GetData('GUEST');
    Check('Delete returns True', U.Delete);
    Check('Deleted user not found', not U.GetData('GUEST'));
    Check('SYSOP still exists', U.GetData('SYSOP'));
  finally
    U.Free;
  end;
end;

{ ---- TConfig Tests ---- }

procedure TestConfig;
var
  Cfg: TConfig;
begin
  WriteLn;
  WriteLn('=== TConfig Tests ===');

  Cfg := TConfig.Create;
  try
    { Default config }
    Cfg.Default;
    Check('Default sets SystemName', Cfg.SystemName[0] <> #0);
    Check('Default TaskNumber = 1', Cfg.TaskNumber = 1);

    { Save and reload }
    StrCopy(Cfg.SystemPath, PChar(TmpDir + DirectorySeparator));
    StrCopy(Cfg.SystemName, 'Test BBS');
    StrCopy(Cfg.SysopName, 'Test Sysop');
    Cfg.TaskNumber := 5;

    Check('Save returns nonzero', Cfg.Save(PChar(TmpDir + DirectorySeparator + 'config.dat')) <> 0);
    Check('config.dat created', FileExists(TmpDir + DirectorySeparator + 'config.dat'));
  finally
    Cfg.Free;
  end;

  { Load into fresh object }
  Cfg := TConfig.Create;
  try
    Check('Load returns nonzero', Cfg.Load(PChar(TmpDir + DirectorySeparator + 'config.dat')) <> 0);
    Check('Loaded SystemName', StrComp(Cfg.SystemName, 'Test BBS') = 0);
    Check('Loaded SysopName', StrComp(Cfg.SysopName, 'Test Sysop') = 0);
    Check('Loaded TaskNumber', Cfg.TaskNumber = 5);
  finally
    Cfg.Free;
  end;
end;

{ ---- TMsgData Tests ---- }

procedure TestMsgData;
var
  MD: TMsgData;
begin
  WriteLn;
  WriteLn('=== TMsgData Tests ===');

  MD := TMsgData.Create(TmpDir);
  try
    { Add a message area }
    MD.New_;
    MD.Key := 'GENERAL';
    MD.Display := 'General Discussion';
    MD.Storage := 1; { ST_JAM }
    MD.Path := TmpDir + DirectorySeparator + 'msg' + DirectorySeparator + 'general';
    MD.EchoMail := False;
    MD.MaxMessages := 500;
    MD.DaysOld := 365;
    Check('Add GENERAL', MD.Add);

    { Add another }
    MD.New_;
    MD.Key := 'SYSOP';
    MD.Display := 'Sysop Conference';
    MD.Storage := 1;
    MD.Path := TmpDir + DirectorySeparator + 'msg' + DirectorySeparator + 'sysop';
    MD.EchoMail := False;
    MD.Level := 32000;
    Check('Add SYSOP', MD.Add);
  finally
    MD.Free;
  end;

  { Read back }
  MD := TMsgData.Create(TmpDir);
  try
    Check('First returns True', MD.First);
    Check('First key is GENERAL', MD.Key = 'GENERAL');
    Check('First display', MD.Display = 'General Discussion');
    Check('First maxmsgs', MD.MaxMessages = 500);

    Check('Next returns True', MD.Next);
    Check('Second key is SYSOP', MD.Key = 'SYSOP');
    Check('Second level', MD.Level = 32000);

    Check('Next past end', not MD.Next);

    { Read by name }
    Check('Read GENERAL', MD.Read('GENERAL'));
    Check('Read GENERAL display', MD.Display = 'General Discussion');

    Check('Read nonexistent', not MD.Read('MISSING'));

    { Update }
    MD.Read('GENERAL');
    MD.MaxMessages := 1000;
    Check('Update GENERAL', MD.Update());

    MD.Read('GENERAL');
    Check('Updated maxmsgs', MD.MaxMessages = 1000);
  finally
    MD.Free;
  end;
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn;
  WriteLn('FastWay BBS - Lora API Unit Test Suite');
  WriteLn('======================================');

  SetupTmpDir;
  try
    TestLog;
    TestOkFile;
    TestUser;
    TestConfig;
    TestMsgData;
  finally
    CleanupTmpDir;
  end;

  WriteLn;
  WriteLn('======================================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
