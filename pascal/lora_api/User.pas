{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of user.cpp
  TUser: user account management (users.dat/users.idx with CRC-based index)
  TMsgTag: message area last-read pointers (msgtags.dat)
  TFileTag: files tagged for download (filetags.dat)
}

unit User;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Collect, Struc299;

type
  TMsgTag = class;
  TFileTag = class;

  TUser = class
  private
    FDat: TFileStream;
    FIdx: TFileStream;
    FDatFile: String;
    FIdxFile: String;
    FUsr: USER_REC;
    FUIdx: UINDEX;
    FCurrentCRC: LongWord;
    procedure Struct2Class;
    procedure Class2Struct;
    procedure EnsureOpen;
  public
    Name: String;
    Password: LongWord;
    RealName: String;
    Company: String;
    Address_: String;
    City: String;
    DayPhone: String;
    Ansi, Avatar, Color, HotKey: Char;
    Sex: Char;
    FullEd, FullReader, NoDisturb, AccessFailed: Byte;
    ScreenHeight, ScreenWidth: Word;
    Level: Word;
    AccessFlags, DenyFlags: LongWord;
    CreationDate, LastCall: LongWord;
    TotalCalls: LongWord;
    TodayTime, WeekTime, MonthTime, YearTime: LongWord;
    MailBox: String;
    LimitClass: String;
    Language_: String;
    FtpHost, FtpName, FtpPwd: String;
    LastMsgArea, LastFileArea: String;
    UploadFiles: Word;
    UploadBytes: LongWord;
    DownloadFiles: Word;
    DownloadBytes: LongWord;
    FilesToday: Word;
    BytesToday: LongWord;
    ImportPOP3Mail, UseInetAddress: Byte;
    InetAddress: String;
    Pop3Pwd: String;
    Archiver: String;
    Protocol_: String;
    Signature: String;
    FullScreen, IBMChars, MorePrompt, ScreenClear: Byte;
    InUserList, MailCheck, NewFileCheck: Byte;
    BirthDay, BirthMonth: Byte;
    BirthYear: Word;
    LastPwdChange: LongWord;
    PwdLength: Byte;
    PwdText: String;

    MsgTag: TMsgTag;
    FileTag: TFileTag;

    constructor Create; overload;
    constructor Create(const AUserFile: String); overload;
    destructor Destroy; override;

    function Add: Boolean;
    function Age: Word;
    procedure ChangeLimitClass(const AOld, ANew: String);
    function CheckPassword(const APwd: String): Boolean;
    procedure Clear;
    function Delete: Boolean;
    function First: Boolean;
    function GetData(const AName: String; CheckRealName: Boolean = False): Boolean;
    function Next: Boolean;
    procedure SetPassword(const APwd: String);
    procedure Pack;
    function Previous: Boolean;
    procedure Reindex;
    function Update: Boolean;
  end;

  TMsgTag = class
  private
    FDatFile: String;
    FData: TCollection;
    procedure CopyFromRecord(P: PMSGTAGS);
  public
    Tagged: Byte;
    UserId: LongWord;
    Area: String;
    LastRead: LongWord;
    OlderMsg: LongWord;

    constructor Create; overload;
    constructor Create(const AUserFile: String); overload;
    destructor Destroy; override;

    procedure Add;
    procedure ChangeArea(const AOldName, ANewName: String);
    procedure ChangeUserId(OldId, NewId: LongWord);
    procedure Clear;
    function First: Boolean;
    procedure Load;
    procedure New_;
    function Next: Boolean;
    function Previous: Boolean;
    function Read(const AArea: String): Boolean;
    procedure Save;
    procedure Update;
  end;

  TFileTag = class
  private
    FDatFile: String;
    FData: TCollection;
    procedure CopyFromRecord(P: PFILETAGS);
  public
    UserId: LongWord;
    Index_: Word;
    Area: String;
    Name: String;
    Complete: String;
    Size: LongWord;
    DeleteAfter: Word;
    CdRom: Word;
    TotalFiles: Word;
    TotalBytes: LongWord;

    constructor Create; overload;
    constructor Create(const AUserFile: String); overload;
    destructor Destroy; override;

    function Add: Boolean;
    procedure ChangeArea(const AOldName, ANewName: String);
    procedure ChangeUserId(OldId, NewId: LongWord);
    function Check(const AName: String): Boolean;
    procedure Clear;
    function First: Boolean;
    procedure Load;
    procedure New_;
    function Next: Boolean;
    function Previous: Boolean;
    procedure Reindex;
    procedure Remove(const AName: String = '');
    function Select(AIndex: Word): Boolean;
    procedure Save;
    procedure Update;
  end;

implementation

const
  MSGTAGS_INDEX = 32;
  FILETAGS_INDEX = 32;

{ ---- TUser ---- }

constructor TUser.Create;
begin
  inherited Create;
  FDat := nil;
  FIdx := nil;
  FDatFile := 'users.dat';
  FIdxFile := 'users.idx';
  FCurrentCRC := 0;
  MsgTag := TMsgTag.Create;
  FileTag := TFileTag.Create;
end;

constructor TUser.Create(const AUserFile: String);
begin
  inherited Create;
  FDat := nil;
  FIdx := nil;
  FDatFile := AUserFile + '.dat';
  FIdxFile := AUserFile + '.idx';
  FCurrentCRC := 0;
  MsgTag := TMsgTag.Create(AUserFile);
  FileTag := TFileTag.Create(AUserFile);
end;

destructor TUser.Destroy;
begin
  FreeAndNil(FDat);
  FreeAndNil(FIdx);
  FreeAndNil(FileTag);
  FreeAndNil(MsgTag);
  inherited Destroy;
end;

procedure TUser.Struct2Class;
begin
  Name := StrPas(FUsr.Name);
  Password := FUsr.Password;
  RealName := StrPas(FUsr.RealName);
  Company := StrPas(FUsr.Company);
  Address_ := StrPas(FUsr.Address);
  City := StrPas(FUsr.City);
  DayPhone := StrPas(FUsr.DayPhone);
  Ansi := FUsr.Ansi;
  Avatar := FUsr.Avatar;
  Color := FUsr.Color;
  HotKey := FUsr.HotKey;
  Sex := FUsr.Sex;
  FullEd := FUsr.FullEd;
  FullReader := FUsr.FullReader;
  NoDisturb := FUsr.NoDisturb;
  AccessFailed := FUsr.AccessFailed;
  ScreenHeight := FUsr.ScreenHeight;
  ScreenWidth := FUsr.ScreenWidth;
  Level := FUsr.Level;
  AccessFlags := FUsr.AccessFlags;
  DenyFlags := FUsr.DenyFlags;
  CreationDate := FUsr.CreationDate;
  LastCall := FUsr.LastCall;
  TotalCalls := FUsr.TotalCalls;
  TodayTime := FUsr.TodayTime;
  WeekTime := FUsr.WeekTime;
  MonthTime := FUsr.MonthTime;
  YearTime := FUsr.YearTime;
  MailBox := StrPas(FUsr.MailBox);
  LimitClass := StrPas(FUsr.LimitClass);
  Language_ := StrPas(FUsr.Language);
  FtpHost := StrPas(FUsr.FtpHost);
  FtpName := StrPas(FUsr.FtpName);
  FtpPwd := StrPas(FUsr.FtpPwd);
  LastMsgArea := StrPas(FUsr.LastMsgArea);
  LastFileArea := StrPas(FUsr.LastFileArea);
  UploadFiles := FUsr.UploadFiles;
  UploadBytes := FUsr.UploadBytes;
  DownloadFiles := FUsr.DownloadFiles;
  DownloadBytes := FUsr.DownloadBytes;
  FilesToday := FUsr.FilesToday;
  BytesToday := FUsr.BytesToday;
  ImportPOP3Mail := FUsr.ImportPOP3Mail;
  UseInetAddress := FUsr.UseInetAddress;
  InetAddress := StrPas(FUsr.InetAddress);
  Pop3Pwd := StrPas(FUsr.Pop3Pwd);
  Archiver := StrPas(FUsr.Archiver);
  Protocol_ := StrPas(FUsr.Protocol);
  Signature := StrPas(FUsr.Signature);
  FullScreen := Byte(FUsr.FullScreen);
  IBMChars := Byte(FUsr.IBMChars);
  MorePrompt := Byte(FUsr.MorePrompt);
  ScreenClear := Byte(FUsr.ScreenClear);
  InUserList := Byte(FUsr.InUserList);
  MailCheck := Byte(FUsr.MailCheck);
  NewFileCheck := Byte(FUsr.NewFileCheck);
  BirthDay := FUsr.BirthDay;
  BirthMonth := FUsr.BirthMonth;
  BirthYear := FUsr.BirthYear;
  LastPwdChange := FUsr.LastPwdChange;
  PwdLength := FUsr.PwdLength;
  PwdText := StrPas(FUsr.PwdText);

  FCurrentCRC := StringCrc32(PChar(Name), $FFFFFFFF);
end;

procedure TUser.Class2Struct;
begin
  FillChar(FUsr, SizeOf(FUsr), 0);
  FUsr.Size := SizeOf(USER_REC);
  StrPCopy(FUsr.Name, Name);
  FUsr.Password := Password;
  StrPCopy(FUsr.RealName, RealName);
  StrPCopy(FUsr.Company, Company);
  StrPCopy(FUsr.Address, Address_);
  StrPCopy(FUsr.City, City);
  StrPCopy(FUsr.DayPhone, DayPhone);
  FUsr.Ansi := Ansi;
  FUsr.Avatar := Avatar;
  FUsr.Color := Color;
  FUsr.HotKey := HotKey;
  FUsr.Sex := Sex;
  FUsr.FullEd := FullEd;
  FUsr.FullReader := FullReader;
  FUsr.NoDisturb := NoDisturb;
  FUsr.AccessFailed := AccessFailed;
  FUsr.ScreenHeight := ScreenHeight;
  FUsr.ScreenWidth := ScreenWidth;
  FUsr.Level := Level;
  FUsr.AccessFlags := AccessFlags;
  FUsr.DenyFlags := DenyFlags;
  FUsr.CreationDate := CreationDate;
  FUsr.LastCall := LastCall;
  FUsr.TotalCalls := TotalCalls;
  FUsr.TodayTime := TodayTime;
  FUsr.WeekTime := WeekTime;
  FUsr.MonthTime := MonthTime;
  FUsr.YearTime := YearTime;
  StrPCopy(FUsr.MailBox, MailBox);
  StrPCopy(FUsr.LimitClass, LimitClass);
  StrPCopy(FUsr.Language, Language_);
  StrPCopy(FUsr.FtpHost, FtpHost);
  StrPCopy(FUsr.FtpName, FtpName);
  StrPCopy(FUsr.FtpPwd, FtpPwd);
  StrPCopy(FUsr.LastMsgArea, LastMsgArea);
  StrPCopy(FUsr.LastFileArea, LastFileArea);
  FUsr.UploadFiles := UploadFiles;
  FUsr.UploadBytes := UploadBytes;
  FUsr.DownloadFiles := DownloadFiles;
  FUsr.DownloadBytes := DownloadBytes;
  FUsr.FilesToday := FilesToday;
  FUsr.BytesToday := BytesToday;
  FUsr.ImportPOP3Mail := ImportPOP3Mail;
  FUsr.UseInetAddress := UseInetAddress;
  StrPCopy(FUsr.InetAddress, InetAddress);
  StrPCopy(FUsr.Pop3Pwd, Pop3Pwd);
  StrPCopy(FUsr.Archiver, Archiver);
  StrPCopy(FUsr.Protocol, Protocol_);
  StrPCopy(FUsr.Signature, Signature);
  FUsr.FullScreen := Char(FullScreen);
  FUsr.IBMChars := Char(IBMChars);
  FUsr.MorePrompt := Char(MorePrompt);
  FUsr.ScreenClear := Char(ScreenClear);
  FUsr.InUserList := Char(InUserList);
  FUsr.MailCheck := Char(MailCheck);
  FUsr.NewFileCheck := Char(NewFileCheck);
  FUsr.BirthDay := BirthDay;
  FUsr.BirthMonth := BirthMonth;
  FUsr.BirthYear := BirthYear;
  FUsr.LastPwdChange := LastPwdChange;
  FUsr.PwdLength := PwdLength;
  StrPCopy(FUsr.PwdText, PwdText);
end;

procedure TUser.EnsureOpen;
begin
  if FIdx = nil then
  begin
    if FileExists(FIdxFile) then
      FIdx := TFileStream.Create(FIdxFile, fmOpenReadWrite or fmShareDenyNone)
    else
      FIdx := TFileStream.Create(FIdxFile, fmCreate);
  end;
  if FDat = nil then
  begin
    if FileExists(FDatFile) then
      FDat := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone)
    else
      FDat := TFileStream.Create(FDatFile, fmCreate);
  end;
end;

procedure TUser.Clear;
begin
  FillChar(FUsr, SizeOf(FUsr), 0);
  Struct2Class;
  MsgTag.Clear;
  FileTag.Clear;
end;

function TUser.Add: Boolean;
begin
  Result := False;
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  FDat.Seek(0, soEnd);
  FIdx.Seek(0, soEnd);

  FillChar(FUIdx, SizeOf(FUIdx), 0);
  FUIdx.Deleted := 0;
  FUIdx.NameCrc := StringCrc32(PChar(Name), $FFFFFFFF);
  FUIdx.RealNameCrc := StringCrc32(PChar(RealName), $FFFFFFFF);
  FUIdx.Position := FDat.Position;

  FCurrentCRC := FUIdx.NameCrc;
  Class2Struct;

  FDat.Write(FUsr, SizeOf(FUsr));
  FIdx.Write(FUIdx, SizeOf(FUIdx));

  MsgTag.UserId := FUIdx.NameCrc;
  MsgTag.Load;
  FileTag.UserId := FUIdx.NameCrc;
  FileTag.Load;

  Result := True;
end;

function TUser.Age: Word;
var
  Y, M, D: Word;
begin
  Result := 0;
  DecodeDate(Now, Y, M, D);
  if (BirthDay <> 0) and (BirthMonth <> 0) and (BirthYear > 1880) and (BirthYear < Y) then
  begin
    Result := Y - BirthYear;
    if M < BirthMonth then
      Dec(Result)
    else if (M = BirthMonth) and (D < BirthDay) then
      Dec(Result);
  end;
end;

procedure TUser.ChangeLimitClass(const AOld, ANew: String);
var
  FD: TFileStream;
begin
  if not FileExists(FDatFile) then Exit;
  try
    FD := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone);
  except
    Exit;
  end;

  try
    FD.Seek(0, soBeginning);
    while FD.Read(FUsr, SizeOf(FUsr)) = SizeOf(FUsr) do
    begin
      if SameText(StrPas(FUsr.LimitClass), AOld) then
      begin
        StrPCopy(FUsr.LimitClass, ANew);
        FD.Seek(FD.Position - SizeOf(FUsr), soBeginning);
        FD.Write(FUsr, SizeOf(FUsr));
      end;
    end;
  finally
    FD.Free;
  end;
end;

function TUser.CheckPassword(const APwd: String): Boolean;
begin
  Result := Password = StringCrc32(PChar(UpperCase(APwd)), $FFFFFFFF);
end;

function TUser.Delete: Boolean;
var
  NameCrc: LongWord;
  WasAuto: Boolean;
begin
  Result := False;
  WasAuto := (FIdx = nil) or (FDat = nil);
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  try
    NameCrc := StringCrc32(PChar(Name), $FFFFFFFF);
    FIdx.Seek(0, soBeginning);
    while FIdx.Read(FUIdx, SizeOf(FUIdx)) = SizeOf(FUIdx) do
    begin
      if (FUIdx.Deleted = 0) and (FUIdx.NameCrc = NameCrc) then
      begin
        Result := True;
        Break;
      end;
    end;

    if Result then
    begin
      FUIdx.Deleted := 1;
      FIdx.Seek(FIdx.Position - SizeOf(FUIdx), soBeginning);
      FIdx.Write(FUIdx, SizeOf(FUIdx));
    end;
  finally
    if WasAuto then
    begin
      FreeAndNil(FDat);
      FreeAndNil(FIdx);
    end;
  end;
end;

function TUser.First: Boolean;
begin
  Result := False;
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;
  FIdx.Seek(0, soBeginning);
  FDat.Seek(0, soBeginning);
  Result := Next;
end;

function TUser.GetData(const AName: String; CheckRealName: Boolean): Boolean;
var
  TestCrc: LongWord;
  WasAuto: Boolean;
begin
  Result := False;
  WasAuto := (FIdx = nil) or (FDat = nil);
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  try
    Clear;
    TestCrc := StringCrc32(PChar(AName), $FFFFFFFF);

    { Search by name CRC }
    FIdx.Seek(0, soBeginning);
    while FIdx.Read(FUIdx, SizeOf(FUIdx)) = SizeOf(FUIdx) do
    begin
      if (FUIdx.Deleted = 0) and (FUIdx.NameCrc = TestCrc) then
      begin
        Result := True;
        Break;
      end;
    end;

    { If not found, try real name CRC }
    if (not Result) and CheckRealName then
    begin
      FIdx.Seek(0, soBeginning);
      while FIdx.Read(FUIdx, SizeOf(FUIdx)) = SizeOf(FUIdx) do
      begin
        if (FUIdx.Deleted = 0) and (FUIdx.RealNameCrc = TestCrc) then
        begin
          Result := True;
          Break;
        end;
      end;
    end;

    if Result then
    begin
      FDat.Seek(FUIdx.Position, soBeginning);
      FDat.Read(FUsr, SizeOf(FUsr));
      Struct2Class;

      MsgTag.UserId := FUIdx.NameCrc;
      MsgTag.Load;
      FileTag.UserId := FUIdx.NameCrc;
      FileTag.Load;
    end;
  finally
    if WasAuto then
    begin
      FreeAndNil(FDat);
      FreeAndNil(FIdx);
    end;
  end;
end;

function TUser.Next: Boolean;
begin
  Result := False;
  if (FDat = nil) or (FIdx = nil) then Exit;

  while FIdx.Read(FUIdx, SizeOf(FUIdx)) = SizeOf(FUIdx) do
  begin
    if FUIdx.Deleted = 0 then
    begin
      Result := True;
      Break;
    end;
  end;

  if Result then
  begin
    Clear;
    FDat.Seek(FUIdx.Position, soBeginning);
    FDat.Read(FUsr, SizeOf(FUsr));
    Struct2Class;
  end;
end;

procedure TUser.SetPassword(const APwd: String);
begin
  Password := StringCrc32(PChar(UpperCase(APwd)), $FFFFFFFF);
end;

procedure TUser.Pack;
var
  NewStream: TFileStream;
  TmpFile: String;
begin
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  TmpFile := ExtractFilePath(FDatFile) + 'users.new';
  try
    NewStream := TFileStream.Create(TmpFile, fmCreate);
  except
    Exit;
  end;

  try
    { First pass: copy non-deleted records to temp file }
    FIdx.Seek(0, soBeginning);
    FDat.Seek(0, soBeginning);
    while FIdx.Read(FUIdx, SizeOf(FUIdx)) = SizeOf(FUIdx) do
    begin
      if FUIdx.Deleted = 0 then
      begin
        FDat.Seek(FUIdx.Position, soBeginning);
        FDat.Read(FUsr, SizeOf(FUsr));
        NewStream.Write(FUsr, SizeOf(FUsr));
      end;
    end;

    { Second pass: rebuild idx and dat from temp }
    FIdx.Seek(0, soBeginning);
    FDat.Seek(0, soBeginning);
    NewStream.Seek(0, soBeginning);

    while NewStream.Read(FUsr, SizeOf(FUsr)) = SizeOf(FUsr) do
    begin
      FillChar(FUIdx, SizeOf(FUIdx), 0);
      FUIdx.Deleted := 0;
      FUIdx.NameCrc := StringCrc32(FUsr.Name, $FFFFFFFF);
      FUIdx.RealNameCrc := StringCrc32(FUsr.RealName, $FFFFFFFF);
      FUIdx.Position := FDat.Position;
      FDat.Write(FUsr, SizeOf(FUsr));
      FIdx.Write(FUIdx, SizeOf(FUIdx));
    end;

    { Truncate files to current position }
    FDat.Size := FDat.Position;
    FIdx.Size := FIdx.Position;
  finally
    NewStream.Free;
    SysUtils.DeleteFile(TmpFile);
  end;

  FreeAndNil(FIdx);
  FreeAndNil(FDat);
end;

function TUser.Previous: Boolean;
begin
  Result := False;
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  while FIdx.Position >= SizeOf(UINDEX) * 2 do
  begin
    FIdx.Seek(FIdx.Position - SizeOf(UINDEX) * 2, soBeginning);
    if FIdx.Read(FUIdx, SizeOf(FUIdx)) = SizeOf(FUIdx) then
    begin
      if FUIdx.Deleted = 0 then
      begin
        Result := True;
        Break;
      end;
    end;
  end;

  if Result then
  begin
    Clear;
    FDat.Seek(FUIdx.Position, soBeginning);
    FDat.Read(FUsr, SizeOf(FUsr));
    Struct2Class;
  end;
end;

procedure TUser.Reindex;
var
  Position: LongWord;
begin
  FreeAndNil(FDat);
  FreeAndNil(FIdx);

  if FileExists(FDatFile) then
    FDat := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone)
  else
    FDat := TFileStream.Create(FDatFile, fmCreate);

  FIdx := TFileStream.Create(FIdxFile, fmCreate);

  try
    FDat.Seek(0, soBeginning);
    while True do
    begin
      Position := FDat.Position;
      if FDat.Read(FUsr, SizeOf(FUsr)) <> SizeOf(FUsr) then Break;
      if FUsr.Size = SizeOf(USER_REC) then
      begin
        FillChar(FUIdx, SizeOf(FUIdx), 0);
        FUIdx.Deleted := 0;
        FUIdx.NameCrc := StringCrc32(FUsr.Name, $FFFFFFFF);
        FUIdx.RealNameCrc := StringCrc32(FUsr.RealName, $FFFFFFFF);
        FUIdx.Position := Position;
        FIdx.Write(FUIdx, SizeOf(FUIdx));
      end;
    end;
  finally
    FreeAndNil(FDat);
    FreeAndNil(FIdx);
  end;
end;

function TUser.Update: Boolean;
var
  WasAuto: Boolean;
  NewNameCrc: LongWord;
begin
  Result := False;
  WasAuto := (FIdx = nil) or (FDat = nil);
  EnsureOpen;
  if (FDat = nil) or (FIdx = nil) then Exit;

  try
    { Find by current CRC }
    FIdx.Seek(0, soBeginning);
    while FIdx.Read(FUIdx, SizeOf(FUIdx)) = SizeOf(FUIdx) do
    begin
      if (FUIdx.Deleted = 0) and (FUIdx.NameCrc = FCurrentCRC) then
      begin
        Result := True;
        Break;
      end;
    end;

    if Result then
    begin
      Class2Struct;

      { Update index CRCs }
      NewNameCrc := StringCrc32(PChar(Name), $FFFFFFFF);
      FUIdx.NameCrc := NewNameCrc;
      FUIdx.RealNameCrc := StringCrc32(PChar(RealName), $FFFFFFFF);
      FIdx.Seek(FIdx.Position - SizeOf(FUIdx), soBeginning);
      FIdx.Write(FUIdx, SizeOf(FUIdx));

      { Update data record }
      FDat.Seek(FUIdx.Position, soBeginning);
      FDat.Write(FUsr, SizeOf(FUsr));

      { If name changed, update tags }
      if FCurrentCRC <> NewNameCrc then
      begin
        MsgTag.ChangeUserId(FCurrentCRC, NewNameCrc);
        FileTag.ChangeUserId(FCurrentCRC, NewNameCrc);
        FCurrentCRC := NewNameCrc;
      end;

      MsgTag.UserId := NewNameCrc;
      MsgTag.Save;
      FileTag.UserId := NewNameCrc;
      FileTag.Save;
    end;
  finally
    if WasAuto then
    begin
      FreeAndNil(FDat);
      FreeAndNil(FIdx);
    end;
  end;
end;

{ ---- TMsgTag ---- }

constructor TMsgTag.Create;
begin
  inherited Create;
  FData := TCollection.Create;
  FDatFile := 'msgtags.dat';
end;

constructor TMsgTag.Create(const AUserFile: String);
begin
  inherited Create;
  FData := TCollection.Create;
  FDatFile := ExtractFilePath(AUserFile) + 'msgtags.dat';
end;

destructor TMsgTag.Destroy;
begin
  FData.Clear;
  FreeAndNil(FData);
  inherited Destroy;
end;

procedure TMsgTag.CopyFromRecord(P: PMSGTAGS);
begin
  Tagged := P^.Tagged;
  Area := StrPas(P^.Area);
  LastRead := P^.LastRead;
  OlderMsg := P^.OlderMsg;
end;

procedure TMsgTag.New_;
begin
  Tagged := 0;
  Area := '';
  LastRead := 0;
  OlderMsg := 0;
end;

procedure TMsgTag.Clear;
begin
  FData.Clear;
  New_;
end;

procedure TMsgTag.Add;
var
  Buffer: MSGTAGS;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  Buffer.Free := 0;
  Buffer.Tagged := Tagged;
  Buffer.UserId := UserId;
  StrPCopy(Buffer.Area, Area);
  Buffer.LastRead := LastRead;
  Buffer.OlderMsg := OlderMsg;
  FData.Add(@Buffer, SizeOf(MSGTAGS));
end;

procedure TMsgTag.ChangeArea(const AOldName, ANewName: String);
var
  FD: TFileStream;
  Buffer: array[0..MSGTAGS_INDEX - 1] of MSGTAGS;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
begin
  if not FileExists(FDatFile) then Exit;
  try
    FD := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone);
  except
    Exit;
  end;

  try
    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(MSGTAGS);
      for I := 0 to Count - 1 do
      begin
        if (Buffer[I].Free = 0) and SameText(StrPas(Buffer[I].Area), AOldName) then
        begin
          StrPCopy(Buffer[I].Area, ANewName);
          Changed := True;
        end;
      end;
      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(MSGTAGS) * Count);
      end;
    until Count < MSGTAGS_INDEX;
  finally
    FD.Free;
  end;
end;

procedure TMsgTag.ChangeUserId(OldId, NewId: LongWord);
var
  FD: TFileStream;
  Buffer: array[0..MSGTAGS_INDEX - 1] of MSGTAGS;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
begin
  if not FileExists(FDatFile) then Exit;
  try
    FD := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone);
  except
    Exit;
  end;

  try
    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(MSGTAGS);
      for I := 0 to Count - 1 do
      begin
        if (Buffer[I].Free = 0) and (Buffer[I].UserId = OldId) then
        begin
          Buffer[I].UserId := NewId;
          Changed := True;
        end;
      end;
      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(MSGTAGS) * Count);
      end;
    until Count < MSGTAGS_INDEX;
  finally
    FD.Free;
  end;
end;

function TMsgTag.First: Boolean;
var
  P: PMSGTAGS;
begin
  Result := False;
  P := PMSGTAGS(FData.First);
  if P <> nil then
  begin
    CopyFromRecord(P);
    Result := True;
  end;
end;

function TMsgTag.Next: Boolean;
var
  P: PMSGTAGS;
begin
  Result := False;
  P := PMSGTAGS(FData.Next);
  if P <> nil then
  begin
    CopyFromRecord(P);
    Result := True;
  end;
end;

function TMsgTag.Previous: Boolean;
var
  P: PMSGTAGS;
begin
  Result := False;
  P := PMSGTAGS(FData.Previous);
  if P <> nil then
  begin
    CopyFromRecord(P);
    Result := True;
  end;
end;

function TMsgTag.Read(const AArea: String): Boolean;
begin
  Result := False;
  if First then
    repeat
      if SameText(AArea, Area) then
      begin
        Result := True;
        Exit;
      end;
    until not Next;
end;

procedure TMsgTag.Load;
var
  FD: TFileStream;
  Buffer: array[0..MSGTAGS_INDEX - 1] of MSGTAGS;
  Count, I: Integer;
begin
  FData.Clear;
  if not FileExists(FDatFile) then Exit;

  try
    FD := TFileStream.Create(FDatFile, fmOpenRead or fmShareDenyNone);
  except
    Exit;
  end;

  try
    repeat
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(MSGTAGS);
      for I := 0 to Count - 1 do
      begin
        if (Buffer[I].Free = 0) and (Buffer[I].UserId = UserId) then
          FData.Add(@Buffer[I], SizeOf(MSGTAGS));
      end;
    until Count < MSGTAGS_INDEX;
  finally
    FD.Free;
  end;

  { Position to first entry }
  if FData.First <> nil then
    CopyFromRecord(PMSGTAGS(FData.Value));
end;

procedure TMsgTag.Save;
var
  FD: TFileStream;
  Buffer: array[0..MSGTAGS_INDEX - 1] of MSGTAGS;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
  RecPtr: PMSGTAGS;
begin
  if FileExists(FDatFile) then
    FD := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone)
  else
    FD := TFileStream.Create(FDatFile, fmCreate);

  try
    RecPtr := PMSGTAGS(FData.First);

    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(MSGTAGS);

      for I := 0 to Count - 1 do
      begin
        if RecPtr = nil then Break;
        if (Buffer[I].UserId = RecPtr^.UserId) or (Buffer[I].Free <> 0) then
        begin
          Move(RecPtr^, Buffer[I], SizeOf(MSGTAGS));
          Buffer[I].Free := 0;
          RecPtr := PMSGTAGS(FData.Next);
          Changed := True;
        end;
      end;

      while I < Count do
      begin
        if Buffer[I].UserId = UserId then
        begin
          FillChar(Buffer[I], SizeOf(MSGTAGS), 0);
          Buffer[I].Free := 1;
          Changed := True;
        end;
        Inc(I);
      end;

      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(MSGTAGS) * Count);
      end;
    until Count < MSGTAGS_INDEX;

    while RecPtr <> nil do
    begin
      FD.Write(RecPtr^, SizeOf(MSGTAGS));
      RecPtr := PMSGTAGS(FData.Next);
    end;
  finally
    FD.Free;
  end;
end;

procedure TMsgTag.Update;
var
  P: PMSGTAGS;
begin
  P := PMSGTAGS(FData.Value);
  if P <> nil then
  begin
    P^.Tagged := Tagged;
    StrPCopy(P^.Area, Area);
    P^.LastRead := LastRead;
    P^.OlderMsg := OlderMsg;
  end;
end;

{ ---- TFileTag ---- }

constructor TFileTag.Create;
begin
  inherited Create;
  FData := TCollection.Create;
  FDatFile := 'filetags.dat';
  TotalFiles := 0;
  TotalBytes := 0;
  New_;
end;

constructor TFileTag.Create(const AUserFile: String);
begin
  inherited Create;
  FData := TCollection.Create;
  FDatFile := ExtractFilePath(AUserFile) + 'filetags.dat';
  TotalFiles := 0;
  TotalBytes := 0;
  New_;
end;

destructor TFileTag.Destroy;
begin
  FData.Clear;
  FreeAndNil(FData);
  inherited Destroy;
end;

procedure TFileTag.CopyFromRecord(P: PFILETAGS);
begin
  Area := StrPas(P^.Area);
  Name := StrPas(P^.Name);
  Complete := StrPas(P^.Complete);
  Size := P^.Size;
  DeleteAfter := P^.DeleteAfter;
  CdRom := P^.CdRom;
  Index_ := P^.Index_;
end;

procedure TFileTag.New_;
begin
  Area := '';
  Name := '';
  Complete := '';
  Size := 0;
  CdRom := 0;
  DeleteAfter := 0;
  Index_ := FData.Elements + 1;
end;

procedure TFileTag.Clear;
begin
  FData.Clear;
  New_;
  Index_ := 0;
  TotalFiles := 0;
  TotalBytes := 0;
end;

function TFileTag.Add: Boolean;
var
  Buffer: FILETAGS;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  Buffer.Free := 0;
  Buffer.UserId := UserId;
  StrPCopy(Buffer.Area, Area);
  StrPCopy(Buffer.Name, Name);
  StrPCopy(Buffer.Complete, Complete);
  Buffer.Size := Size;
  Buffer.DeleteAfter := DeleteAfter;
  Buffer.CdRom := CdRom;
  Buffer.Index_ := FData.Elements + 1;
  Index_ := Buffer.Index_;

  Result := FData.Add(@Buffer, SizeOf(FILETAGS)) <> 0;
  if Result then
  begin
    Inc(TotalFiles);
    Inc(TotalBytes, Size);
  end;
end;

procedure TFileTag.ChangeArea(const AOldName, ANewName: String);
var
  FD: TFileStream;
  Buffer: array[0..FILETAGS_INDEX - 1] of FILETAGS;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
begin
  if not FileExists(FDatFile) then Exit;
  try
    FD := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone);
  except
    Exit;
  end;

  try
    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(FILETAGS);
      for I := 0 to Count - 1 do
      begin
        if (Buffer[I].Free = 0) and SameText(StrPas(Buffer[I].Area), AOldName) then
        begin
          StrPCopy(Buffer[I].Area, ANewName);
          Changed := True;
        end;
      end;
      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(FILETAGS) * Count);
      end;
    until Count < FILETAGS_INDEX;
  finally
    FD.Free;
  end;
end;

procedure TFileTag.ChangeUserId(OldId, NewId: LongWord);
var
  FD: TFileStream;
  Buffer: array[0..FILETAGS_INDEX - 1] of FILETAGS;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
begin
  if not FileExists(FDatFile) then Exit;
  try
    FD := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone);
  except
    Exit;
  end;

  try
    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(FILETAGS);
      for I := 0 to Count - 1 do
      begin
        if (Buffer[I].Free = 0) and (Buffer[I].UserId = OldId) then
        begin
          Buffer[I].UserId := NewId;
          Changed := True;
        end;
      end;
      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(FILETAGS) * Count);
      end;
    until Count < FILETAGS_INDEX;
  finally
    FD.Free;
  end;
end;

function TFileTag.Check(const AName: String): Boolean;
var
  P: PFILETAGS;
begin
  Result := False;
  P := PFILETAGS(FData.First);
  while P <> nil do
  begin
    if SameText(StrPas(P^.Name), AName) then
    begin
      CopyFromRecord(P);
      Result := True;
      Exit;
    end;
    P := PFILETAGS(FData.Next);
  end;
end;

function TFileTag.First: Boolean;
var
  P: PFILETAGS;
begin
  Result := False;
  P := PFILETAGS(FData.First);
  if P <> nil then
  begin
    CopyFromRecord(P);
    Result := True;
  end;
end;

function TFileTag.Next: Boolean;
var
  P: PFILETAGS;
begin
  Result := False;
  P := PFILETAGS(FData.Next);
  if P <> nil then
  begin
    CopyFromRecord(P);
    Result := True;
  end;
end;

function TFileTag.Previous: Boolean;
var
  P: PFILETAGS;
begin
  Result := False;
  P := PFILETAGS(FData.Previous);
  if P <> nil then
  begin
    CopyFromRecord(P);
    Result := True;
  end;
end;

procedure TFileTag.Load;
var
  FD: TFileStream;
  Buffer: array[0..FILETAGS_INDEX - 1] of FILETAGS;
  Count, I: Integer;
begin
  FData.Clear;
  TotalFiles := 0;
  TotalBytes := 0;

  if not FileExists(FDatFile) then Exit;
  try
    FD := TFileStream.Create(FDatFile, fmOpenRead or fmShareDenyNone);
  except
    Exit;
  end;

  try
    repeat
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(FILETAGS);
      for I := 0 to Count - 1 do
      begin
        if (Buffer[I].Free = 0) and (Buffer[I].UserId = UserId) then
        begin
          Buffer[I].Index_ := FData.Elements + 1;
          Index_ := Buffer[I].Index_;
          if FData.Add(@Buffer[I], SizeOf(FILETAGS)) <> 0 then
          begin
            Inc(TotalFiles);
            Inc(TotalBytes, Buffer[I].Size);
          end;
        end;
      end;
    until Count < FILETAGS_INDEX;
  finally
    FD.Free;
  end;

  if FData.First <> nil then
    CopyFromRecord(PFILETAGS(FData.Value));
end;

procedure TFileTag.Reindex;
var
  LastIndex: Word;
  P: PFILETAGS;
begin
  LastIndex := 1;
  P := PFILETAGS(FData.First);
  while P <> nil do
  begin
    P^.Index_ := LastIndex;
    Inc(LastIndex);
    P := PFILETAGS(FData.Next);
  end;
end;

procedure TFileTag.Remove(const AName: String);
var
  P: PFILETAGS;
  Found: Boolean;
begin
  if AName <> '' then
  begin
    Found := False;
    P := PFILETAGS(FData.First);
    while (P <> nil) and not Found do
    begin
      if SameText(StrPas(P^.Name), AName) then
        Found := True
      else
        P := PFILETAGS(FData.Next);
    end;
    if Found and (P <> nil) then
    begin
      if P^.DeleteAfter <> 0 then
        SysUtils.DeleteFile(StrPas(P^.Complete));
      Dec(TotalFiles);
      Dec(TotalBytes, P^.Size);
      FData.Remove;
    end;
  end
  else
  begin
    if DeleteAfter <> 0 then
      SysUtils.DeleteFile(Complete);
    Dec(TotalFiles);
    Dec(TotalBytes, Size);
    FData.Remove;
  end;

  P := PFILETAGS(FData.Value);
  if P <> nil then
    CopyFromRecord(P);
end;

function TFileTag.Select(AIndex: Word): Boolean;
var
  P: PFILETAGS;
begin
  Result := False;
  P := PFILETAGS(FData.First);
  while P <> nil do
  begin
    if P^.Index_ = AIndex then
    begin
      CopyFromRecord(P);
      Result := True;
      Exit;
    end;
    P := PFILETAGS(FData.Next);
  end;
end;

procedure TFileTag.Save;
var
  FD: TFileStream;
  Buffer: array[0..FILETAGS_INDEX - 1] of FILETAGS;
  Count, I: Integer;
  Position: Int64;
  Changed: Boolean;
  RecPtr: PFILETAGS;
begin
  if FileExists(FDatFile) then
    FD := TFileStream.Create(FDatFile, fmOpenReadWrite or fmShareDenyNone)
  else
    FD := TFileStream.Create(FDatFile, fmCreate);

  try
    RecPtr := PFILETAGS(FData.First);

    repeat
      Changed := False;
      Position := FD.Position;
      Count := FD.Read(Buffer, SizeOf(Buffer)) div SizeOf(FILETAGS);

      for I := 0 to Count - 1 do
      begin
        if RecPtr = nil then Break;
        if (Buffer[I].UserId = RecPtr^.UserId) or (Buffer[I].Free <> 0) then
        begin
          Move(RecPtr^, Buffer[I], SizeOf(FILETAGS));
          RecPtr := PFILETAGS(FData.Next);
          Changed := True;
        end;
      end;

      while I < Count do
      begin
        if Buffer[I].UserId = UserId then
        begin
          FillChar(Buffer[I], SizeOf(FILETAGS), 0);
          Buffer[I].Free := 1;
          Changed := True;
        end;
        Inc(I);
      end;

      if Changed then
      begin
        FD.Seek(Position, soBeginning);
        FD.Write(Buffer, SizeOf(FILETAGS) * Count);
      end;
    until Count < FILETAGS_INDEX;

    while RecPtr <> nil do
    begin
      FD.Write(RecPtr^, SizeOf(FILETAGS));
      RecPtr := PFILETAGS(FData.Next);
    end;
  finally
    FD.Free;
  end;
end;

procedure TFileTag.Update;
var
  P: PFILETAGS;
begin
  P := PFILETAGS(FData.Value);
  if P <> nil then
  begin
    Dec(TotalBytes, P^.Size);
    StrPCopy(P^.Area, Area);
    StrPCopy(P^.Name, Name);
    StrPCopy(P^.Complete, Complete);
    P^.Size := Size;
    P^.DeleteAfter := DeleteAfter;
    P^.CdRom := CdRom;
    Inc(TotalBytes, Size);
  end;
end;

end.
