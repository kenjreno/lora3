{
  FastWay BBS v1.0.0
  Comm test server - Run in terminal 1, then run test_comm_client in terminal 2
  Tests TCP server, pipe server, accept, data relay, carrier detection
  Usage: test_comm_server [port] (default 23000)
}

program test_comm_server;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils,
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  Defs, ComBase, Tcpip, Npipe;

var
  TestPort: Word;

{ Helper: wait for data with timeout, returns True if data available }
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

procedure RunTcpServer;
var
  Server: TTcpip;
  Buf: array[0..2047] of Byte;
  Received, Total: LongWord;
  B: Byte;
  i, Tries: Integer;
  OK: Boolean;
begin
  WriteLn;
  WriteLn('=== TCP Server Test ===');

  Server := TTcpip.Create;
  try
    if Server.Initialize(TestPort) = 0 then
    begin
      WriteLn('  ERROR: Could not bind to port ', TestPort);
      Exit;
    end;
    WriteLn('  Listening on port ', TestPort, ' (HostIP=', StrPas(Server.HostIP), ')');
    WriteLn('  Waiting for client... (run test_comm_client in another terminal)');

    { Wait for client - 60 second timeout }
    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 6000) do
    begin
      Sleep(10);
      Inc(Tries);
    end;

    if Tries >= 6000 then
    begin
      WriteLn('  TIMEOUT: No client connected within 60 seconds');
      Exit;
    end;

    WriteLn('  Client connected from ', StrPas(Server.ClientIP));
    WriteLn;

    { Test 1: Single byte echo }
    WriteLn('  [Test 1] Byte echo...');
    if WaitData(Server, 5000) then
    begin
      B := Server.ReadByte;
      WriteLn('    Received: $', IntToHex(B, 2));
      Server.SendByte(B xor $FF);
      Server.UnbufferBytes;
      WriteLn('    Sent back: $', IntToHex(B xor $FF, 2));
      WriteLn('  PASS: Byte echo');
    end
    else
      WriteLn('  FAIL: No byte received');

    { Test 2: 256-byte block with verification }
    WriteLn;
    WriteLn('  [Test 2] 256-byte block transfer...');
    Received := RecvExact(Server, @Buf[0], 256, 5000);
    WriteLn('    Received ', Received, ' bytes');

    if Received = 256 then
    begin
      OK := True;
      for i := 0 to 255 do
        if Buf[i] <> Byte(i) then begin OK := False; Break; end;
      if OK then
        WriteLn('  PASS: Block data verified')
      else
        WriteLn('  FAIL: Block data mismatch');

      { Send back reversed }
      for i := 0 to 255 do
        Buf[i] := Byte(255 - i);
      Server.SendBytes(@Buf[0], 256);
      Server.UnbufferBytes;
      WriteLn('    Sent 256 bytes back (reversed)');
    end
    else
      WriteLn('  FAIL: Only received ', Received, ' of 256');

    { Test 3: Stress - receive 100KB with 30s idle timeout }
    WriteLn;
    WriteLn('  [Test 3] Stress test (100KB)...');
    Total := 0;
    Tries := 0;
    while (Total < 102400) and (Tries < 30000) and (Server.Carrier <> 0) do
    begin
      if Server.BytesReady <> 0 then
      begin
        Received := Server.ReadBytes(@Buf[0], SizeOf(Buf));
        Inc(Total, Received);
        Tries := 0; { Reset timeout on data }
      end
      else
      begin
        Inc(Tries);
        Sleep(1);
      end;
    end;
    WriteLn(Format('    %d / 102400 bytes', [Total]));
    if Total = 102400 then
    begin
      WriteLn('  PASS: Received 100KB');
      { Send ack }
      Server.SendByte($AA);
      Server.UnbufferBytes;
    end
    else
    begin
      WriteLn('  FAIL: Only received ', Total, ' bytes');
      if Server.Carrier = 0 then
        WriteLn('    (carrier dropped)')
      else
        WriteLn('    (idle timeout - 30s)');
    end;

    { Test 4: Bidirectional - server sends while receiving }
    { Wait for sync byte from client to resynchronize }
    WriteLn;
    WriteLn('  [Test 4] Bidirectional test (50 rounds x 512B)...');
    if WaitData(Server, 15000) then
    begin
      B := Server.ReadByte; { Consume sync byte $BB }
      WriteLn('    Sync received ($', IntToHex(B, 2), ')');
    end
    else
    begin
      WriteLn('  FAIL: No sync byte from client');
      WriteLn('  Skipping remaining tests');
      Exit;
    end;

    Total := 0;
    for i := 1 to 50 do
    begin
      { Send 512 bytes }
      FillChar(Buf, 512, Byte(i));
      Server.SendBytes(@Buf[0], 512);
      Server.UnbufferBytes;

      { Receive 512 bytes }
      Received := RecvExact(Server, @Buf[0], 512, 5000);
      Inc(Total, Received);
    end;
    if Total = 25600 then
      WriteLn('  PASS: Bidirectional 25600 bytes')
    else
      WriteLn('  FAIL: Bidirectional received ', Total, ' of 25600');

    { Test 5: Carrier detection - wait for client to disconnect }
    WriteLn;
    WriteLn('  [Test 5] Carrier detection...');
    WriteLn('    Waiting for client disconnect...');
    Tries := 0;
    while (Server.Carrier <> 0) and (Tries < 1500) do
    begin
      Server.BytesReady; { Triggers carrier check }
      Inc(Tries);
      Sleep(10);
    end;
    if Server.Carrier = 0 then
      WriteLn('  PASS: Detected client disconnect')
    else
      WriteLn('  FAIL: Client still appears connected (15s timeout)');

  finally
    Server.Free;
  end;
end;

{$IFDEF UNIX}
procedure RunPipeServer;
var
  Server: TPipe;
  Buf: array[0..255] of Byte;
  Received: Word;
  B: Byte;
  Tries: Integer;
  PipePath, CtlPath: String;
begin
  WriteLn;
  WriteLn('=== Pipe Server Test ===');

  PipePath := '/tmp/lora_test_pipe';
  CtlPath := '/tmp/lora_test_ctl';
  DeleteFile(PipePath);
  DeleteFile(CtlPath);

  Server := TPipe.Create;
  try
    if Server.Initialize(PChar(PipePath), PChar(CtlPath), 1) = 0 then
    begin
      WriteLn('  ERROR: Could not create pipe');
      Exit;
    end;
    WriteLn('  Pipe server ready at ', PipePath);
    WriteLn('  Waiting for client...');

    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 3000) do
    begin
      Sleep(10);
      Inc(Tries);
    end;

    if Tries >= 3000 then
    begin
      WriteLn('  TIMEOUT: No pipe client within 30 seconds');
      Exit;
    end;

    WriteLn('  Pipe client connected');

    { Echo test }
    WriteLn('  [Test] Pipe byte echo...');
    if WaitData(Server, 5000) then
    begin
      B := Server.ReadByte;
      Server.SendByte(B xor $FF);
      Server.UnbufferBytes;
      WriteLn('  PASS: Pipe byte echo ($', IntToHex(B, 2), ' -> $', IntToHex(B xor $FF, 2), ')');
    end
    else
      WriteLn('  FAIL: No pipe byte received');

    { Block test }
    WriteLn('  [Test] Pipe 64-byte block...');
    Received := RecvExact(Server, @Buf[0], 64, 5000);
    if Received = 64 then
    begin
      WriteLn('  PASS: Pipe received 64 bytes');
      Server.SendBytes(@Buf[0], 64);
      Server.UnbufferBytes;
    end
    else
      WriteLn('  FAIL: Pipe only received ', Received);

    { Wait for disconnect }
    WriteLn('  Waiting for pipe client disconnect...');
    Tries := 0;
    while (Server.Carrier <> 0) and (Tries < 500) do
    begin
      Server.BytesReady;
      Inc(Tries);
      Sleep(10);
    end;
    if Server.Carrier = 0 then
      WriteLn('  PASS: Pipe disconnect detected')
    else
      WriteLn('  FAIL: Pipe still connected');

  finally
    Server.Free;
    DeleteFile(PipePath);
    DeleteFile(CtlPath);
  end;
end;
{$ENDIF}

begin
  WriteLn;
  WriteLn('FastWay BBS - Comm Test Server');
  WriteLn('==============================');
  WriteLn('Run test_comm_client in another terminal to execute tests.');
  WriteLn;

  if ParamCount >= 1 then
    TestPort := Word(StrToIntDef(ParamStr(1), 23000))
  else
    TestPort := 23000;

  RunTcpServer;
  {$IFDEF UNIX}
  RunPipeServer;
  {$ENDIF}

  WriteLn;
  WriteLn('Server tests complete.');
end.
