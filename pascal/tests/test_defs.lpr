{
  FastWay BBS v1.0.0
  Test program for Defs unit - CRC, string, timer, and path functions
}

program test_defs;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Defs;

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

procedure TestCrc16;
var
  Crc: Word;
begin
  WriteLn;
  WriteLn('=== CRC-16 Tests ===');

  { Single byte CRC }
  Crc := Crc16(Byte('A'), $0000);
  Check('Crc16 of "A" from 0 is nonzero', Crc <> 0);

  { CRC should be deterministic }
  Check('Crc16 is deterministic', Crc16(Byte('A'), $0000) = Crc16(Byte('A'), $0000));

  { Different bytes give different CRCs }
  Check('Crc16 differs for A vs B', Crc16(Byte('A'), $0000) <> Crc16(Byte('B'), $0000));

  { StringCrc16 basic tests }
  Crc := StringCrc16('HELLO', $0000);
  Check('StringCrc16 of HELLO is nonzero', Crc <> 0);
  Check('StringCrc16 is case-insensitive', StringCrc16('hello', $0000) = StringCrc16('HELLO', $0000));
  Check('StringCrc16 differs for different strings', StringCrc16('HELLO', $0000) <> StringCrc16('WORLD', $0000));

  { String overload matches PChar overload }
  Check('StringCrc16 String = PChar overload', StringCrc16('TEST', $0000) = StringCrc16(PChar('TEST'), $0000));

  { Empty string gives back the seed }
  Check('StringCrc16 empty string returns seed', StringCrc16('', $FFFF) = $FFFF);
end;

procedure TestCrc32;
var
  Crc: LongWord;
begin
  WriteLn;
  WriteLn('=== CRC-32 Tests ===');

  { Single byte CRC }
  Crc := Crc32(Byte('A'), $FFFFFFFF);
  Check('Crc32 of "A" from FFFFFFFF is nonzero', Crc <> 0);
  Check('Crc32 is deterministic', Crc32(Byte('A'), $FFFFFFFF) = Crc32(Byte('A'), $FFFFFFFF));
  Check('Crc32 differs for A vs B', Crc32(Byte('A'), $FFFFFFFF) <> Crc32(Byte('B'), $FFFFFFFF));

  { StringCrc32 tests }
  Crc := StringCrc32('HELLO', $FFFFFFFF);
  Check('StringCrc32 of HELLO is nonzero', Crc <> 0);
  Check('StringCrc32 is case-insensitive', StringCrc32('hello', $FFFFFFFF) = StringCrc32('HELLO', $FFFFFFFF));
  Check('StringCrc32 differs for different strings', StringCrc32('HELLO', $FFFFFFFF) <> StringCrc32('WORLD', $FFFFFFFF));

  { String overload matches PChar overload }
  Check('StringCrc32 String = PChar overload', StringCrc32('TEST', $FFFFFFFF) = StringCrc32(PChar('TEST'), $FFFFFFFF));

  { Empty string gives back the seed }
  Check('StringCrc32 empty string returns seed', StringCrc32('', $FFFFFFFF) = $FFFFFFFF);

  { Known value: CRC32 of "HELLO" (case-insensitive, custom table) }
  { The LoraBBS CRC32 uses UpCase before CRC, so lowercase = uppercase }
  Check('StringCrc32 mixed case matches upper', StringCrc32('HeLLo', $FFFFFFFF) = StringCrc32('HELLO', $FFFFFFFF));
end;

procedure TestStringFunctions;
var
  Buf: array[0..255] of Char;
  S1, S2: PChar;
begin
  WriteLn;
  WriteLn('=== String Function Tests ===');

  { stricmp }
  Check('stricmp equal', stricmp('hello', 'HELLO') = 0);
  Check('stricmp not equal', stricmp('hello', 'world') <> 0);
  Check('stricmp empty', stricmp('', '') = 0);

  { strnicmp }
  Check('strnicmp equal prefix', strnicmp('hello world', 'HELLO THERE', 5) = 0);
  Check('strnicmp not equal prefix', strnicmp('hello', 'world', 3) <> 0);
  Check('strnicmp zero length', strnicmp('abc', 'xyz', 0) = 0);

  { strlwr }
  StrCopy(Buf, 'HELLO WORLD');
  strlwr(Buf);
  Check('strlwr converts to lowercase', StrComp(Buf, 'hello world') = 0);

  { strupr }
  StrCopy(Buf, 'hello world');
  strupr(Buf);
  Check('strupr converts to uppercase', StrComp(Buf, 'HELLO WORLD') = 0);

  { strsrep }
  StrCopy(Buf, 'hello world hello');
  strsrep(Buf, 'hello', 'hi');
  Check('strsrep replaces all occurrences', StrComp(Buf, 'hi world hi') = 0);

  StrCopy(Buf, 'aabbcc');
  strsrep(Buf, 'bb', 'B');
  Check('strsrep shorter replacement', StrComp(Buf, 'aaBcc') = 0);

  StrCopy(Buf, 'test');
  strsrep(Buf, 'xyz', 'abc');
  Check('strsrep no match unchanged', StrComp(Buf, 'test') = 0);
end;

procedure TestDosDateTime;
var
  dd: DosDate_T;
  dt: DosTime_T;
begin
  WriteLn;
  WriteLn('=== DOS Date/Time Tests ===');

  _dos_getdate(dd);
  Check('dos_getdate Year >= 2024', dd.Year >= 2024);
  Check('dos_getdate Month in range', (dd.Month >= 1) and (dd.Month <= 12));
  Check('dos_getdate Day in range', (dd.Day >= 1) and (dd.Day <= 31));
  Check('dos_getdate DayOfWeek in range', dd.DayOfWeek <= 6);

  _dos_gettime(dt);
  Check('dos_gettime Hour in range', dt.Hour <= 23);
  Check('dos_gettime Minute in range', dt.Minute <= 59);
  Check('dos_gettime Second in range', dt.Second <= 59);
end;

procedure TestAdjustPath;
var
  Buf: array[0..255] of Char;
begin
  WriteLn;
  WriteLn('=== AdjustPath Tests ===');

  StrCopy(Buf, '/tmp/test');
  AdjustPath(Buf);
  Check('AdjustPath adds trailing slash', StrComp(Buf, '/tmp/test/') = 0);

  StrCopy(Buf, '/tmp/test/');
  AdjustPath(Buf);
  Check('AdjustPath no double slash', StrComp(Buf, '/tmp/test/') = 0);

  Buf[0] := #0;
  AdjustPath(Buf);
  Check('AdjustPath empty string unchanged', Buf[0] = #0);
end;

procedure TestTimers;
var
  T: LongInt;
begin
  WriteLn;
  WriteLn('=== Timer Tests ===');

  T := TimerSet(100); { 1 second }
  Check('TimerSet returns future value', T > LongInt(GetTickCount64 div 10) - 10);
  Check('TimeUp not expired immediately', TimeUp(T) = 0);

  { Test already expired timer }
  T := TimerSet(0);
  Check('TimerSet(0) expires immediately', TimeUp(T) <> 0);
end;

procedure TestConstants;
begin
  WriteLn;
  WriteLn('=== Constants Tests ===');

  Check('TRUE_ = 1', TRUE_ = 1);
  Check('FALSE_ = 0', FALSE_ = 0);
  Check('CTRLA = $01', CTRLA = $01);
  Check('CTRLZ = $1A', CTRLZ = $1A);
  Check('ESC_ = $1B', ESC_ = $1B);
  Check('DEL_ = $7F', DEL_ = $7F);

  { Color constants }
  Check('BLACK = 0', BLACK = 0);
  Check('WHITE = 15', WHITE = 15);
  Check('_BLUE = 16', _BLUE = 16);
  Check('BLINK = 128', BLINK = 128);
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn;
  WriteLn('FastWay BBS - Defs Unit Test Suite');
  WriteLn('==================================');

  TestConstants;
  TestCrc16;
  TestCrc32;
  TestStringFunctions;
  TestDosDateTime;
  TestAdjustPath;
  TestTimers;

  WriteLn;
  WriteLn('==================================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
