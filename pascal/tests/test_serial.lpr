{
  FastWay BBS v1.0.0
  Serial port test - Tests TSerial class using virtual serial ports

  Linux setup (requires socat):
    socat -d -d pty,raw,echo=0 pty,raw,echo=0
    This creates two linked pseudo-terminals like /dev/pts/3 and /dev/pts/4

  Then run:
    test_serial /dev/pts/3 /dev/pts/4

  Windows setup (requires com0com or similar virtual COM port driver):
    test_serial COM3 COM4

  The test opens both ports - one as "modem" side, one as "remote" side -
  and sends data between them to verify the serial comm layer.
}

program test_serial;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Defs, ComBase, Serial;

var
  TestsPassed, TestsFailed: Integer;

procedure Pass(const Msg: String);
begin
  WriteLn('  PASS: ', Msg);
  Inc(TestsPassed);
end;

procedure Fail(const Msg: String);
begin
  WriteLn('  FAIL: ', Msg);
  Inc(TestsFailed);
end;

procedure TestInitAndCarrier(const Dev1, Dev2: String);
var
  Ser: TSerial;
begin
  WriteLn;
  WriteLn('=== Initialize and Carrier Test ===');

  Ser := TSerial.Create;
  try
    StrPCopy(Ser.Device, Dev1);
    Ser.Speed := 9600;
    Ser.DataBits := 8;
    Ser.Parity := 'N';
    Ser.StopBits := 1;

    WriteLn('  Opening ', Dev1, ' at 9600 8N1...');
    if Ser.Initialize <> 0 then
    begin
      Pass('Serial port opened: ' + Dev1);
      WriteLn('  Carrier: ', Ser.Carrier);
      { Virtual ports may or may not report carrier }
    end
    else
      Fail('Could not open serial port: ' + Dev1);
  finally
    Ser.Free;
  end;
end;

procedure TestSingleByteEcho(const Dev1, Dev2: String);
var
  Modem, Remote: TSerial;
  B: Byte;
  Tries: Integer;
begin
  WriteLn;
  WriteLn('=== Single Byte Transfer ===');

  Modem := TSerial.Create;
  Remote := TSerial.Create;
  try
    StrPCopy(Modem.Device, Dev1);
    Modem.Speed := 9600;
    Modem.DataBits := 8;
    Modem.Parity := 'N';
    Modem.StopBits := 1;

    StrPCopy(Remote.Device, Dev2);
    Remote.Speed := 9600;
    Remote.DataBits := 8;
    Remote.Parity := 'N';
    Remote.StopBits := 1;

    if (Modem.Initialize = 0) then
    begin
      Fail('Could not open modem port: ' + Dev1);
      Exit;
    end;
    if (Remote.Initialize = 0) then
    begin
      Fail('Could not open remote port: ' + Dev2);
      Exit;
    end;
    Pass('Both ports opened');

    { Send from modem to remote }
    WriteLn('  Sending $A5 from ', Dev1, ' to ', Dev2, '...');
    Modem.SendByte($A5);
    Modem.UnbufferBytes;

    Tries := 0;
    while (Remote.BytesReady = 0) and (Tries < 100) do
    begin
      Sleep(10);
      Inc(Tries);
    end;

    if Remote.BytesReady <> 0 then
    begin
      B := Remote.ReadByte;
      if B = $A5 then
        Pass(Format('Byte transfer verified ($%s)', [IntToHex(B, 2)]))
      else
        Fail(Format('Expected $A5, got $%s', [IntToHex(B, 2)]));
    end
    else
      Fail('No data received on remote port (timeout)');

    { Send from remote back to modem }
    WriteLn('  Sending $5A from ', Dev2, ' to ', Dev1, '...');
    Remote.SendByte($5A);
    Remote.UnbufferBytes;

    Tries := 0;
    while (Modem.BytesReady = 0) and (Tries < 100) do
    begin
      Sleep(10);
      Inc(Tries);
    end;

    if Modem.BytesReady <> 0 then
    begin
      B := Modem.ReadByte;
      if B = $5A then
        Pass(Format('Reverse byte transfer verified ($%s)', [IntToHex(B, 2)]))
      else
        Fail(Format('Expected $5A, got $%s', [IntToHex(B, 2)]));
    end
    else
      Fail('No data received on modem port (timeout)');

  finally
    Remote.Free;
    Modem.Free;
  end;
end;

procedure TestBlockTransfer(const Dev1, Dev2: String);
var
  Modem, Remote: TSerial;
  SendBuf, RecvBuf: array[0..255] of Byte;
  Received: Word;
  i, Tries: Integer;
  OK: Boolean;
begin
  WriteLn;
  WriteLn('=== 256-Byte Block Transfer ===');

  Modem := TSerial.Create;
  Remote := TSerial.Create;
  try
    StrPCopy(Modem.Device, Dev1);
    Modem.Speed := 9600;
    Modem.DataBits := 8;
    Modem.Parity := 'N';
    Modem.StopBits := 1;

    StrPCopy(Remote.Device, Dev2);
    Remote.Speed := 9600;
    Remote.DataBits := 8;
    Remote.Parity := 'N';
    Remote.StopBits := 1;

    if (Modem.Initialize = 0) or (Remote.Initialize = 0) then
    begin
      Fail('Could not open serial ports');
      Exit;
    end;

    { Fill send buffer with pattern }
    for i := 0 to 255 do
      SendBuf[i] := Byte(i);

    WriteLn('  Sending 256-byte block...');
    Modem.SendBytes(@SendBuf[0], 256);
    Modem.UnbufferBytes;

    { Receive }
    FillChar(RecvBuf, 256, 0);
    Received := 0;
    Tries := 0;
    while (Received < 256) and (Tries < 300) do
    begin
      if Remote.BytesReady <> 0 then
        Received := Received + Remote.ReadBytes(@RecvBuf[Received], 256 - Received);
      Inc(Tries);
      if Received < 256 then Sleep(10);
    end;
    WriteLn('  Received ', Received, ' bytes');

    if Received = 256 then
    begin
      OK := True;
      for i := 0 to 255 do
        if RecvBuf[i] <> Byte(i) then begin OK := False; Break; end;
      if OK then
        Pass('Block transfer data verified')
      else
        Fail('Block data mismatch');
    end
    else
      Fail(Format('Only received %d of 256 bytes', [Received]));

  finally
    Remote.Free;
    Modem.Free;
  end;
end;

procedure TestBufferedIO(const Dev1, Dev2: String);
var
  Modem, Remote: TSerial;
  Buf: array[0..1023] of Byte;
  Received: Word;
  i, Tries: Integer;
begin
  WriteLn;
  WriteLn('=== Buffered I/O Test ===');

  Modem := TSerial.Create;
  Remote := TSerial.Create;
  try
    StrPCopy(Modem.Device, Dev1);
    Modem.Speed := 9600;
    Modem.DataBits := 8;
    Modem.Parity := 'N';
    Modem.StopBits := 1;

    StrPCopy(Remote.Device, Dev2);
    Remote.Speed := 9600;
    Remote.DataBits := 8;
    Remote.Parity := 'N';
    Remote.StopBits := 1;

    if (Modem.Initialize = 0) or (Remote.Initialize = 0) then
    begin
      Fail('Could not open serial ports');
      Exit;
    end;

    { Buffer multiple bytes then flush }
    WriteLn('  Buffering 10 bytes then flushing...');
    for i := 0 to 9 do
      Modem.BufferByte(Byte(i + $30));
    Modem.UnbufferBytes;

    Received := 0;
    Tries := 0;
    while (Received < 10) and (Tries < 100) do
    begin
      if Remote.BytesReady <> 0 then
        Received := Received + Remote.ReadBytes(@Buf[Received], 10 - Received);
      Inc(Tries);
      if Received < 10 then Sleep(10);
    end;

    if Received = 10 then
      Pass(Format('Buffered I/O: received %d bytes', [Received]))
    else
      Fail(Format('Buffered I/O: only received %d of 10', [Received]));

    { Buffer a block }
    WriteLn('  BufferBytes 100 bytes then flush...');
    for i := 0 to 99 do
      Buf[i] := Byte(i);
    Modem.BufferBytes(@Buf[0], 100);
    Modem.UnbufferBytes;

    FillChar(Buf, 100, 0);
    Received := 0;
    Tries := 0;
    while (Received < 100) and (Tries < 200) do
    begin
      if Remote.BytesReady <> 0 then
        Received := Received + Remote.ReadBytes(@Buf[Received], 100 - Received);
      Inc(Tries);
      if Received < 100 then Sleep(10);
    end;

    if Received = 100 then
      Pass(Format('BufferBytes: received %d bytes', [Received]))
    else
      Fail(Format('BufferBytes: only received %d of 100', [Received]));

  finally
    Remote.Free;
    Modem.Free;
  end;
end;

procedure TestSpeedChange(const Dev1, Dev2: String);
var
  Modem, Remote: TSerial;
  B: Byte;
  Tries: Integer;
begin
  WriteLn;
  WriteLn('=== Speed Change Test ===');

  Modem := TSerial.Create;
  Remote := TSerial.Create;
  try
    StrPCopy(Modem.Device, Dev1);
    Modem.Speed := 9600;
    Modem.DataBits := 8;
    Modem.Parity := 'N';
    Modem.StopBits := 1;

    StrPCopy(Remote.Device, Dev2);
    Remote.Speed := 9600;
    Remote.DataBits := 8;
    Remote.Parity := 'N';
    Remote.StopBits := 1;

    if (Modem.Initialize = 0) or (Remote.Initialize = 0) then
    begin
      Fail('Could not open serial ports');
      Exit;
    end;

    { Change both to 19200 }
    WriteLn('  Changing both ports to 19200...');
    Modem.SetParameters(19200, 8, Byte('N'), 1);
    Remote.SetParameters(19200, 8, Byte('N'), 1);
    Sleep(50); { Let settings take effect }

    Modem.SendByte($BE);
    Modem.UnbufferBytes;

    Tries := 0;
    while (Remote.BytesReady = 0) and (Tries < 100) do begin Sleep(10); Inc(Tries); end;
    if Remote.BytesReady <> 0 then
    begin
      B := Remote.ReadByte;
      if B = $BE then
        Pass('Speed change to 19200 verified')
      else
        Fail(Format('At 19200: expected $BE, got $%s', [IntToHex(B, 2)]));
    end
    else
      Fail('No data at 19200 baud');

    { Change to 38400 }
    WriteLn('  Changing both ports to 38400...');
    Modem.SetParameters(38400, 8, Byte('N'), 1);
    Remote.SetParameters(38400, 8, Byte('N'), 1);
    Sleep(50);

    Modem.SendByte($EF);
    Modem.UnbufferBytes;

    Tries := 0;
    while (Remote.BytesReady = 0) and (Tries < 100) do begin Sleep(10); Inc(Tries); end;
    if Remote.BytesReady <> 0 then
    begin
      B := Remote.ReadByte;
      if B = $EF then
        Pass('Speed change to 38400 verified')
      else
        Fail(Format('At 38400: expected $EF, got $%s', [IntToHex(B, 2)]));
    end
    else
      Fail('No data at 38400 baud');

  finally
    Remote.Free;
    Modem.Free;
  end;
end;

procedure TestDTRControl(const Dev1, Dev2: String);
var
  Ser: TSerial;
begin
  WriteLn;
  WriteLn('=== DTR/RTS Control Test ===');

  Ser := TSerial.Create;
  try
    StrPCopy(Ser.Device, Dev1);
    Ser.Speed := 9600;
    Ser.DataBits := 8;
    Ser.Parity := 'N';
    Ser.StopBits := 1;

    if Ser.Initialize = 0 then
    begin
      Fail('Could not open serial port');
      Exit;
    end;

    WriteLn('  Setting DTR high...');
    Ser.SetDTR(1);
    Sleep(50);
    Pass('DTR set high (no crash)');

    WriteLn('  Setting DTR low...');
    Ser.SetDTR(0);
    Sleep(50);
    Pass('DTR set low (no crash)');

    WriteLn('  Setting RTS high...');
    Ser.SetRTS(1);
    Sleep(50);
    Pass('RTS set high (no crash)');

    WriteLn('  Setting RTS low...');
    Ser.SetRTS(0);
    Sleep(50);
    Pass('RTS set low (no crash)');

    WriteLn('  Toggling DTR rapidly (hangup simulation)...');
    Ser.SetDTR(0);
    Sleep(100);
    Ser.SetDTR(1);
    Sleep(100);
    Pass('DTR toggle (hangup simulation)');

  finally
    Ser.Free;
  end;
end;

procedure TestClearBuffers(const Dev1, Dev2: String);
var
  Modem, Remote: TSerial;
  Buf: array[0..255] of Byte;
  i: Integer;
begin
  WriteLn;
  WriteLn('=== Clear Buffers Test ===');

  Modem := TSerial.Create;
  Remote := TSerial.Create;
  try
    StrPCopy(Modem.Device, Dev1);
    Modem.Speed := 9600;
    Modem.DataBits := 8;
    Modem.Parity := 'N';
    Modem.StopBits := 1;

    StrPCopy(Remote.Device, Dev2);
    Remote.Speed := 9600;
    Remote.DataBits := 8;
    Remote.Parity := 'N';
    Remote.StopBits := 1;

    if (Modem.Initialize = 0) or (Remote.Initialize = 0) then
    begin
      Fail('Could not open serial ports');
      Exit;
    end;

    { Buffer some data but clear before sending }
    WriteLn('  Buffering 50 bytes then clearing outbound...');
    for i := 0 to 49 do
      Modem.BufferByte(Byte(i));
    Modem.ClearOutbound;
    Modem.UnbufferBytes;
    Pass('ClearOutbound executed (no crash)');

    { Clear inbound }
    WriteLn('  Clearing inbound buffer...');
    Remote.ClearInbound;
    Pass('ClearInbound executed (no crash)');

  finally
    Remote.Free;
    Modem.Free;
  end;
end;

procedure PrintUsage;
begin
  WriteLn;
  WriteLn('FastWay BBS - Serial Port Test');
  WriteLn('==============================');
  WriteLn;
  WriteLn('Usage: test_serial <device1> <device2>');
  WriteLn;
  WriteLn('Requires a pair of linked virtual serial ports.');
  WriteLn;
  WriteLn('Linux setup (using socat):');
  WriteLn('  socat -d -d pty,raw,echo=0 pty,raw,echo=0');
  WriteLn('  Then use the two /dev/pts/N paths shown by socat.');
  WriteLn;
  WriteLn('  Example: test_serial /dev/pts/3 /dev/pts/4');
  WriteLn;
  WriteLn('Windows setup (using com0com virtual COM port driver):');
  WriteLn('  Install com0com, then use the paired COM ports.');
  WriteLn;
  WriteLn('  Example: test_serial COM3 COM4');
  WriteLn;
end;

var
  Dev1, Dev2: String;
begin
  TestsPassed := 0;
  TestsFailed := 0;

  if ParamCount < 2 then
  begin
    PrintUsage;
    Halt(1);
  end;

  Dev1 := ParamStr(1);
  Dev2 := ParamStr(2);

  WriteLn;
  WriteLn('FastWay BBS - Serial Port Test');
  WriteLn('==============================');
  WriteLn('Device 1 (modem):  ', Dev1);
  WriteLn('Device 2 (remote): ', Dev2);

  TestInitAndCarrier(Dev1, Dev2);
  TestSingleByteEcho(Dev1, Dev2);
  TestBlockTransfer(Dev1, Dev2);
  TestBufferedIO(Dev1, Dev2);
  TestSpeedChange(Dev1, Dev2);
  TestDTRControl(Dev1, Dev2);
  TestClearBuffers(Dev1, Dev2);

  WriteLn;
  WriteLn('==============================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
