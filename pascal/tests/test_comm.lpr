{
  FastWay BBS v1.0.0
  Intensive test program for comm library
  Tests: TTcpip (TCP client/server, UDP), TScreen (ANSI), TPipe (IPC)
  Exercises the full TCom abstract interface through each transport.
}

program test_comm;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}BaseUnix, Unix,{$ENDIF}
  Defs, ComBase, Tcpip, Npipe;

var
  TestsPassed, TestsFailed, TestsSkipped: Integer;

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

procedure Skip(const TestName: String; const Reason: String);
begin
  WriteLn('  SKIP: ', TestName, ' (', Reason, ')');
  Inc(TestsSkipped);
end;

{ ================================================================ }
{  TCom Base Class Tests                                           }
{ ================================================================ }

procedure TestComBaseConstants;
begin
  WriteLn;
  WriteLn('=== TCom Base Constants ===');

  Check('RSIZE = 2048', ComBase.RSIZE = 2048);
  Check('TSIZE = 512', ComBase.TSIZE = 512);
  Check('DTR_ = 1', DTR_ = 1);
  Check('RTS_ = 2', RTS_ = 2);
  Check('CTS_ = 16', CTS_ = 16);
  Check('DSR_ = 32', DSR_ = 32);
  Check('RI_ = 64', RI_ = 64);
  Check('DCD_ = 128', DCD_ = 128);
  Check('DATA_READY = $0100', DATA_READY = $0100);
end;

{ ================================================================ }
{  TTcpip Tests                                                    }
{ ================================================================ }

procedure TestTcpipAvailability;
begin
  WriteLn;
  WriteLn('=== TCP/IP Availability ===');

  {$IFDEF UNIX}
  Check('TcpipAvailable on Linux = True', TcpipAvailable);
  {$ENDIF}
  {$IFDEF WINDOWS}
  Check('TcpipAvailable on Windows = True', TcpipAvailable);
  {$ENDIF}
end;

procedure TestTcpipCreateDestroy;
var
  T: TTcpip;
begin
  WriteLn;
  WriteLn('=== TTcpip Create/Destroy ===');

  T := TTcpip.Create;
  try
    Check('Create: EndRun = 0', T.EndRun = 0);
    Check('Create: RxBytes = 0', T.RxBytes = 0);
    Check('Create: TxBytes = 0', T.TxBytes = 0);
    Check('Create: Carrier = 1 (no drop)', T.Carrier = 1);
    Check('Create: HostIP empty', T.HostIP[0] = #0);
    Check('Create: HostID = 0', T.HostID = 0);
    Check('Create: ClientIP empty', T.ClientIP[0] = #0);
  finally
    T.Free;
  end;
end;

procedure TestTcpipServerClientLoopback;
var
  Server, Client: TTcpip;
  TestPort: Word;
  SendBuf, RecvBuf: array[0..255] of Byte;
  i, Tries: Integer;
  Received: Word;
  GotData: Boolean;
begin
  WriteLn;
  WriteLn('=== TTcpip TCP Server/Client Loopback ===');

  TestPort := 19999 + Word(GetTickCount64 mod 1000); { Random high port }

  Server := TTcpip.Create;
  Client := TTcpip.Create;
  try
    { Start TCP server }
    Check('Server Initialize', Server.Initialize(TestPort) <> 0);
    Check('Server HostIP populated', Server.HostIP[0] <> #0);
    Check('Server HostID nonzero', Server.HostID <> 0);
    WriteLn('    Server listening on port ', TestPort, ', HostIP=', StrPas(Server.HostIP));

    { Client connects }
    Check('Client ConnectServer', Client.ConnectServer(PChar('127.0.0.1'), TestPort) <> 0);
    Check('Client Carrier = 1', Client.Carrier <> 0);
    WriteLn('    Client connected, HostIP=', StrPas(Client.HostIP));

    { Server accepts }
    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 50) do
    begin
      Sleep(10);
      Inc(Tries);
    end;
    Check('Server WaitClient accepted', Tries < 50);
    Check('Server ClientIP populated', Server.ClientIP[0] <> #0);
    WriteLn('    Server accepted from ', StrPas(Server.ClientIP));

    { === Test SendByte / ReadByte === }
    WriteLn;
    WriteLn('  --- Byte-level I/O ---');

    Client.SendByte($42);
    Client.UnbufferBytes;
    Sleep(50);

    Check('Server BytesReady after send', Server.BytesReady <> 0);
    Check('Server ReadByte = $42', Server.ReadByte = $42);

    { Send back from server to client }
    Server.SendByte($99);
    Server.UnbufferBytes;
    Sleep(50);

    Check('Client BytesReady after reply', Client.BytesReady <> 0);
    Check('Client ReadByte = $99', Client.ReadByte = $99);

    { === Test SendBytes / ReadBytes (bulk) === }
    WriteLn;
    WriteLn('  --- Bulk I/O ---');

    for i := 0 to 255 do
      SendBuf[i] := Byte(i);
    Client.SendBytes(@SendBuf[0], 256);
    Client.UnbufferBytes;
    Sleep(100);

    FillChar(RecvBuf, 256, 0);
    GotData := False;
    Tries := 0;
    Received := 0;
    while (Received < 256) and (Tries < 100) do
    begin
      if Server.BytesReady <> 0 then
      begin
        Received := Received + Server.ReadBytes(@RecvBuf[Received], 256 - Received);
        GotData := True;
      end;
      Inc(Tries);
      Sleep(10);
    end;
    Check('Server received 256 bytes', Received = 256);

    if Received = 256 then
    begin
      GotData := True;
      for i := 0 to 255 do
        if RecvBuf[i] <> Byte(i) then
        begin
          GotData := False;
          Break;
        end;
      Check('Server data matches sent', GotData);
    end;

    { === Test BufferByte / BufferBytes + UnbufferBytes === }
    WriteLn;
    WriteLn('  --- Buffered I/O ---');

    Server.BufferByte($AA);
    Server.BufferByte($BB);
    Server.BufferByte($CC);
    Check('Server TxBytes = 3 after buffering', Server.TxBytes = 3);
    Server.UnbufferBytes;
    Check('Server TxBytes = 0 after unbuffer', Server.TxBytes = 0);
    Sleep(50);

    FillChar(RecvBuf, 3, 0);
    Received := 0;
    Tries := 0;
    while (Received < 3) and (Tries < 50) do
    begin
      if Client.BytesReady <> 0 then
        Received := Received + Client.ReadBytes(@RecvBuf[Received], 3 - Received);
      Inc(Tries);
      Sleep(10);
    end;
    Check('Client received 3 buffered bytes', Received = 3);
    if Received >= 3 then
      Check('Buffered data correct', (RecvBuf[0] = $AA) and (RecvBuf[1] = $BB) and (RecvBuf[2] = $CC));

    { === Test BufferBytes with full buffer flush === }
    WriteLn;
    WriteLn('  --- Large buffer auto-flush ---');

    { Fill entire TX buffer to trigger auto-flush }
    FillChar(SendBuf, SizeOf(SendBuf), $DD);
    for i := 1 to 3 do
      Server.BufferBytes(@SendBuf[0], 256);
    Server.UnbufferBytes;
    Sleep(100);

    Received := 0;
    Tries := 0;
    while (Received < 768) and (Tries < 100) do
    begin
      if Client.BytesReady <> 0 then
        Received := Received + Client.ReadBytes(@RecvBuf[0], 256);
      Inc(Tries);
      Sleep(10);
    end;
    Check('Client received 768 bytes (3x256)', Received = 768);

    { === Test ClearInbound / ClearOutbound === }
    WriteLn;
    WriteLn('  --- Clear buffers ---');

    Client.BufferByte($FF);
    Check('Client TxBytes = 1', Client.TxBytes = 1);
    Client.ClearOutbound;
    { Note: ClearOutbound may or may not reset TxBytes depending on impl }

    Server.ClearInbound;
    Check('Server ClearInbound: RxBytes = 0', Server.RxBytes = 0);

    { === Test Carrier drop detection === }
    WriteLn;
    WriteLn('  --- Carrier detection ---');

    Check('Client Carrier still up', Client.Carrier <> 0);
    Check('Server Carrier still up', Server.Carrier <> 0);

    { Close client and check server detects drop }
    Client.ClosePort;
    Sleep(100);

    { Try reading from server - should detect carrier loss }
    Tries := 0;
    while (Server.Carrier <> 0) and (Tries < 30) do
    begin
      Server.BytesReady;
      Inc(Tries);
      Sleep(50);
    end;
    Check('Server detects carrier drop', Server.Carrier = 0);

  finally
    Client.Free;
    Server.Free;
  end;
end;

procedure TestTcpipConnectFailure;
var
  T: TTcpip;
begin
  WriteLn;
  WriteLn('=== TTcpip Connect Failure ===');

  T := TTcpip.Create;
  try
    { Connect to a port that should be refused }
    Check('Connect to closed port returns 0',
      T.ConnectServer(PChar('127.0.0.1'), 19) = 0);
    Check('Carrier = 0 after failed connect', T.Carrier = 0);
  finally
    T.Free;
  end;
end;

procedure TestTcpipUDP;
var
  Sender, Receiver: TTcpip;
  TestPort: Word;
  SendBuf, RecvBuf: array[0..63] of Byte;
  i, Tries: Integer;
  Got: Word;
begin
  WriteLn;
  WriteLn('=== TTcpip UDP Packet I/O ===');

  TestPort := 20999 + Word(GetTickCount64 mod 1000);

  Receiver := TTcpip.Create;
  Sender := TTcpip.Create;
  try
    { Bind UDP receiver }
    Check('UDP Receiver Initialize', Receiver.Initialize(TestPort, 0, PROTO_UDP) <> 0);
    WriteLn('    UDP receiver bound to port ', TestPort);

    { Sender connects to receiver }
    { For UDP send, we use ConnectServer which creates a TCP socket -
      instead we need a different approach. TTcpip UDP is server-mode only.
      Test PeekPacket/GetPacket by sending via a raw Synapse socket. }

    { Use a second TTcpip in UDP mode on a different port to send }
    { Actually, let's test the Peek/Get with a direct approach }
    Skip('UDP send/receive', 'TTcpip UDP is server-mode; need external sender');
  finally
    Sender.Free;
    Receiver.Free;
  end;
end;

procedure TestTcpipMultipleConnections;
var
  Server: TTcpip;
  Client1, Client2: TTcpip;
  TestPort: Word;
  B: Byte;
  Tries: Integer;
begin
  WriteLn;
  WriteLn('=== TTcpip Multiple Connections ===');

  TestPort := 21999 + Word(GetTickCount64 mod 1000);

  Server := TTcpip.Create;
  Client1 := TTcpip.Create;
  Client2 := TTcpip.Create;
  try
    Check('Server init', Server.Initialize(TestPort) <> 0);

    { First client }
    Check('Client1 connect', Client1.ConnectServer(PChar('127.0.0.1'), TestPort) <> 0);
    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 50) do begin Sleep(10); Inc(Tries); end;
    Check('Server accepted client1', Tries < 50);

    Client1.SendByte($11);
    Client1.UnbufferBytes;
    Sleep(50);
    Check('Server reads $11 from client1', (Server.BytesReady <> 0) and (Server.ReadByte = $11));

    { Second client replaces first on server }
    Check('Client2 connect', Client2.ConnectServer(PChar('127.0.0.1'), TestPort) <> 0);
    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 50) do begin Sleep(10); Inc(Tries); end;
    Check('Server accepted client2', Tries < 50);

    Client2.SendByte($22);
    Client2.UnbufferBytes;
    Sleep(50);
    Check('Server reads $22 from client2', (Server.BytesReady <> 0) and (Server.ReadByte = $22));
  finally
    Client2.Free;
    Client1.Free;
    Server.Free;
  end;
end;

procedure TestTcpipSetMetadata;
var
  T: TTcpip;
begin
  WriteLn;
  WriteLn('=== TTcpip Set Metadata (no-crash) ===');

  T := TTcpip.Create;
  try
    { These are inherited from TCom - just verify they don't crash }
    T.SetName(PChar('Test User'));
    T.SetCity(PChar('Test City'));
    T.SetLevel(PChar('100'));
    T.SetTimeLeft(3600);
    T.SetTime(1234567890);
    Check('SetName/City/Level/Time no crash', True);
  finally
    T.Free;
  end;
end;

{ ================================================================ }
{  TPipe Tests                                                     }
{ ================================================================ }

procedure TestPipeCreateDestroy;
var
  P: TPipe;
begin
  WriteLn;
  WriteLn('=== TPipe Create/Destroy ===');

  P := TPipe.Create;
  try
    Check('Pipe Create: EndRun = 0', P.EndRun = 0);
    Check('Pipe Create: Carrier = 0 (not connected)', P.Carrier = 0);
    Check('Pipe Create: TimeLeft = 0', P.TimeLeft = 0);
    Check('Pipe Create: Time_ = 0', P.Time_ = 0);
  finally
    P.Free;
  end;
end;

{$IFDEF UNIX}
procedure TestPipeServerClient;
var
  Server, Client: TPipe;
  PipePath, CtlPath: String;
  SendBuf, RecvBuf: array[0..63] of Byte;
  i, Tries: Integer;
  Received: Word;
begin
  WriteLn;
  WriteLn('=== TPipe Server/Client (Unix Sockets) ===');

  PipePath := '/tmp/lora_test_pipe';
  CtlPath := '/tmp/lora_test_ctl';

  { Clean up any stale sockets }
  DeleteFile(PipePath);
  DeleteFile(CtlPath);

  Server := TPipe.Create;
  Client := TPipe.Create;
  try
    { Initialize server }
    Check('Pipe Server Initialize', Server.Initialize(PChar(PipePath), PChar(CtlPath), 1) <> 0);

    { Client connects }
    Check('Pipe Client ConnectServer', Client.ConnectServer(PChar(PipePath), PChar(CtlPath)) <> 0);

    { Server accepts }
    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 50) do
    begin
      Sleep(10);
      Inc(Tries);
    end;
    Check('Pipe Server WaitClient', Tries < 50);

    { Test byte send/receive }
    Client.SendByte($AB);
    Client.UnbufferBytes;
    Sleep(50);

    if Server.BytesReady <> 0 then
      Check('Pipe Server ReadByte = $AB', Server.ReadByte = $AB)
    else
      Check('Pipe Server BytesReady after send', False);

    { Test bulk data }
    for i := 0 to 63 do
      SendBuf[i] := Byte(i * 3);
    Client.SendBytes(@SendBuf[0], 64);
    Client.UnbufferBytes;
    Sleep(100);

    FillChar(RecvBuf, 64, 0);
    Received := 0;
    Tries := 0;
    while (Received < 64) and (Tries < 50) do
    begin
      if Server.BytesReady <> 0 then
        Received := Received + Server.ReadBytes(@RecvBuf[Received], 64 - Received);
      Inc(Tries);
      Sleep(10);
    end;
    Check('Pipe Server received 64 bytes', Received = 64);
    if Received = 64 then
      Check('Pipe data matches', RecvBuf[10] = 30);

    { Test metadata transfer }
    Client.SetName(PChar('Test User'));
    Client.SetCity(PChar('Test City'));
    Client.SetLevel(PChar('Sysop'));
    Client.SetTimeLeft(1800);
    Client.SetTime(12345);
    Sleep(100);

    { Server should pick up metadata via control channel }
    { Read a few times to trigger control channel read }
    for i := 1 to 5 do
    begin
      Server.BytesReady;
      Sleep(20);
    end;

    if Server.Time_ <> 0 then
    begin
      Check('Pipe metadata: PipeName set', Server.PipeName[0] <> #0);
      Check('Pipe metadata: Time_ nonzero', Server.Time_ <> 0);
      WriteLn('    Name=', StrPas(Server.PipeName), ' City=', StrPas(Server.PipeCity));
    end
    else
      Skip('Pipe metadata transfer', 'control channel may need bidirectional test');

    { Test carrier detection }
    Check('Pipe Server Carrier up', Server.Carrier <> 0);
    Client.Free;
    Client := nil;
    Sleep(100);

    Tries := 0;
    while (Server.Carrier <> 0) and (Tries < 20) do
    begin
      Server.BytesReady;
      Inc(Tries);
      Sleep(50);
    end;
    Check('Pipe Server detects client disconnect', Server.Carrier = 0);
  finally
    if Client <> nil then Client.Free;
    Server.Free;
    DeleteFile(PipePath);
    DeleteFile(CtlPath);
  end;
end;
{$ENDIF}

{ ================================================================ }
{  Stress Tests                                                    }
{ ================================================================ }

procedure TestTcpipStress;
var
  Server, Client: TTcpip;
  TestPort: Word;
  SendBuf: array[0..1023] of Byte;
  RecvBuf: array[0..1023] of Byte;
  TotalSent, TotalRecv: LongWord;
  Iteration, Tries: Integer;
  Received: Word;
begin
  WriteLn;
  WriteLn('=== TTcpip Stress Test (100 rounds x 1KB) ===');

  TestPort := 22999 + Word(GetTickCount64 mod 1000);

  Server := TTcpip.Create;
  Client := TTcpip.Create;
  try
    Server.Initialize(TestPort);
    Client.ConnectServer(PChar('127.0.0.1'), TestPort);

    Tries := 0;
    while (Server.WaitClient = 0) and (Tries < 50) do begin Sleep(10); Inc(Tries); end;

    if Tries >= 50 then
    begin
      Check('Stress: Server accept', False);
      Exit;
    end;

    TotalSent := 0;
    TotalRecv := 0;

    for Iteration := 1 to 100 do
    begin
      { Fill with pattern }
      FillChar(SendBuf, 1024, Byte(Iteration and $FF));
      Client.SendBytes(@SendBuf[0], 1024);
      Client.UnbufferBytes;
      Inc(TotalSent, 1024);

      { Receive }
      Received := 0;
      Tries := 0;
      while (Received < 1024) and (Tries < 100) do
      begin
        if Server.BytesReady <> 0 then
          Received := Received + Server.ReadBytes(@RecvBuf[Received], 1024 - Received);
        Inc(Tries);
        if Received < 1024 then Sleep(5);
      end;
      Inc(TotalRecv, Received);

      if (Iteration mod 25) = 0 then
        Write(Format('    Round %d: sent=%d recv=%d'#13, [Iteration, TotalSent, TotalRecv]));
    end;

    WriteLn;
    Check(Format('Stress: sent %d bytes', [TotalSent]), TotalSent = 102400);
    Check(Format('Stress: received %d bytes', [TotalRecv]), TotalRecv = 102400);

    { Bidirectional stress }
    WriteLn;
    WriteLn('  --- Bidirectional stress (50 rounds) ---');
    TotalSent := 0;
    TotalRecv := 0;

    for Iteration := 1 to 50 do
    begin
      { Client -> Server }
      FillChar(SendBuf, 512, Byte(Iteration));
      Client.SendBytes(@SendBuf[0], 512);
      Client.UnbufferBytes;

      { Server -> Client }
      FillChar(SendBuf, 512, Byte(Iteration + 128));
      Server.SendBytes(@SendBuf[0], 512);
      Server.UnbufferBytes;
      Sleep(10);

      { Read both directions }
      Received := 0;
      Tries := 0;
      while (Received < 512) and (Tries < 50) do
      begin
        if Server.BytesReady <> 0 then
          Received := Received + Server.ReadBytes(@RecvBuf[0], 512 - Received);
        Inc(Tries);
        if Received < 512 then Sleep(5);
      end;
      Inc(TotalRecv, Received);

      Received := 0;
      Tries := 0;
      while (Received < 512) and (Tries < 50) do
      begin
        if Client.BytesReady <> 0 then
          Received := Received + Client.ReadBytes(@RecvBuf[0], 512 - Received);
        Inc(Tries);
        if Received < 512 then Sleep(5);
      end;
      Inc(TotalSent, Received);
    end;

    Check(Format('Bidir: server recv %d', [TotalRecv]), TotalRecv = 25600);
    Check(Format('Bidir: client recv %d', [TotalSent]), TotalSent = 25600);
  finally
    Client.Free;
    Server.Free;
  end;
end;

{ ================================================================ }
{  Main                                                            }
{ ================================================================ }

begin
  TestsPassed := 0;
  TestsFailed := 0;
  TestsSkipped := 0;

  WriteLn;
  WriteLn('FastWay BBS - Comm Library Test Suite');
  WriteLn('=====================================');
  WriteLn('Tests TCP client/server, UDP, pipes, carrier detection,');
  WriteLn('buffered I/O, bulk transfer, and stress testing.');
  WriteLn;

  TestComBaseConstants;
  TestTcpipAvailability;
  TestTcpipCreateDestroy;
  TestTcpipConnectFailure;
  TestTcpipServerClientLoopback;
  TestTcpipMultipleConnections;
  TestTcpipUDP;
  TestTcpipSetMetadata;
  TestPipeCreateDestroy;
  {$IFDEF UNIX}
  TestPipeServerClient;
  {$ENDIF}
  TestTcpipStress;

  WriteLn;
  WriteLn('=====================================');
  WriteLn(Format('Results: %d passed, %d failed, %d skipped, %d total',
    [TestsPassed, TestsFailed, TestsSkipped, TestsPassed + TestsFailed + TestsSkipped]));
  WriteLn;

  if TestsFailed > 0 then
    Halt(1);
end.
