{
  FastWay BBS v1.0.0
  Comm test client - Run test_comm_server first, then run this in terminal 2
  Tests TCP client, pipe client, data relay, carrier detection
  Usage: test_comm_client [host] [port] (default localhost 23000)
}

program test_comm_client;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils,
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  Defs, ComBase, Tcpip, Npipe;

var
  TestHost: String;
  TestPort: Word;
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

{ Helper: wait for data with timeout }
function WaitData(Conn: TCom; TimeoutMs: Integer): Boolean;
var
  Elapsed: Integer;
begin
  Elapsed := 0;
  while (Conn.BytesReady = 0) and (Elapsed < TimeoutMs) and (Conn.Carrier <> 0) do
  begin
    Sleep(10);
    Inc(Elapsed, 10);
  end;
  Result := Conn.BytesReady <> 0;
end;

{ Helper: receive exact number of bytes with timeout }
function RecvExact(Conn: TCom; Buf: PByte; Count: LongWord; TimeoutMs: Integer): LongWord;
var
  Got: LongWord;
  Elapsed: Integer;
begin
  Result := 0;
  Elapsed := 0;
  while (Result < Count) and (Elapsed < TimeoutMs) and (Conn.Carrier <> 0) do
  begin
    if Conn.BytesReady <> 0 then
    begin
      Got := Conn.ReadBytes(@Buf[Result], Count - Result);
      Inc(Result, Got);
      Elapsed := 0; { Reset timeout on data }
    end
    else
    begin
      Sleep(10);
      Inc(Elapsed, 10);
    end;
  end;
end;

procedure RunTcpClient;
var
  Client: TTcpip;
  Buf: array[0..2047] of Byte;
  Received, Total: LongWord;
  B: Byte;
  i: Integer;
  OK: Boolean;
begin
  WriteLn;
  WriteLn('=== TCP Client Test ===');

  Client := TTcpip.Create;
  try
    WriteLn('  Connecting to ', TestHost, ':', TestPort, '...');
    if Client.ConnectServer(PChar(TestHost), TestPort) = 0 then
    begin
      Fail('Could not connect to server');
      Exit;
    end;
    WriteLn('  Connected!');
    WriteLn;

    { Test 1: Single byte echo - send $A5, expect $5A back }
    WriteLn('  [Test 1] Byte echo...');
    Client.SendByte($A5);
    Client.UnbufferBytes;
    WriteLn('    Sent: $A5');

    if WaitData(Client, 5000) then
    begin
      B := Client.ReadByte;
      WriteLn('    Received: $', IntToHex(B, 2));
      if B = ($A5 xor $FF) then
        Pass('Byte echo verified ($A5 -> $5A)')
      else
        Fail(Format('Expected $5A, got $%s', [IntToHex(B, 2)]));
    end
    else
      Fail('No echo response');

    { Test 2: 256-byte block with verification }
    WriteLn;
    WriteLn('  [Test 2] 256-byte block transfer...');
    for i := 0 to 255 do
      Buf[i] := Byte(i);
    Client.SendBytes(@Buf[0], 256);
    Client.UnbufferBytes;
    WriteLn('    Sent 256 bytes (0..255)');

    { Receive reversed block }
    Received := RecvExact(Client, @Buf[0], 256, 5000);
    WriteLn('    Received ', Received, ' bytes back');

    if Received = 256 then
    begin
      OK := True;
      for i := 0 to 255 do
        if Buf[i] <> Byte(255 - i) then begin OK := False; Break; end;
      if OK then
        Pass('Block transfer verified (reversed)')
      else
        Fail('Block data mismatch');
    end
    else
      Fail(Format('Only received %d of 256', [Received]));

    { Test 3: Stress - send 100KB with pacing }
    WriteLn;
    WriteLn('  [Test 3] Stress test (100KB)...');
    Total := 0;
    for i := 0 to 49 do
    begin
      FillChar(Buf, 2048, Byte(i));
      Client.SendBytes(@Buf[0], 2048);
      Client.UnbufferBytes;
      Inc(Total, 2048);
      if (Total mod 10240) = 0 then
      begin
        Write(Format('    %d / 102400 bytes sent'#13, [Total]));
        Sleep(1); { Small delay every 10KB to avoid overwhelming server }
      end;
    end;
    WriteLn(Format('    %d / 102400 bytes sent   ', [Total]));

    { Wait for ack with 30s timeout }
    if WaitData(Client, 30000) then
    begin
      B := Client.ReadByte;
      if B = $AA then
        Pass('Stress test 100KB acknowledged')
      else
        Fail(Format('Expected ack $AA, got $%s', [IntToHex(B, 2)]));
    end
    else
    begin
      Fail('No stress test acknowledgement (30s timeout)');
      if Client.Carrier = 0 then
        WriteLn('    (carrier dropped)');
    end;

    { Test 4: Bidirectional - 50 rounds x 512B }
    { Send sync byte to resynchronize with server }
    WriteLn;
    WriteLn('  [Test 4] Bidirectional test (50 rounds x 512B)...');
    Client.SendByte($BB); { Sync byte }
    Client.UnbufferBytes;
    Sleep(50); { Let server process sync }

    Total := 0;
    for i := 1 to 50 do
    begin
      { Receive 512 bytes from server }
      Received := RecvExact(Client, @Buf[0], 512, 5000);
      Inc(Total, Received);

      { Send 512 bytes back }
      FillChar(Buf, 512, Byte(i + 100));
      Client.SendBytes(@Buf[0], 512);
      Client.UnbufferBytes;
    end;
    if Total = 25600 then
      Pass('Bidirectional 25600 bytes')
    else
      Fail(Format('Bidirectional received %d of 25600', [Total]));

    { Test 5: Disconnect - carrier detection on server side }
    WriteLn;
    WriteLn('  [Test 5] Disconnecting (server should detect carrier loss)...');
    Sleep(200); { Brief pause before disconnect }

  finally
    Client.Free;
  end;

  Pass('Client disconnected cleanly');
end;

{$IFDEF UNIX}
procedure RunPipeClient;
var
  Client: TPipe;
  Buf: array[0..255] of Byte;
  Received: Word;
  B: Byte;
  i: Integer;
  PipePath, CtlPath: String;
begin
  WriteLn;
  WriteLn('=== Pipe Client Test ===');

  PipePath := '/tmp/lora_test_pipe';
  CtlPath := '/tmp/lora_test_ctl';

  Client := TPipe.Create;
  try
    WriteLn('  Connecting to pipe at ', PipePath, '...');
    if Client.ConnectServer(PChar(PipePath), PChar(CtlPath)) = 0 then
    begin
      Fail('Could not connect to pipe server');
      Exit;
    end;
    WriteLn('  Connected!');
    Sleep(100); { Let server detect connection }

    { Echo test }
    WriteLn('  [Test] Pipe byte echo...');
    Client.SendByte($C3);
    Client.UnbufferBytes;

    if WaitData(Client, 5000) then
    begin
      B := Client.ReadByte;
      if B = ($C3 xor $FF) then
        Pass(Format('Pipe echo verified ($C3 -> $%s)', [IntToHex(B, 2)]))
      else
        Fail(Format('Pipe echo expected $3C, got $%s', [IntToHex(B, 2)]));
    end
    else
      Fail('No pipe echo response');

    { Block test }
    WriteLn('  [Test] Pipe 64-byte block...');
    for i := 0 to 63 do
      Buf[i] := Byte(i * 4);
    Client.SendBytes(@Buf[0], 64);
    Client.UnbufferBytes;

    Received := RecvExact(Client, @Buf[0], 64, 5000);
    if Received = 64 then
      Pass('Pipe block 64 bytes echoed')
    else
      Fail(Format('Pipe block only received %d of 64', [Received]));

    WriteLn('  Disconnecting pipe...');
    Sleep(100);
  finally
    Client.Free;
  end;
  Pass('Pipe client disconnected');
end;
{$ENDIF}

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn;
  WriteLn('FastWay BBS - Comm Test Client');
  WriteLn('==============================');
  WriteLn;

  if ParamCount >= 1 then
    TestHost := ParamStr(1)
  else
    TestHost := '127.0.0.1';

  if ParamCount >= 2 then
    TestPort := Word(StrToIntDef(ParamStr(2), 23000))
  else
    TestPort := 23000;

  RunTcpClient;
  {$IFDEF UNIX}
  RunPipeClient;
  {$ENDIF}

  WriteLn;
  WriteLn('==============================');
  WriteLn(Format('Results: %d passed, %d failed, %d total',
    [TestsPassed, TestsFailed, TestsPassed + TestsFailed]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
