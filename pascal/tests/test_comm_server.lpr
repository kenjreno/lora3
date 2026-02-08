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
  Done: Boolean;

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

    { Wait for client }
    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 3000) do { 30 second timeout }
    begin
      Sleep(10);
      Inc(Tries);
    end;

    if Tries >= 3000 then
    begin
      WriteLn('  TIMEOUT: No client connected within 30 seconds');
      Exit;
    end;

    WriteLn('  Client connected from ', StrPas(Server.ClientIP));
    WriteLn;

    { Test 1: Single byte echo }
    WriteLn('  [Test 1] Byte echo...');
    Tries := 0;
    while (Server.BytesReady = 0) and (Tries < 200) do begin Sleep(10); Inc(Tries); end;
    if Server.BytesReady <> 0 then
    begin
      B := Server.ReadByte;
      WriteLn('    Received: $', IntToHex(B, 2));
      Server.SendByte(B xor $FF); { Echo back XOR'd }
      Server.UnbufferBytes;
      WriteLn('    Sent back: $', IntToHex(B xor $FF, 2));
      WriteLn('  PASS: Byte echo');
    end
    else
      WriteLn('  FAIL: No byte received');

    { Test 2: 256-byte block with verification }
    WriteLn;
    WriteLn('  [Test 2] 256-byte block transfer...');
    FillChar(Buf, 256, 0);
    Received := 0;
    Tries := 0;
    while (Received < 256) and (Tries < 200) do
    begin
      if Server.BytesReady <> 0 then
        Received := Received + Server.ReadBytes(@Buf[Received], 256 - Received);
      Inc(Tries);
      if Received < 256 then Sleep(10);
    end;
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

    { Test 3: Stress - receive 100KB }
    WriteLn;
    WriteLn('  [Test 3] Stress test (100KB)...');
    Total := 0;
    Tries := 0;
    while (Total < 102400) and (Tries < 5000) and (Server.Carrier <> 0) do
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
      if (Total mod 10240) = 0 then
        Write(Format('    %d / 102400 bytes'#13, [Total]));
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
      WriteLn('  FAIL: Only received ', Total, ' bytes');

    { Test 4: Bidirectional - server sends while receiving }
    WriteLn;
    WriteLn('  [Test 4] Bidirectional test (50 rounds x 512B)...');
    Total := 0;
    for i := 1 to 50 do
    begin
      { Send 512 bytes }
      FillChar(Buf, 512, Byte(i));
      Server.SendBytes(@Buf[0], 512);
      Server.UnbufferBytes;

      { Receive 512 bytes }
      Received := 0;
      Tries := 0;
      while (Received < 512) and (Tries < 200) do
      begin
        if Server.BytesReady <> 0 then
          Received := Received + Server.ReadBytes(@Buf[Received], 512 - Received);
        Inc(Tries);
        if Received < 512 then Sleep(5);
      end;
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
    while (Server.Carrier <> 0) and (Tries < 500) do
    begin
      Server.BytesReady;
      Inc(Tries);
      Sleep(10);
    end;
    if Server.Carrier = 0 then
      WriteLn('  PASS: Detected client disconnect')
    else
      WriteLn('  FAIL: Client still appears connected');

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
  i, Tries: Integer;
  OK: Boolean;
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
    Tries := 0;
    while (Server.BytesReady = 0) and (Tries < 200) do begin Sleep(10); Inc(Tries); end;
    if Server.BytesReady <> 0 then
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
    FillChar(Buf, 64, 0);
    Received := 0;
    Tries := 0;
    while (Received < 64) and (Tries < 200) do
    begin
      if Server.BytesReady <> 0 then
        Received := Received + Server.ReadBytes(@Buf[Received], 64 - Received);
      Inc(Tries);
      if Received < 64 then Sleep(10);
    end;
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
    while (Server.Carrier <> 0) and (Tries < 300) do
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
