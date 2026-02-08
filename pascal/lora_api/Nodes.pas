{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of nodes.cpp - TNodes and TNodeFlags classes
  FidoNet node database management. Reads/writes nodes.dat with sorted
  insertion, nodelist index lookup, and node flags mapping.
  Uses TFileStream for binary I/O and TCollection for in-memory lists.
}

unit Nodes;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc299, Collect, Address;

type
  TNodes = class
  public
    DataFile:       String;
    Address_:       array[0..63] of Char;
    Zone:           Word;
    Net:            Word;
    Node:           Word;
    Point:          Word;
    SystemName:     array[0..63] of Char;
    SysopName:      array[0..47] of Char;
    Location:       array[0..47] of Char;
    Speed:          LongWord;
    MinSpeed:       LongWord;
    Phone:          array[0..47] of Char;
    Flags:          array[0..47] of Char;
    DialCmd:        array[0..31] of Char;
    RemapMail:      Byte;
    SessionPwd:     array[0..31] of Char;
    AreaMgrPwd:     array[0..31] of Char;
    OutPktPwd:      array[0..8] of Char;
    InPktPwd:       array[0..8] of Char;
    TicPwd:         array[0..31] of Char;
    UsePkt22:       Byte;
    CreateNewAreas: Byte;
    NewAreasFilter: array[0..127] of Char;
    Packer:         array[0..15] of Char;
    ImportPOP3Mail: Byte;
    UseInetAddress: Byte;
    InetAddress:    array[0..63] of Char;
    Pop3Pwd:        array[0..31] of Char;
    DefaultZone:    Word;
    Nodelist:       array[0..63] of Char;
    Nodediff:       array[0..63] of Char;
    Level:          Word;
    AccessFlags:    LongWord;
    DenyFlags:      LongWord;
    TicLevel:       Word;
    TicAccessFlags: LongWord;
    TicDenyFlags:   LongWord;
    LinkNewEcho:    Byte;
    EchoMaint:      Byte;
    ChangeEchoTag:  Byte;
    NotifyAreafix:  Byte;
    CreateNewTic:   Byte;
    LinkNewTic:     Byte;
    TicMaint:       Byte;
    ChangeTicTag:   Byte;
    NotifyRaid:     Byte;
    MailerAka:      array[0..47] of Char;
    EchoAka:        array[0..47] of Char;
    TicAka:         array[0..47] of Char;
    NewTicFilter:   array[0..127] of Char;

    constructor Create; overload;
    constructor Create(pszDataPath: PChar); overload;
    destructor Destroy; override;

    procedure Add;
    procedure AddNodelist(name, diff: PChar; AZone: Word = 0);
    procedure Delete;
    procedure DeleteNodelist;
    function  First: Word;
    function  FirstNodelist: Word;
    procedure LoadNodelist;
    function  Next: Word;
    function  NextNodelist: Word;
    procedure New_;
    function  Previous: Word;
    function  Read(usZone, usNet, usNode, usPoint: Word;
                   pszDomain: PChar = nil): Word; overload;
    function  Read(lpAddress: TAddress; flAddNodelist: Word = 1): Word; overload;
    function  Read(pszAddress: PChar; flAddNodelist: Word = 1): Word; overload;
    function  ReadNodelist(lpAddress: TAddress): Word;
    procedure SaveNodelist;
    procedure Update;

  private
    fdDat:     TFileStream;
    Addr1:     TAddress;
    Addr2:     TAddress;
    ListData:  TCollection;

    function  OpenDat: Boolean;
    procedure Class2Struct(var N: NODES_REC);
    procedure Struct2Class(var N: NODES_REC);
  end;

  TNodeFlags = class
  public
    Flags_: array[0..63] of Char;
    Cmd:    array[0..63] of Char;

    constructor Create; overload;
    constructor Create(pszDataPath: PChar); overload;
    destructor Destroy; override;

    procedure Add;
    procedure Delete;
    procedure DeleteAll;
    function  First: Word;
    function  Next: Word;
    function  Read(pszFlag: PChar): Word; overload;
    function  Read(index: Word): Word; overload;
    procedure Save;
    procedure Update;

  private
    DataFile: String;
    nf:       NODEFLAGS_REC;
    List:     TCollection;
  end;

implementation

{ --- TNodes --- }

constructor TNodes.Create;
begin
  inherited Create;
  DataFile := '.' + PathDelim + 'nodes';
  fdDat := nil;
  Addr1 := TAddress.Create;
  Addr2 := TAddress.Create;
  ListData := TCollection.Create;
end;

constructor TNodes.Create(pszDataPath: PChar);
begin
  inherited Create;
  DataFile := IncludeTrailingPathDelimiter(StrPas(pszDataPath)) + 'nodes';
  fdDat := nil;
  Addr1 := TAddress.Create;
  Addr2 := TAddress.Create;
  ListData := TCollection.Create;
end;

destructor TNodes.Destroy;
begin
  FreeAndNil(fdDat);
  Addr1.Free;
  Addr2.Free;
  ListData.Free;
  inherited Destroy;
end;

function TNodes.OpenDat: Boolean;
var
  FName: String;
begin
  if fdDat = nil then
  begin
    FName := DataFile + '.dat';
    if FileExists(FName) then
      fdDat := TFileStream.Create(FName, fmOpenReadWrite or fmShareDenyNone)
    else
      fdDat := TFileStream.Create(FName, fmCreate);
  end;
  Result := (fdDat <> nil);
end;

procedure TNodes.Class2Struct(var N: NODES_REC);
begin
  FillChar(N, SizeOf(NODES_REC), 0);
  StrCopy(N.Address, Address_);
  StrCopy(N.SystemName, SystemName);
  StrCopy(N.SysopName, SysopName);
  StrCopy(N.Location, Location);
  N.Speed := Speed;
  N.MinSpeed := MinSpeed;
  StrCopy(N.Phone, Phone);
  StrCopy(N.Flags, Flags);
  StrCopy(N.DialCmd, DialCmd);
  N.RemapMail := RemapMail;
  StrCopy(N.SessionPwd, SessionPwd);
  StrCopy(N.AreaMgrPwd, AreaMgrPwd);
  StrCopy(N.OutPktPwd, OutPktPwd);
  StrCopy(N.InPktPwd, InPktPwd);
  N.UsePkt22 := UsePkt22;
  N.CreateNewAreas := CreateNewAreas;
  StrCopy(N.NewAreasFilter, NewAreasFilter);
  StrCopy(N.TicPwd, TicPwd);
  StrCopy(N.Packer, Packer);
  N.ImportPOP3Mail := ImportPOP3Mail;
  N.UseInetAddress := UseInetAddress;
  StrCopy(N.InetAddress, InetAddress);
  StrCopy(N.Pop3Pwd, Pop3Pwd);
  N.Level := Level;
  N.AccessFlags := AccessFlags;
  N.DenyFlags := DenyFlags;
  N.TicLevel := TicLevel;
  N.TicAccessFlags := TicAccessFlags;
  N.TicDenyFlags := TicDenyFlags;
  N.LinkNewEcho := LinkNewEcho;
  N.EchoMaint := EchoMaint;
  N.ChangeEchoTag := ChangeEchoTag;
  N.NotifyAreafix := NotifyAreafix;
  N.CreateNewTic := CreateNewTic;
  N.LinkNewTic := LinkNewTic;
  N.TicMaint := TicMaint;
  N.ChangeTicTag := ChangeTicTag;
  N.NotifyRaid := NotifyRaid;
  StrCopy(N.MailerAka, MailerAka);
  StrCopy(N.EchoAka, EchoAka);
  StrCopy(N.TicAka, TicAka);
  StrCopy(N.NewTicFilter, NewTicFilter);
end;

procedure TNodes.Struct2Class(var N: NODES_REC);
var
  Addr: TAddress;
begin
  StrCopy(Address_, N.Address);
  Addr := TAddress.Create;
  try
    Addr.Parse(Address_);
    Zone := Addr.Zone;
    Net := Addr.Net;
    Node := Addr.Node;
    Point := Addr.Point;
  finally
    Addr.Free;
  end;
  StrCopy(SystemName, N.SystemName);
  StrCopy(SysopName, N.SysopName);
  StrCopy(Location, N.Location);
  Speed := N.Speed;
  MinSpeed := N.MinSpeed;
  StrCopy(Phone, N.Phone);
  StrCopy(Flags, N.Flags);
  StrCopy(DialCmd, N.DialCmd);
  RemapMail := N.RemapMail;
  StrCopy(SessionPwd, N.SessionPwd);
  StrCopy(AreaMgrPwd, N.AreaMgrPwd);
  StrCopy(OutPktPwd, N.OutPktPwd);
  StrCopy(InPktPwd, N.InPktPwd);
  UsePkt22 := N.UsePkt22;
  CreateNewAreas := N.CreateNewAreas;
  StrCopy(NewAreasFilter, N.NewAreasFilter);
  StrCopy(TicPwd, N.TicPwd);
  StrCopy(Packer, N.Packer);
  ImportPOP3Mail := N.ImportPOP3Mail;
  UseInetAddress := N.UseInetAddress;
  StrCopy(InetAddress, N.InetAddress);
  StrCopy(Pop3Pwd, N.Pop3Pwd);
  Level := N.Level;
  AccessFlags := N.AccessFlags;
  DenyFlags := N.DenyFlags;
  TicLevel := N.TicLevel;
  TicAccessFlags := N.TicAccessFlags;
  TicDenyFlags := N.TicDenyFlags;
  LinkNewEcho := N.LinkNewEcho;
  EchoMaint := N.EchoMaint;
  ChangeEchoTag := N.ChangeEchoTag;
  NotifyAreafix := N.NotifyAreafix;
  CreateNewTic := N.CreateNewTic;
  LinkNewTic := N.LinkNewTic;
  TicMaint := N.TicMaint;
  ChangeTicTag := N.ChangeTicTag;
  NotifyRaid := N.NotifyRaid;
  StrCopy(MailerAka, N.MailerAka);
  StrCopy(EchoAka, N.EchoAka);
  StrCopy(TicAka, N.TicAka);
  StrCopy(NewTicFilter, N.NewTicFilter);
end;

procedure TNodes.Add;
var
  fsNew: TFileStream;
  N: NODES_REC;
  Saved: Boolean;
  DoClose: Boolean;
begin
  DoClose := False;
  if fdDat = nil then
  begin
    if not OpenDat then Exit;
    DoClose := True;
  end;

  fsNew := TFileStream.Create(DataFile + '.new', fmCreate);
  try
    Saved := False;
    fdDat.Seek(0, soFromBeginning);
    Addr1.Parse(Address_);
    StrCopy(Address_, Addr1.Str);

    while fdDat.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) do
    begin
      if not Saved then
      begin
        Addr2.Parse(N.Address);
        if (Addr2.Zone > Addr1.Zone) or
           ((Addr2.Zone = Addr1.Zone) and (Addr2.Net > Addr1.Net)) or
           ((Addr2.Zone = Addr1.Zone) and (Addr2.Net = Addr1.Net) and (Addr2.Node > Addr1.Node)) or
           ((Addr2.Zone = Addr1.Zone) and (Addr2.Net = Addr1.Net) and (Addr2.Node = Addr1.Node) and (Addr2.Point > Addr1.Point)) or
           ((Addr2.Zone = Addr1.Zone) and (Addr2.Net = Addr1.Net) and (Addr2.Node = Addr1.Node) and (Addr2.Point = Addr1.Point) and
            (StrIComp(Addr2.Domain, Addr1.Domain) > 0)) then
        begin
          Saved := True;
          Class2Struct(N);
          fsNew.Write(N, SizeOf(NODES_REC));
          { Re-read the record we displaced }
          fdDat.Seek(fdDat.Position - SizeOf(NODES_REC), soFromBeginning);
          fdDat.Read(N, SizeOf(NODES_REC));
        end;
      end;
      fsNew.Write(N, SizeOf(NODES_REC));
    end;

    if not Saved then
    begin
      Class2Struct(N);
      fsNew.Write(N, SizeOf(NODES_REC));
    end;

    { Copy back }
    fdDat.Seek(0, soFromBeginning);
    fsNew.Seek(0, soFromBeginning);
    while fsNew.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) do
      fdDat.Write(N, SizeOf(NODES_REC));
  finally
    fsNew.Free;
    SysUtils.DeleteFile(DataFile + '.new');
  end;

  if DoClose then
    FreeAndNil(fdDat);

  if Read(Addr1, 0) = 0 then
  begin
    if First = 0 then
      New_;
  end;
end;

procedure TNodes.Delete;
var
  fsNew: TFileStream;
  N: NODES_REC;
  DoClose: Boolean;
begin
  DoClose := False;
  if fdDat = nil then
  begin
    if not OpenDat then Exit;
    DoClose := True;
  end;

  fsNew := TFileStream.Create(DataFile + '.new', fmCreate);
  try
    fdDat.Seek(0, soFromBeginning);
    while fdDat.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) do
    begin
      if StrIComp(N.Address, Address_) <> 0 then
        fsNew.Write(N, SizeOf(NODES_REC));
    end;

    fdDat.Seek(0, soFromBeginning);
    fsNew.Seek(0, soFromBeginning);
    while fsNew.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) do
      fdDat.Write(N, SizeOf(NODES_REC));
    fdDat.Size := fdDat.Position;
  finally
    fsNew.Free;
    SysUtils.DeleteFile(DataFile + '.new');
  end;

  if DoClose then
    FreeAndNil(fdDat);

  if Next = 0 then
  begin
    if Previous = 0 then
      New_;
  end;
end;

function TNodes.First: Word;
begin
  Result := 0;
  if not OpenDat then Exit;
  fdDat.Seek(0, soFromBeginning);
  Result := Next;
end;

procedure TNodes.New_;
begin
  FillChar(Address_, SizeOf(Address_), 0);
  FillChar(SystemName, SizeOf(SystemName), 0);
  FillChar(SysopName, SizeOf(SysopName), 0);
  FillChar(Location, SizeOf(Location), 0);
  Speed := 0;
  MinSpeed := 0;
  FillChar(Phone, SizeOf(Phone), 0);
  FillChar(Flags, SizeOf(Flags), 0);
  FillChar(DialCmd, SizeOf(DialCmd), 0);
  RemapMail := 0;
  FillChar(SessionPwd, SizeOf(SessionPwd), 0);
  FillChar(AreaMgrPwd, SizeOf(AreaMgrPwd), 0);
  FillChar(OutPktPwd, SizeOf(OutPktPwd), 0);
  FillChar(InPktPwd, SizeOf(InPktPwd), 0);
  FillChar(TicPwd, SizeOf(TicPwd), 0);
  FillChar(NewAreasFilter, SizeOf(NewAreasFilter), 0);
  UsePkt22 := 0;
  CreateNewAreas := 0;
  ImportPOP3Mail := 0;
  UseInetAddress := 0;
  FillChar(InetAddress, SizeOf(InetAddress), 0);
  FillChar(Pop3Pwd, SizeOf(Pop3Pwd), 0);
  FillChar(Packer, SizeOf(Packer), 0);
  Level := 0;
  AccessFlags := 0;
  DenyFlags := 0;
  TicLevel := 0;
  TicAccessFlags := 0;
  TicDenyFlags := 0;
  LinkNewEcho := 0;
  EchoMaint := 0;
  ChangeEchoTag := 0;
  NotifyAreafix := 0;
  CreateNewTic := 0;
  LinkNewTic := 0;
  TicMaint := 0;
  ChangeTicTag := 0;
  NotifyRaid := 0;
  FillChar(MailerAka, SizeOf(MailerAka), 0);
  FillChar(EchoAka, SizeOf(EchoAka), 0);
  FillChar(TicAka, SizeOf(TicAka), 0);
  FillChar(NewTicFilter, SizeOf(NewTicFilter), 0);
end;

function TNodes.Next: Word;
var
  N: NODES_REC;
begin
  Result := 0;
  if not OpenDat then Exit;

  if fdDat.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) then
  begin
    Struct2Class(N);
    Result := 1;
  end;
end;

function TNodes.Previous: Word;
var
  N: NODES_REC;
begin
  Result := 0;
  if fdDat = nil then Exit;

  if fdDat.Position >= SizeOf(NODES_REC) * 2 then
  begin
    fdDat.Seek(fdDat.Position - SizeOf(NODES_REC) * 2, soFromBeginning);
    if fdDat.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) then
    begin
      Struct2Class(N);
      Result := 1;
    end;
  end;
end;

function TNodes.Read(usZone, usNet, usNode, usPoint: Word;
                     pszDomain: PChar): Word;
var
  N: NODES_REC;
  DoClose: Boolean;
begin
  Result := 0;
  New_;
  DoClose := False;

  if fdDat = nil then
  begin
    if not OpenDat then Exit;
    DoClose := True;
  end;

  Addr1.Clear;
  Addr1.Add(usZone, usNet, usNode, usPoint, pszDomain);
  Addr1.First;

  fdDat.Seek(0, soFromBeginning);
  while fdDat.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) do
  begin
    if StrIComp(N.Address, Addr1.Str) = 0 then
    begin
      Result := 1;
      Break;
    end;
  end;

  Addr1.Clear;
  if Result = 1 then
    Struct2Class(N);

  if DoClose then
    FreeAndNil(fdDat);
end;

function TNodes.Read(lpAddress: TAddress; flAddNodelist: Word): Word;
var
  N: NODES_REC;
  DoClose: Boolean;
begin
  Result := 0;
  New_;
  DoClose := False;

  if fdDat = nil then
  begin
    if not OpenDat then Exit;
    DoClose := True;
  end;

  if lpAddress <> nil then
  begin
    fdDat.Seek(0, soFromBeginning);
    while fdDat.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) do
    begin
      if StrIComp(N.Address, lpAddress.Str) = 0 then
      begin
        Result := 1;
        Break;
      end;
    end;

    if Result = 1 then
      Struct2Class(N);
  end;

  if DoClose then
    FreeAndNil(fdDat);

  if (flAddNodelist <> 0) and (lpAddress <> nil) then
  begin
    if ReadNodelist(lpAddress) = 1 then
    begin
      StrCopy(Address_, lpAddress.Str);
      Result := 1;
    end;
  end;
end;

function TNodes.Read(pszAddress: PChar; flAddNodelist: Word): Word;
var
  Addr: TAddress;
begin
  Addr := TAddress.Create;
  try
    Addr.Parse(pszAddress);
    Result := Read(Addr, flAddNodelist);
  finally
    Addr.Free;
  end;
end;

function TNodes.ReadNodelist(lpAddress: TAddress): Word;
var
  fsIdx, fsText: TFileStream;
  idxHead: IDXHEADER;
  nodeIdx: NODEIDX;
  Num: LongWord;
  BasePath, FName, Line: String;
  First_: Boolean;
  SL: TStringList;
  Fields: TStringList;
  i, p: Integer;
  Done: Boolean;
begin
  Result := 0;
  Done := False;
  FName := DataFile + '.idx';
  if not FileExists(FName) then Exit;

  try
    fsIdx := TFileStream.Create(FName, fmOpenRead or fmShareDenyNone);
    try
      while (fsIdx.Read(idxHead, SizeOf(IDXHEADER)) = SizeOf(IDXHEADER)) and (Result = 0) and not Done do
      begin
        for Num := 0 to idxHead.Entry - 1 do
        begin
          if fsIdx.Read(nodeIdx, SizeOf(NODEIDX)) <> SizeOf(NODEIDX) then
            Break;
          if (nodeIdx.Zone = lpAddress.Zone) and (nodeIdx.Net = lpAddress.Net) and
             ((nodeIdx.Node = 0) or (nodeIdx.Node = lpAddress.Node)) then
          begin
            { Build path to nodelist text file }
            BasePath := ExtractFilePath(DataFile);
            FName := BasePath + StrPas(idxHead.Name);
            if not FileExists(FName) then
              Continue;

            SL := TStringList.Create;
            try
              SL.LoadFromFile(FName);
              { Find starting line by approximate position }
              First_ := False;
              for i := 0 to SL.Count - 1 do
              begin
                Line := SL[i];
                if (Length(Line) = 0) or (Line[1] = ';') then
                  Continue;

                Fields := TStringList.Create;
                try
                  Fields.Delimiter := ',';
                  Fields.StrictDelimiter := True;
                  Fields.DelimitedText := Line;

                  if Fields.Count < 2 then Continue;

                  if (Line[1] <> ',') then
                  begin
                    { Keyword line }
                    if SameText(Fields[0], 'Zone') or SameText(Fields[0], 'Region') or
                       SameText(Fields[0], 'Host') then
                    begin
                      if First_ then
                      begin
                        Done := True; { break outer }
                        Break;
                      end;
                      First_ := True;
                      Continue;
                    end;
                    { Regular node entry - node number is field[1] }
                    if lpAddress.Node = Word(StrToIntDef(Fields[1], -1)) then
                    begin
                      Result := 1;
                      if (Fields.Count > 2) and (SystemName[0] = #0) then
                        StrPCopy(SystemName, StringReplace(Fields[2], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 3) and (Location[0] = #0) then
                        StrPCopy(Location, StringReplace(Fields[3], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 4) and (SysopName[0] = #0) then
                        StrPCopy(SysopName, StringReplace(Fields[4], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 5) and (Phone[0] = #0) then
                        StrPCopy(Phone, StringReplace(Fields[5], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 6) and (Speed = 0) then
                        Speed := StrToIntDef(Fields[6], 0);
                      if (Fields.Count > 7) and (Self.Flags[0] = #0) then
                        StrPCopy(Self.Flags, Fields[7]);
                      Break;
                    end;
                  end
                  else
                  begin
                    { Continuation line (starts with comma) - node number is field[0] after comma }
                    if lpAddress.Node = Word(StrToIntDef(Fields[1], -1)) then
                    begin
                      Result := 1;
                      if (Fields.Count > 2) and (SystemName[0] = #0) then
                        StrPCopy(SystemName, StringReplace(Fields[2], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 3) and (Location[0] = #0) then
                        StrPCopy(Location, StringReplace(Fields[3], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 4) and (SysopName[0] = #0) then
                        StrPCopy(SysopName, StringReplace(Fields[4], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 5) and (Phone[0] = #0) then
                        StrPCopy(Phone, StringReplace(Fields[5], '_', ' ', [rfReplaceAll]));
                      if (Fields.Count > 6) and (Speed = 0) then
                        Speed := StrToIntDef(Fields[6], 0);
                      if (Fields.Count > 7) and (Self.Flags[0] = #0) then
                        StrPCopy(Self.Flags, Fields[7]);
                      Break;
                    end;
                  end;
                finally
                  Fields.Free;
                end;
              end;
            finally
              SL.Free;
            end;
          end;
          if Result = 1 then Break;
        end;
      end;
    finally
      fsIdx.Free;
    end;
  except
  end;

  if Result = 1 then
  begin
    Zone := lpAddress.Zone;
    Net := lpAddress.Net;
    Node := lpAddress.Node;
    Point := lpAddress.Point;
  end;
end;

procedure TNodes.Update;
var
  N: NODES_REC;
  DoClose: Boolean;
begin
  DoClose := False;
  if fdDat = nil then
  begin
    if not OpenDat then Exit;
    DoClose := True;
  end;

  fdDat.Seek(0, soFromBeginning);
  Addr1.Parse(Address_);
  StrCopy(Address_, Addr1.Str);

  while fdDat.Read(N, SizeOf(NODES_REC)) = SizeOf(NODES_REC) do
  begin
    if StrComp(Address_, N.Address) = 0 then
    begin
      Class2Struct(N);
      fdDat.Seek(fdDat.Position - SizeOf(NODES_REC), soFromBeginning);
      fdDat.Write(N, SizeOf(NODES_REC));
      Break;
    end;
  end;

  if DoClose then
    FreeAndNil(fdDat);
end;

function TNodes.FirstNodelist: Word;
var
  data: PNODELIST_REC;
begin
  Result := 0;
  data := PNODELIST_REC(ListData.First);
  if data <> nil then
  begin
    DefaultZone := data^.Zone;
    StrCopy(Nodelist, data^.Name);
    StrCopy(Nodediff, data^.Diff);
    Result := 1;
  end;
end;

function TNodes.NextNodelist: Word;
var
  data: PNODELIST_REC;
begin
  Result := 0;
  data := PNODELIST_REC(ListData.Next);
  if data <> nil then
  begin
    DefaultZone := data^.Zone;
    StrCopy(Nodelist, data^.Name);
    StrCopy(Nodediff, data^.Diff);
    Result := 1;
  end;
end;

procedure TNodes.AddNodelist(name, diff: PChar; AZone: Word);
var
  data: NODELIST_REC;
begin
  FillChar(data, SizeOf(NODELIST_REC), 0);
  data.Size := SizeOf(NODELIST_REC);
  data.Zone := AZone;
  StrCopy(data.Name, name);
  StrCopy(data.Diff, diff);
  ListData.Add(@data, SizeOf(NODELIST_REC));
end;

procedure TNodes.LoadNodelist;
var
  fs: TFileStream;
  FName: String;
  data: NODELIST_REC;
begin
  ListData.Clear;
  FName := Copy(DataFile, 1, Length(DataFile) - 5) + 'nodelist.dat';
  if not FileExists(FName) then Exit;

  try
    fs := TFileStream.Create(FName, fmOpenReadWrite or fmShareDenyNone);
    try
      while fs.Read(data, SizeOf(NODELIST_REC)) = SizeOf(NODELIST_REC) do
        ListData.Add(@data, SizeOf(NODELIST_REC));
    finally
      fs.Free;
    end;
  except
  end;
end;

procedure TNodes.SaveNodelist;
var
  fs: TFileStream;
  FName: String;
  data: PNODELIST_REC;
begin
  FName := Copy(DataFile, 1, Length(DataFile) - 5) + 'nodelist.dat';
  try
    fs := TFileStream.Create(FName, fmCreate);
    try
      data := PNODELIST_REC(ListData.First);
      while data <> nil do
      begin
        data^.Size := SizeOf(NODELIST_REC);
        fs.Write(data^, SizeOf(NODELIST_REC));
        data := PNODELIST_REC(ListData.Next);
      end;
    finally
      fs.Free;
    end;
  except
  end;
end;

procedure TNodes.DeleteNodelist;
begin
  ListData.Remove;
end;

{ --- TNodeFlags --- }

constructor TNodeFlags.Create;
begin
  inherited Create;
  DataFile := 'nodeflag.dat';
  List := TCollection.Create;
end;

constructor TNodeFlags.Create(pszDataPath: PChar);
var
  fs: TFileStream;
begin
  inherited Create;
  DataFile := IncludeTrailingPathDelimiter(StrPas(pszDataPath)) + 'nodeflag.dat';
  {$IFDEF UNIX}
  DataFile := StringReplace(DataFile, '\', '/', [rfReplaceAll]);
  {$ELSE}
  DataFile := StringReplace(DataFile, '/', '\', [rfReplaceAll]);
  {$ENDIF}
  DataFile := LowerCase(DataFile);
  List := TCollection.Create;

  if FileExists(DataFile) then
  begin
    try
      fs := TFileStream.Create(DataFile, fmOpenRead or fmShareDenyNone);
      try
        while fs.Read(nf, SizeOf(NODEFLAGS_REC)) = SizeOf(NODEFLAGS_REC) do
          List.Add(@nf, SizeOf(NODEFLAGS_REC));
      finally
        fs.Free;
      end;
    except
    end;
  end;
end;

destructor TNodeFlags.Destroy;
begin
  List.Free;
  inherited Destroy;
end;

procedure TNodeFlags.Add;
begin
  FillChar(nf, SizeOf(NODEFLAGS_REC), 0);
  nf.Size := SizeOf(NODEFLAGS_REC);
  StrCopy(nf.Flags, Flags_);
  StrCopy(nf.Cmd, Cmd);
  List.Add(@nf, SizeOf(NODEFLAGS_REC));
end;

procedure TNodeFlags.Delete;
var
  pnf: PNODEFLAGS_REC;
begin
  List.Remove;
  pnf := PNODEFLAGS_REC(List.Value);
  if pnf <> nil then
  begin
    StrCopy(Flags_, pnf^.Flags);
    StrCopy(Cmd, pnf^.Cmd);
  end;
end;

procedure TNodeFlags.DeleteAll;
begin
  while List.First <> nil do
    List.Remove;
end;

function TNodeFlags.First: Word;
var
  pnf: PNODEFLAGS_REC;
begin
  Result := 0;
  pnf := PNODEFLAGS_REC(List.First);
  if pnf <> nil then
  begin
    StrCopy(Flags_, pnf^.Flags);
    StrCopy(Cmd, pnf^.Cmd);
    Result := 1;
  end;
end;

function TNodeFlags.Next: Word;
var
  pnf: PNODEFLAGS_REC;
begin
  Result := 0;
  pnf := PNODEFLAGS_REC(List.Next);
  if pnf <> nil then
  begin
    StrCopy(Flags_, pnf^.Flags);
    StrCopy(Cmd, pnf^.Cmd);
    Result := 1;
  end;
end;

function TNodeFlags.Read(pszFlag: PChar): Word;
var
  pnf: PNODEFLAGS_REC;
  Temp1, Temp2, Token: String;
  p: Integer;
begin
  Result := 0;
  Temp1 := UpperCase(StrPas(pszFlag));

  pnf := PNODEFLAGS_REC(List.First);
  while (pnf <> nil) and (Result = 0) do
  begin
    Temp2 := UpperCase(StrPas(pnf^.Flags));
    { Tokenize by space and comma }
    while Temp2 <> '' do
    begin
      p := 1;
      while (p <= Length(Temp2)) and (Temp2[p] <> ' ') and (Temp2[p] <> ',') do
        Inc(p);
      Token := Copy(Temp2, 1, p - 1);
      if p <= Length(Temp2) then
        System.Delete(Temp2, 1, p)
      else
        Temp2 := '';

      if (Token <> '') and (Pos(Token, Temp1) > 0) then
      begin
        StrCopy(Flags_, pnf^.Flags);
        StrCopy(Cmd, pnf^.Cmd);
        Result := 1;
        Break;
      end;
    end;
    if Result = 0 then
      pnf := PNODEFLAGS_REC(List.Next);
  end;
end;

function TNodeFlags.Read(index: Word): Word;
begin
  Result := 0;
end;

procedure TNodeFlags.Update;
var
  pnf: PNODEFLAGS_REC;
begin
  pnf := PNODEFLAGS_REC(List.Value);
  if pnf <> nil then
  begin
    FillChar(pnf^, SizeOf(NODEFLAGS_REC), 0);
    pnf^.Size := SizeOf(NODEFLAGS_REC);
    StrCopy(pnf^.Flags, Flags_);
    StrCopy(pnf^.Cmd, Cmd);
  end;
end;

procedure TNodeFlags.Save;
var
  fs: TFileStream;
  pnf: PNODEFLAGS_REC;
begin
  try
    fs := TFileStream.Create(DataFile, fmCreate);
    try
      pnf := PNODEFLAGS_REC(List.First);
      while pnf <> nil do
      begin
        fs.Write(pnf^, SizeOf(NODEFLAGS_REC));
        pnf := PNODEFLAGS_REC(List.Next);
      end;
    finally
      fs.Free;
    end;
  except
  end;
end;

end.
