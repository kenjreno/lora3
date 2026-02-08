{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of msgdata.cpp
  TMsgData: message area data management (msg.dat/msg.idx indexed pair)
  TEchoLink: echo link management (echolink.dat) with sorted TCollection
  TEchotoss: echotoss.log text tag list
}

unit MsgData;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Collect, Struc299, Address;

type
  TMsgData = class
  private
    FDat: TFileStream;
    FIdx: TFileStream;
    FDataFile: String;
    FIdxFile: String;
    FLastKey: String;
    FAutoOpened: Boolean;
    procedure Class2Struct(var Msg: MESSAGE_REC);
    procedure Struct2Class(const Msg: MESSAGE_REC);
    procedure EnsureOpen;
    procedure CloseIfAuto;
    function FixMsgPath(const P: String; MsgStorage: Word): String;
  public
    Key: String;
    Display: String;
    Level, WriteLevel: Word;
    AccessFlags, DenyFlags, WriteFlags, DenyWriteFlags: LongWord;
    Age: Byte;
    Storage: Word;
    Path: String;
    Board: Word;
    Flags_, Group: Word;
    EchoMail, ShowGlobal, UpdateNews, Offline: Boolean;
    MenuName: String;
    Moderator: String;
    Cost: LongWord;
    DaysOld, RecvDaysOld, MaxMessages: Word;
    ActiveMsgs, HighWaterMark: LongWord;
    NewsGroup: String;
    EchoTag: String;
    Origin: String;
    Address_: String;
    Highest, FirstMessage, LastMessage: LongWord;
    OriginIndex: SmallInt;
    LastReaded, NewsHWM: LongWord;

    constructor Create; overload;
    constructor Create(const ADataPath: String); overload;
    destructor Destroy; override;

    function Add: Boolean;
    procedure Delete;
    function First: Boolean;
    function Insert: Boolean; overload;
    function Insert(Data: TMsgData): Boolean; overload;
    function Last: Boolean;
    procedure New_;
    function Next: Boolean;
    procedure Pack;
    function Previous: Boolean;
    function Read(const AName: String; CloseAfter: Boolean = True): Boolean;
    function ReadEcho(const AEchoTag: String): Boolean;
    function ReRead: Boolean;
    function Update(const ANewKey: String = ''): Boolean;
  end;

  TEchoLink = class
  private
    FData: TCollection;
    FDataFile: String;
    procedure CopyFromRecord(El: PECHOLINK);
    function BuildAddress: String;
  public
    Skip4D: Boolean;
    EchoTag_: LongWord;
    Zone, Net, Node, Point: Word;
    Domain: String;
    Address_: String;
    ShortAddress: String;
    SendOnly, ReceiveOnly: Boolean;
    PersonalOnly: Boolean;
    Passive, Skip: Boolean;

    constructor Create; overload;
    constructor Create(const ADataPath: String); overload;
    destructor Destroy; override;

    function Add: Boolean;
    function AddString(const AString: String): Boolean;
    procedure Change(const AFrom, ATo: String);
    function Check(const AAddress: String): Boolean;
    procedure Clear;
    procedure Delete;
    function First: Boolean;
    procedure Load(const AEchoTag: String);
    procedure New_;
    function Next: Boolean;
    function Previous: Boolean;
    procedure Save;
    procedure Update;
  end;

  TEchotoss = class
  private
    FDataFile: String;
    FData: TCollection;
  public
    Tag: String;

    constructor Create(const APath: String);
    destructor Destroy; override;

    procedure Add(const ATag: String);
    procedure Clear;
    procedure Delete;
    function First: Boolean;
    function Load: Boolean;
    function Next: Boolean;
    procedure Save;
  end;

implementation

function AdjustPath(const S: String): String;
begin
  {$IFDEF UNIX}
  Result := StringReplace(S, '\', '/', [rfReplaceAll]);
  {$ELSE}
  Result := StringReplace(S, '/', '\', [rfReplaceAll]);
  {$ENDIF}
end;

{ ---- TMsgData ---- }

constructor TMsgData.Create;
begin
  inherited Create;
  FDat := nil;
  FIdx := nil;
  FDataFile := 'msg.dat';
  FIdxFile := 'msg.idx';
  FLastKey := '';
  LastReaded := 0;
end;

constructor TMsgData.Create(const ADataPath: String);
var
  BasePath: String;
begin
  inherited Create;
  FDat := nil;
  FIdx := nil;
  BasePath := IncludeTrailingPathDelimiter(ADataPath);
  FDataFile := AdjustPath(LowerCase(BasePath + 'msg.dat'));
  FIdxFile := AdjustPath(LowerCase(BasePath + 'msg.idx'));
  FLastKey := '';
  LastReaded := 0;
end;

destructor TMsgData.Destroy;
begin
  FreeAndNil(FDat);
  FreeAndNil(FIdx);
  inherited Destroy;
end;

procedure TMsgData.EnsureOpen;
begin
  if FIdx = nil then
  begin
    if FileExists(FIdxFile) then
      FIdx := TFileStream.Create(FIdxFile, fmOpenReadWrite or fmShareDenyNone)
    else
      FIdx := TFileStream.Create(FIdxFile, fmCreate);
    FAutoOpened := True;
  end;
  if FDat = nil then
  begin
    if FileExists(FDataFile) then
      FDat := TFileStream.Create(FDataFile, fmOpenReadWrite or fmShareDenyNone)
    else
      FDat := TFileStream.Create(FDataFile, fmCreate);
    FAutoOpened := True;
  end;
end;

procedure TMsgData.CloseIfAuto;
begin
  if FAutoOpened then
  begin
    FreeAndNil(FDat);
    FreeAndNil(FIdx);
    FAutoOpened := False;
  end;
end;

function TMsgData.FixMsgPath(const P: String; MsgStorage: Word): String;
begin
  if (MsgStorage = ST_FIDO) or (MsgStorage = ST_HUDSON) then
    Result := IncludeTrailingPathDelimiter(P)
  else
    Result := ExcludeTrailingPathDelimiter(P);
  Result := AdjustPath(Result);
end;

procedure TMsgData.Class2Struct(var Msg: MESSAGE_REC);
begin
  StrPCopy(Msg.Display, Display);
  StrPCopy(Msg.Key, Key);
  Msg.Level := Level;
  Msg.AccessFlags := AccessFlags;
  Msg.DenyFlags := DenyFlags;
  Msg.WriteLevel := WriteLevel;
  Msg.WriteFlags := WriteFlags;
  Msg.DenyWriteFlags := DenyWriteFlags;
  Msg.Age := Age;
  Msg.Storage := Storage;
  StrPCopy(Msg.Path, Path);
  Msg.Board := Board;
  Msg.Flags := Flags_;
  Msg.Group := Group;
  if EchoMail then Msg.EchoMail := 1 else Msg.EchoMail := 0;
  if ShowGlobal then Msg.ShowGlobal := 1 else Msg.ShowGlobal := 0;
  if UpdateNews then Msg.UpdateNews := 1 else Msg.UpdateNews := 0;
  if Offline then Msg.Offline := 1 else Msg.Offline := 0;
  StrPCopy(Msg.MenuName, MenuName);
  StrPCopy(Msg.Moderator, Moderator);
  Msg.Cost := Cost;
  Msg.DaysOld := DaysOld;
  Msg.RecvDaysOld := RecvDaysOld;
  Msg.MaxMessages := MaxMessages;
  Msg.ActiveMsgs := ActiveMsgs;
  StrPCopy(Msg.NewsGroup, NewsGroup);
  Msg.Highest := Highest;
  Msg.HighWaterMark := HighWaterMark;
  StrPCopy(Msg.EchoTag, EchoTag);
  StrPCopy(Msg.Origin, Origin);
  StrPCopy(Msg.Address, Address_);
  Msg.FirstMessage := FirstMessage;
  Msg.LastMessage := LastMessage;
  Msg.OriginIndex := OriginIndex;
  Msg.NewsHWM := NewsHWM;
end;

procedure TMsgData.Struct2Class(const Msg: MESSAGE_REC);
begin
  Display := StrPas(Msg.Display);
  Key := StrPas(Msg.Key);
  Level := Msg.Level;
  AccessFlags := Msg.AccessFlags;
  DenyFlags := Msg.DenyFlags;
  WriteLevel := Msg.WriteLevel;
  WriteFlags := Msg.WriteFlags;
  DenyWriteFlags := Msg.DenyWriteFlags;
  Age := Msg.Age;
  Storage := Msg.Storage;
  Path := FixMsgPath(StrPas(Msg.Path), Msg.Storage);
  Board := Msg.Board;
  Flags_ := Msg.Flags;
  Group := Msg.Group;
  EchoMail := Msg.EchoMail <> 0;
  ShowGlobal := Msg.ShowGlobal <> 0;
  UpdateNews := Msg.UpdateNews <> 0;
  Offline := Msg.Offline <> 0;
  MenuName := StrPas(Msg.MenuName);
  Moderator := StrPas(Msg.Moderator);
  Cost := Msg.Cost;
  DaysOld := Msg.DaysOld;
  RecvDaysOld := Msg.RecvDaysOld;
  MaxMessages := Msg.MaxMessages;
  ActiveMsgs := Msg.ActiveMsgs;
  NewsGroup := StrPas(Msg.NewsGroup);
  Highest := Msg.Highest;
  HighWaterMark := Msg.HighWaterMark;
  EchoTag := StrPas(Msg.EchoTag);
  Origin := StrPas(Msg.Origin);
  Address_ := StrPas(Msg.Address);
  FirstMessage := Msg.FirstMessage;
  LastMessage := Msg.LastMessage;
  OriginIndex := Msg.OriginIndex;
  NewsHWM := Msg.NewsHWM;
  FLastKey := Key;
end;

procedure TMsgData.New_;
begin
  Display := '';
  Key := '';
  Level := 0;
  AccessFlags := 0;
  DenyFlags := 0;
  WriteLevel := 0;
  WriteFlags := 0;
  DenyWriteFlags := 0;
  Age := 0;
  Storage := 0;
  Path := '';
  Board := 0;
  Flags_ := 0;
  Group := 0;
  EchoMail := False;
  ShowGlobal := True;
  UpdateNews := False;
  Offline := True;
  MenuName := '';
  Moderator := '';
  Cost := 0;
  DaysOld := 0;
  RecvDaysOld := 0;
  MaxMessages := 0;
  FirstMessage := 0;
  LastMessage := 0;
  ActiveMsgs := 0;
  NewsGroup := '';
  Highest := 0;
  EchoTag := '';
  Origin := '';
  HighWaterMark := 0;
  Address_ := '';
  NewsHWM := 0;
end;

function TMsgData.Add: Boolean;
var
  Msg: MESSAGE_REC;
  Idx: INDEX;
  WasAuto: Boolean;
begin
  Result := False;
  WasAuto := (FIdx = nil) or (FDat = nil);
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  try
    FDat.Seek(0, soEnd);
    FIdx.Seek(0, soEnd);

    FillChar(Msg, SizeOf(Msg), 0);
    Msg.Size := SizeOf(MESSAGE_REC);
    Class2Struct(Msg);

    FillChar(Idx, SizeOf(Idx), 0);
    StrPCopy(Idx.Key, Key);
    Idx.Level := Level;
    Idx.AccessFlags := AccessFlags;
    Idx.DenyFlags := DenyFlags;
    Idx.Position := FDat.Position;

    FDat.Write(Msg, SizeOf(Msg));
    FIdx.Write(Idx, SizeOf(Idx));
    Result := True;
  finally
    if WasAuto then CloseIfAuto;
  end;
end;

procedure TMsgData.Delete;
var
  TmpStream: TFileStream;
  Msg: MESSAGE_REC;
  Idx: INDEX;
  SavedPos: Int64;
  TmpFile: String;
begin
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  TmpFile := ExtractFilePath(FDataFile) + 'Temp1.Dat';
  try
    TmpStream := TFileStream.Create(TmpFile, fmCreate);
  except
    Exit;
  end;

  try
    { Copy all records except the one matching FLastKey }
    FDat.Seek(0, soBeginning);
    while FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) do
    begin
      if StrPas(Msg.Key) <> FLastKey then
        TmpStream.Write(Msg, SizeOf(Msg));
    end;

    SavedPos := FIdx.Position;
    if SavedPos >= SizeOf(INDEX) then
      Dec(SavedPos, SizeOf(INDEX));

    { Rebuild both files }
    FreeAndNil(FDat);
    FreeAndNil(FIdx);
    FIdx := TFileStream.Create(FIdxFile, fmCreate);
    FDat := TFileStream.Create(FDataFile, fmCreate);

    TmpStream.Seek(0, soBeginning);
    while TmpStream.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) do
    begin
      FillChar(Idx, SizeOf(Idx), 0);
      StrCopy(Idx.Key, Msg.Key);
      Idx.Level := Msg.Level;
      Idx.AccessFlags := Msg.AccessFlags;
      Idx.DenyFlags := Msg.DenyFlags;
      Idx.Position := FDat.Position;
      FIdx.Write(Idx, SizeOf(Idx));
      FDat.Write(Msg, SizeOf(Msg));
    end;

    { Reposition and navigate }
    if SavedPos < FIdx.Size then
      FIdx.Seek(SavedPos, soBeginning);
    if not Next then
      if not Previous then
        New_;
  finally
    TmpStream.Free;
    SysUtils.DeleteFile(TmpFile);
  end;
end;

function TMsgData.First: Boolean;
begin
  Result := False;
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;
  FIdx.Seek(0, soBeginning);
  FDat.Seek(0, soBeginning);
  Result := Next;
end;

function TMsgData.Next: Boolean;
var
  Msg: MESSAGE_REC;
  Idx: INDEX;
begin
  Result := False;
  if (FDat = nil) or (FIdx = nil) then Exit;

  while FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) do
  begin
    if (Idx.Flags and IDX_DELETED) = 0 then
    begin
      if FDat.Position <> Idx.Position then
        FDat.Seek(Idx.Position, soBeginning);
      if FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) then
      begin
        New_;
        Struct2Class(Msg);
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function TMsgData.Previous: Boolean;
var
  Msg: MESSAGE_REC;
  Idx: INDEX;
begin
  Result := False;
  if (FDat = nil) or (FIdx = nil) then Exit;

  while FIdx.Position >= SizeOf(INDEX) * 2 do
  begin
    FIdx.Seek(FIdx.Position - SizeOf(INDEX) * 2, soBeginning);
    if FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) then
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        FDat.Seek(Idx.Position, soBeginning);
        if FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) then
        begin
          New_;
          Struct2Class(Msg);
          Result := True;
          Exit;
        end;
      end;
    end;
  end;
end;

function TMsgData.Last: Boolean;
var
  Msg: MESSAGE_REC;
  Idx: INDEX;
begin
  Result := False;
  if (FDat = nil) or (FIdx = nil) then Exit;

  { Seek to end of index, then try last entry }
  FIdx.Seek(0, soEnd);
  if FIdx.Position >= SizeOf(INDEX) then
  begin
    FIdx.Seek(FIdx.Position - SizeOf(INDEX), soBeginning);
    if FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) then
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        FDat.Seek(Idx.Position, soBeginning);
        if FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) then
        begin
          New_;
          Struct2Class(Msg);
          Result := True;
          Exit;
        end;
      end;
    end;
  end;

  { Walk backwards to find non-deleted entry }
  while FIdx.Position >= SizeOf(INDEX) * 2 do
  begin
    FIdx.Seek(FIdx.Position - SizeOf(INDEX) * 2, soBeginning);
    if FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) then
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        FDat.Seek(Idx.Position, soBeginning);
        if FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) then
        begin
          New_;
          Struct2Class(Msg);
          Result := True;
          Exit;
        end;
      end;
    end;
  end;
end;

function TMsgData.Insert: Boolean;
var
  TmpStream: TFileStream;
  Msg: MESSAGE_REC;
  Idx: INDEX;
  SavedPos: Int64;
  TmpFile: String;
begin
  Result := False;
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  TmpFile := ExtractFilePath(FDataFile) + 'Temp1.Dat';
  try
    TmpStream := TFileStream.Create(TmpFile, fmCreate);
  except
    Exit;
  end;

  try
    { Copy all records, inserting new one after FLastKey match }
    FDat.Seek(0, soBeginning);
    while FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) do
    begin
      TmpStream.Write(Msg, SizeOf(Msg));
      if StrPas(Msg.Key) = FLastKey then
      begin
        FillChar(Msg, SizeOf(Msg), 0);
        Msg.Size := SizeOf(MESSAGE_REC);
        Class2Struct(Msg);
        TmpStream.Write(Msg, SizeOf(Msg));
      end;
    end;

    { Rebuild both files from temp }
    SavedPos := FIdx.Position;
    FDat.Seek(0, soBeginning);
    FIdx.Seek(0, soBeginning);
    TmpStream.Seek(0, soBeginning);

    while TmpStream.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) do
    begin
      FillChar(Idx, SizeOf(Idx), 0);
      StrCopy(Idx.Key, Msg.Key);
      Idx.Level := Msg.Level;
      Idx.AccessFlags := Msg.AccessFlags;
      Idx.DenyFlags := Msg.DenyFlags;
      Idx.Position := FDat.Position;
      FIdx.Write(Idx, SizeOf(Idx));
      FDat.Write(Msg, SizeOf(Msg));
    end;

    FIdx.Seek(SavedPos, soBeginning);
    Next;
    Result := True;
  finally
    TmpStream.Free;
    SysUtils.DeleteFile(TmpFile);
  end;
end;

function TMsgData.Insert(Data: TMsgData): Boolean;
begin
  Display := Data.Display;
  Key := Data.Key;
  Level := Data.Level;
  AccessFlags := Data.AccessFlags;
  DenyFlags := Data.DenyFlags;
  WriteLevel := Data.WriteLevel;
  WriteFlags := Data.WriteFlags;
  DenyWriteFlags := Data.DenyWriteFlags;
  Age := Data.Age;
  Storage := Data.Storage;
  Path := FixMsgPath(Data.Path, Data.Storage);
  Board := Data.Board;
  Flags_ := Data.Flags_;
  Group := Data.Group;
  EchoMail := Data.EchoMail;
  ShowGlobal := Data.ShowGlobal;
  UpdateNews := Data.UpdateNews;
  Offline := Data.Offline;
  MenuName := Data.MenuName;
  Moderator := Data.Moderator;
  Cost := Data.Cost;
  DaysOld := Data.DaysOld;
  RecvDaysOld := Data.RecvDaysOld;
  MaxMessages := Data.MaxMessages;
  ActiveMsgs := Data.ActiveMsgs;
  NewsGroup := Data.NewsGroup;
  Highest := Data.Highest;
  HighWaterMark := Data.HighWaterMark;
  EchoTag := Data.EchoTag;
  Origin := Data.Origin;
  Address_ := Data.Address_;
  FirstMessage := Data.FirstMessage;
  LastMessage := Data.LastMessage;
  OriginIndex := Data.OriginIndex;
  NewsHWM := Data.NewsHWM;
  Result := Insert;
end;

function TMsgData.Read(const AName: String; CloseAfter: Boolean): Boolean;
var
  Msg: MESSAGE_REC;
  Idx: INDEX;
  WasAuto: Boolean;
begin
  Result := False;
  New_;

  WasAuto := (FIdx = nil) or (FDat = nil);
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  try
    FIdx.Seek(0, soBeginning);
    FDat.Seek(0, soBeginning);

    while FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) do
    begin
      if ((Idx.Flags and IDX_DELETED) = 0) and
         SameText(AName, StrPas(Idx.Key)) then
      begin
        FDat.Seek(Idx.Position, soBeginning);
        if FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) then
        begin
          Struct2Class(Msg);
          Result := True;
          Break;
        end;
      end;
    end;
  finally
    if CloseAfter then
    begin
      FreeAndNil(FDat);
      FreeAndNil(FIdx);
    end;
  end;
end;

function TMsgData.ReadEcho(const AEchoTag: String): Boolean;
var
  FStream: TFileStream;
  Msg: MESSAGE_REC;
begin
  Result := False;
  New_;

  if not FileExists(FDataFile) then Exit;
  try
    FStream := TFileStream.Create(FDataFile, fmOpenRead or fmShareDenyNone);
  except
    Exit;
  end;

  try
    while FStream.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) do
    begin
      if SameText(AEchoTag, StrPas(Msg.EchoTag)) then
      begin
        Struct2Class(Msg);
        Result := True;
        Break;
      end;
    end;
  finally
    FStream.Free;
  end;
end;

function TMsgData.ReRead: Boolean;
begin
  Result := False;
  if (FDat = nil) or (FIdx = nil) then Exit;
  if FIdx.Position >= SizeOf(INDEX) then
  begin
    FIdx.Seek(FIdx.Position - SizeOf(INDEX), soBeginning);
    Result := Next;
  end;
end;

function TMsgData.Update(const ANewKey: String): Boolean;
var
  Msg: MESSAGE_REC;
  Idx: INDEX;
  WasAuto: Boolean;
  Found: Boolean;
begin
  Result := False;
  WasAuto := (FIdx = nil) or (FDat = nil);
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  try
    Found := False;

    if WasAuto then
    begin
      { Search from beginning }
      FIdx.Seek(0, soBeginning);
      while FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) do
      begin
        if ((Idx.Flags and IDX_DELETED) = 0) and SameText(Key, StrPas(Idx.Key)) then
        begin
          Found := True;
          Break;
        end;
      end;
    end
    else
    begin
      { Try current position first }
      if FIdx.Position >= SizeOf(INDEX) then
      begin
        FIdx.Seek(FIdx.Position - SizeOf(INDEX), soBeginning);
        if FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) then
        begin
          if StrPas(Idx.Key) = Key then
            Found := True;
        end;
      end;

      if not Found then
      begin
        FIdx.Seek(0, soBeginning);
        while FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) do
        begin
          if ((Idx.Flags and IDX_DELETED) = 0) and SameText(Key, StrPas(Idx.Key)) then
          begin
            Found := True;
            Break;
          end;
        end;
      end;
    end;

    if Found and (FIdx.Position >= SizeOf(INDEX)) then
    begin
      if ANewKey <> '' then
        Key := ANewKey;

      FillChar(Msg, SizeOf(Msg), 0);
      Msg.Size := SizeOf(MESSAGE_REC);
      Class2Struct(Msg);

      StrPCopy(Idx.Key, Key);
      FIdx.Seek(FIdx.Position - SizeOf(INDEX), soBeginning);
      FIdx.Write(Idx, SizeOf(Idx));

      FDat.Seek(Idx.Position, soBeginning);
      FDat.Write(Msg, SizeOf(Msg));
      Result := True;
    end;
  finally
    if WasAuto then CloseIfAuto;
  end;
end;

procedure TMsgData.Pack;
var
  NewIdx, NewDat: TFileStream;
  Msg: MESSAGE_REC;
  Idx: INDEX;
  NewIdxFile, NewDatFile: String;
begin
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  NewIdxFile := ExtractFilePath(FIdxFile) + 'Msg-New.Idx';
  NewDatFile := ExtractFilePath(FDataFile) + 'Msg-New.Dat';

  try
    NewIdx := TFileStream.Create(NewIdxFile, fmCreate);
    NewDat := TFileStream.Create(NewDatFile, fmCreate);
  except
    Exit;
  end;

  try
    FIdx.Seek(0, soBeginning);
    while FIdx.Read(Idx, SizeOf(Idx)) = SizeOf(Idx) do
    begin
      if (Idx.Flags and IDX_DELETED) = 0 then
      begin
        FDat.Seek(Idx.Position, soBeginning);
        if FDat.Read(Msg, SizeOf(Msg)) = SizeOf(Msg) then
        begin
          Idx.Position := NewDat.Position;
          NewDat.Write(Msg, SizeOf(Msg));
          NewIdx.Write(Idx, SizeOf(Idx));
        end;
      end;
    end;
  finally
    NewIdx.Free;
    NewDat.Free;
  end;

  FreeAndNil(FDat);
  FreeAndNil(FIdx);

  SysUtils.DeleteFile(FDataFile);
  RenameFile(NewDatFile, FDataFile);
  SysUtils.DeleteFile(FIdxFile);
  RenameFile(NewIdxFile, FIdxFile);

  { Clean up in case rename failed }
  SysUtils.DeleteFile(NewDatFile);
  SysUtils.DeleteFile(NewIdxFile);
end;

{ ---- TEchoLink ---- }

const
  ECHOLINK_INDEX = 32;

constructor TEchoLink.Create;
begin
  inherited Create;
  FData := TCollection.Create;
  FDataFile := 'echolink.dat';
  Skip4D := False;
end;

constructor TEchoLink.Create(const ADataPath: String);
begin
  inherited Create;
  FData := TCollection.Create;
  FDataFile := IncludeTrailingPathDelimiter(ADataPath) + 'echolink.dat';
  Skip4D := False;
end;

destructor TEchoLink.Destroy;
begin
  FData.Clear;
  FreeAndNil(FData);
  inherited Destroy;
end;

function TEchoLink.BuildAddress: String;
begin
  if Point = 0 then
    Result := Format('%u:%u/%u', [Zone, Net, Node])
  else
    Result := Format('%u:%u/%u.%u', [Zone, Net, Node, Point]);
  if Domain <> '' then
    Result := Result + '@' + Domain;
end;

procedure TEchoLink.CopyFromRecord(El: PECHOLINK);
begin
  EchoTag_ := El^.EchoTag;
  Zone := El^.Zone;
  Net := El^.Net;
  Node := El^.Node;
  Point := El^.Point;
  Domain := StrPas(El^.Domain);
  SendOnly := El^.SendOnly <> 0;
  ReceiveOnly := El^.ReceiveOnly <> 0;
  PersonalOnly := El^.PersonalOnly <> 0;
  Passive := El^.Passive <> 0;
  Skip := El^.Skip <> 0;
  Address_ := BuildAddress;
end;

procedure TEchoLink.New_;
begin
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  Address_ := '';
  Domain := '';
  SendOnly := False;
  ReceiveOnly := False;
  PersonalOnly := False;
  Passive := False;
  Skip := False;
end;

procedure TEchoLink.Clear;
begin
  FData.Clear;
  New_;
end;

procedure TEchoLink.Delete;
begin
  if FData.Value <> nil then
    FData.Remove;
end;

function TEchoLink.Add: Boolean;
var
  Buffer: ECHOLINK;
  Current: PECHOLINK;
  Inserted: Boolean;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  Buffer.Free := 0;
  Buffer.EchoTag := EchoTag_;
  Buffer.Zone := Zone;
  Buffer.Net := Net;
  Buffer.Node := Node;
  Buffer.Point := Point;
  StrPCopy(Buffer.Domain, Domain);
  if SendOnly then Buffer.SendOnly := 1;
  if ReceiveOnly then Buffer.ReceiveOnly := 1;
  if PersonalOnly then Buffer.PersonalOnly := 1;
  if Passive then Buffer.Passive := 1;
  if Skip then Buffer.Skip := 1;

  Inserted := False;
  Current := PECHOLINK(FData.First);
  if Current <> nil then
  begin
    if (Current^.Zone > Zone) or
       ((Current^.Zone = Zone) and (Current^.Net > Net)) or
       ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node > Node)) or
       ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node = Node) and (Current^.Point > Point)) then
    begin
      FData.Insert(@Buffer, SizeOf(ECHOLINK));
      FData.Insert(Current, SizeOf(ECHOLINK));
      FData.First;
      FData.Remove;
      FData.First;
      Inserted := True;
    end
    else
    begin
      Current := PECHOLINK(FData.Next);
      while Current <> nil do
      begin
        if (Current^.Zone > Zone) or
           ((Current^.Zone = Zone) and (Current^.Net > Net)) or
           ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node > Node)) or
           ((Current^.Zone = Zone) and (Current^.Net = Net) and (Current^.Node = Node) and (Current^.Point > Point)) then
        begin
          FData.Previous;
          FData.Insert(@Buffer, SizeOf(ECHOLINK));
          Inserted := True;
          Break;
        end;
        Current := PECHOLINK(FData.Next);
      end;
      if not Inserted then
      begin
        FData.Add(@Buffer, SizeOf(ECHOLINK));
        Inserted := True;
      end;
    end;
  end
  else
  begin
    FData.Add(@Buffer, SizeOf(ECHOLINK));
    Inserted := True;
  end;

  Result := Inserted;
end;

function TEchoLink.AddString(const AString: String): Boolean;
var
  Tokens: TStringList;
  I: Integer;
  S: String;
  Addr: TAddress;
begin
  Result := False;
  Tokens := TStringList.Create;
  try
    Tokens.Delimiter := ' ';
    Tokens.StrictDelimiter := True;
    Tokens.DelimitedText := AString;

    Addr := TAddress.Create;
    try
      for I := 0 to Tokens.Count - 1 do
      begin
        S := Trim(Tokens[I]);
        if S = '' then Continue;

        Skip := False;
        ReceiveOnly := False;
        SendOnly := False;
        PersonalOnly := False;

        if not Check(S) then
        begin
          { Strip prefix modifiers }
          while (Length(S) > 0) and not (S[1] in ['0'..'9', '.']) do
          begin
            if S[1] = '>' then ReceiveOnly := True;
            if S[1] = '<' then SendOnly := True;
            if S[1] = '!' then PersonalOnly := True;
            System.Delete(S, 1, 1);
          end;
          if S = '' then Continue;

          Addr.Parse(S);
          if not Check(Addr.String_) then
          begin
            if Addr.Zone <> 0 then Zone := Addr.Zone;
            if Addr.Net <> 0 then Net := Addr.Net;
            Node := Addr.Node;
            Point := Addr.Point;
            Domain := Addr.Domain;
            Result := Add;
          end;
        end;
      end;
    finally
      Addr.Free;
    end;
  finally
    Tokens.Free;
  end;
end;

procedure TEchoLink.Change(const AFrom, ATo: String);
var
  FD: TFileStream;
  CrcFrom, CrcTo: LongWord;
  Buffer: array[0..ECHOLINK_INDEX - 1] of ECHOLINK;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
begin
  CrcFrom := StringCrc32(AFrom, $FFFFFFFF);
  CrcTo := StringCrc32(ATo, $FFFFFFFF);

  if not FileExists(FDataFile) then Exit;
  try
    FD := TFileStream.Create(FDataFile, fmOpenReadWrite or fmShareDenyNone);
  except
    Exit;
  end;

  try
    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(ECHOLINK);
      for I := 0 to Count - 1 do
      begin
        if Buffer[I].EchoTag = CrcFrom then
        begin
          Buffer[I].EchoTag := CrcTo;
          Changed := True;
        end;
      end;
      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(ECHOLINK) * Count);
      end;
    until Count < ECHOLINK_INDEX;
  finally
    FD.Free;
  end;
end;

function TEchoLink.Check(const AAddress: String): Boolean;
var
  El: PECHOLINK;
  Addr: TAddress;
  S: String;
begin
  Result := False;
  S := AAddress;
  while (Length(S) > 0) and not (S[1] in ['0'..'9', '.']) do
    System.Delete(S, 1, 1);

  Addr := TAddress.Create;
  try
    Addr.Parse(S);

    El := PECHOLINK(FData.First);
    while El <> nil do
    begin
      if (El^.Zone = Addr.Zone) and (El^.Net = Addr.Net) and
         (El^.Node = Addr.Node) and (El^.Point = Addr.Point) then
      begin
        CopyFromRecord(El);
        Result := True;
        Exit;
      end;
      El := PECHOLINK(FData.Next);
    end;
  finally
    Addr.Free;
  end;
end;

function TEchoLink.First: Boolean;
var
  El: PECHOLINK;
begin
  Result := False;
  El := PECHOLINK(FData.First);
  if El <> nil then
  begin
    CopyFromRecord(El);
    if Skip4D and (Point <> 0) then
      ShortAddress := ''
    else
      ShortAddress := Address_;
    Result := True;
  end;
end;

function TEchoLink.Next: Boolean;
var
  El: PECHOLINK;
  PrevZone, PrevNet, PrevNode: Word;
begin
  Result := False;
  PrevZone := Zone;
  PrevNet := Net;
  PrevNode := Node;

  El := PECHOLINK(FData.Next);
  if El <> nil then
  begin
    { Build short address based on what changed }
    if (not Skip4D) or (El^.Point = 0) then
    begin
      if PrevZone <> El^.Zone then
      begin
        if El^.Point = 0 then
          ShortAddress := Format('%u:%u/%u', [El^.Zone, El^.Net, El^.Node])
        else
          ShortAddress := Format('%u:%u/%u.%u', [El^.Zone, El^.Net, El^.Node, El^.Point]);
      end
      else if PrevNet <> El^.Net then
      begin
        if El^.Point = 0 then
          ShortAddress := Format('%u/%u', [El^.Net, El^.Node])
        else
          ShortAddress := Format('%u/%u.%u', [El^.Net, El^.Node, El^.Point]);
      end
      else if PrevNode <> El^.Node then
      begin
        if El^.Point = 0 then
          ShortAddress := Format('%u', [El^.Node])
        else
          ShortAddress := Format('%u.%u', [El^.Node, El^.Point]);
      end
      else
        ShortAddress := Format('.%u', [El^.Point]);
    end
    else
      ShortAddress := '';

    CopyFromRecord(El);
    Result := True;
  end;
end;

function TEchoLink.Previous: Boolean;
var
  El: PECHOLINK;
begin
  Result := False;
  El := PECHOLINK(FData.Previous);
  if El <> nil then
  begin
    CopyFromRecord(El);
    Result := True;
  end;
end;

procedure TEchoLink.Load(const AEchoTag: String);
var
  FD: TFileStream;
  Buffer: array[0..ECHOLINK_INDEX - 1] of ECHOLINK;
  Count, I: Integer;
  Crc: LongWord;
begin
  FData.Clear;
  Crc := StringCrc32(UpperCase(AEchoTag), $FFFFFFFF);
  EchoTag_ := Crc;

  if not FileExists(FDataFile) then
  begin
    First;
    Exit;
  end;

  try
    FD := TFileStream.Create(FDataFile, fmOpenRead or fmShareDenyNone);
  except
    First;
    Exit;
  end;

  try
    repeat
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(ECHOLINK);
      for I := 0 to Count - 1 do
      begin
        if (Buffer[I].Free = 0) and (Buffer[I].EchoTag = Crc) then
          FData.Add(@Buffer[I], SizeOf(ECHOLINK));
      end;
    until Count < ECHOLINK_INDEX;
  finally
    FD.Free;
  end;

  First;
end;

procedure TEchoLink.Save;
var
  FD: TFileStream;
  Buffer: array[0..ECHOLINK_INDEX - 1] of ECHOLINK;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
  RecPtr: PECHOLINK;
begin
  if FileExists(FDataFile) then
    FD := TFileStream.Create(FDataFile, fmOpenReadWrite or fmShareDenyNone)
  else
    FD := TFileStream.Create(FDataFile, fmCreate);

  try
    RecPtr := PECHOLINK(FData.First);

    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(ECHOLINK);

      for I := 0 to Count - 1 do
      begin
        if RecPtr = nil then Break;
        if (Buffer[I].EchoTag = RecPtr^.EchoTag) or (Buffer[I].Free <> 0) then
        begin
          Move(RecPtr^, Buffer[I], SizeOf(ECHOLINK));
          RecPtr := PECHOLINK(FData.Next);
          Changed := True;
        end;
      end;

      { Mark remaining entries with matching EchoTag as free }
      while I < Count do
      begin
        if Buffer[I].EchoTag = EchoTag_ then
        begin
          FillChar(Buffer[I], SizeOf(ECHOLINK), 0);
          Buffer[I].Free := 1;
          Changed := True;
        end;
        Inc(I);
      end;

      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(ECHOLINK) * Count);
      end;
    until Count < ECHOLINK_INDEX;

    { Append remaining records }
    while RecPtr <> nil do
    begin
      FD.Write(RecPtr^, SizeOf(ECHOLINK));
      RecPtr := PECHOLINK(FData.Next);
    end;
  finally
    FD.Free;
  end;
end;

procedure TEchoLink.Update;
var
  Buffer: PECHOLINK;
begin
  Buffer := PECHOLINK(FData.Value);
  if Buffer <> nil then
  begin
    Buffer^.EchoTag := EchoTag_;
    Buffer^.Zone := Zone;
    Buffer^.Net := Net;
    Buffer^.Node := Node;
    Buffer^.Point := Point;
    StrPCopy(Buffer^.Domain, Domain);
    if SendOnly then Buffer^.SendOnly := 1 else Buffer^.SendOnly := 0;
    if ReceiveOnly then Buffer^.ReceiveOnly := 1 else Buffer^.ReceiveOnly := 0;
    if PersonalOnly then Buffer^.PersonalOnly := 1 else Buffer^.PersonalOnly := 0;
    if Passive then Buffer^.Passive := 1 else Buffer^.Passive := 0;
    if Skip then Buffer^.Skip := 1 else Buffer^.Skip := 0;
    Address_ := BuildAddress;
  end;
end;

{ ---- TEchotoss ---- }

constructor TEchotoss.Create(const APath: String);
begin
  inherited Create;
  FData := TCollection.Create;
  FDataFile := AdjustPath(LowerCase(IncludeTrailingPathDelimiter(APath) + 'echotoss.log'));
end;

destructor TEchotoss.Destroy;
begin
  FData.Clear;
  FreeAndNil(FData);
  inherited Destroy;
end;

procedure TEchotoss.Add(const ATag: String);
var
  P: PChar;
begin
  { Check for duplicate }
  P := PChar(FData.First);
  while P <> nil do
  begin
    if SameText(StrPas(P), ATag) then
      Exit;
    P := PChar(FData.Next);
  end;

  FData.Add(PChar(ATag));
end;

procedure TEchotoss.Clear;
begin
  FData.Clear;
end;

procedure TEchotoss.Delete;
begin
  SysUtils.DeleteFile(FDataFile);
end;

function TEchotoss.First: Boolean;
var
  P: PChar;
begin
  Result := False;
  P := PChar(FData.First);
  if P <> nil then
  begin
    Tag := StrPas(P);
    Result := True;
  end;
end;

function TEchotoss.Next: Boolean;
var
  P: PChar;
begin
  Result := False;
  P := PChar(FData.Next);
  if P <> nil then
  begin
    Tag := StrPas(P);
    Result := True;
  end;
end;

function TEchotoss.Load: Boolean;
var
  Lines: TStringList;
  I: Integer;
  Token: String;
begin
  Result := False;
  if not FileExists(FDataFile) then Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FDataFile);
    Result := True;
    for I := 0 to Lines.Count - 1 do
    begin
      Token := Trim(Lines[I]);
      if Pos(' ', Token) > 0 then
        Token := Copy(Token, 1, Pos(' ', Token) - 1);
      if Token <> '' then
        Add(Token);
    end;
  finally
    Lines.Free;
  end;
end;

procedure TEchotoss.Save;
var
  F: TextFile;
  P: PChar;
begin
  try
    AssignFile(F, FDataFile);
    Rewrite(F);
    try
      P := PChar(FData.First);
      while P <> nil do
      begin
        WriteLn(F, StrPas(P));
        P := PChar(FData.Next);
      end;
    finally
      CloseFile(F);
    end;
  except
  end;
end;

end.
