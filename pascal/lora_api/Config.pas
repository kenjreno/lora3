{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of config.cpp - TConfig class
  System configuration management. Reads/writes config.dat and channel.dat.
  Uses IncludeTrailingPathDelimiter/ExcludeTrailingPathDelimiter for path
  normalization instead of C FixPath/AdjustPath.
}

unit Config;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Struc299, Address;

type
  TConfig = class
  public
    Device:             array[0..31] of Char;
    Speed:              LongWord;
    Initialize:         array[0..2, 0..47] of Char;
    Answer:             array[0..47] of Char;
    Dial:               array[0..47] of Char;
    Hangup:             array[0..47] of Char;
    OffHook:            array[0..47] of Char;
    DialTimeout:        Word;
    LockSpeed:          Word;
    CarrierDropTimeout: Word;
    StripDashes:        Word;
    Ring:               array[0..31] of Char;
    ManualAnswer:       Byte;
    LimitedHours:       Byte;
    StartTime:          Word;
    EndTime:            Word;
    FaxMessage:         array[0..47] of Char;
    FaxCommand:         array[0..63] of Char;
    CallIf:             array[0..63] of Char;
    DontCallIf:         array[0..63] of Char;

    SystemName:         array[0..63] of Char;
    SysopName:          array[0..47] of Char;
    Location:           array[0..47] of Char;
    Phone:              array[0..31] of Char;
    NodelistFlags:      array[0..63] of Char;
    LoginType:          Byte;
    UseAnsi:            Byte;
    AskAlias:           Byte;
    AskCompanyName:     Byte;
    AskAddress:         Byte;
    AskCity:            Byte;
    AskPhoneNumber:     Byte;
    AskGender:          Byte;
    TaskNumber:         Word;
    NewUserLevel:       Word;
    NewUserFlags:       LongWord;
    NewUserDenyFlags:   LongWord;
    NewUserLimits:      array[0..15] of Char;
    SystemPath:         array[0..63] of Char;
    LogFile:            array[0..63] of Char;
    UserFile:           array[0..63] of Char;
    Outbound:           array[0..63] of Char;
    SchedulerFile:      array[0..63] of Char;
    NormalInbound:      array[0..63] of Char;
    KnownInbound:       array[0..63] of Char;
    ProtectedInbound:   array[0..63] of Char;
    NodelistPath:       array[0..63] of Char;
    UsersHomePath:      array[0..63] of Char;
    MenuPath:           array[0..63] of Char;
    LanguageFile:       array[0..63] of Char;
    TextFiles:          array[0..63] of Char;
    TempPath:           array[0..63] of Char;
    MainMenu:           array[0..31] of Char;
    HostName:           array[0..47] of Char;
    NewsServer:         array[0..47] of Char;
    MailServer:         array[0..47] of Char;
    PopServer:          array[0..47] of Char;
    FakeNet:            Word;
    NetMailStorage:     Word;
    MailStorage:        Word;
    BadStorage:         Word;
    DupeStorage:        Word;
    NetMailPath:        array[0..63] of Char;
    MailPath:           array[0..63] of Char;
    BadPath:            array[0..63] of Char;
    DupePath:           array[0..63] of Char;
    TelnetServer:       Word;
    TelnetPort:         Word;
    FtpServer:          Word;
    FtpPort:            Word;
    WebServer:          Word;
    WebPort:            Word;
    SMTPServer:         Word;
    SMTPPort:           Word;
    POP3Server:         Word;
    POP3Port:           Word;
    NNTPServer:         Word;
    NNTPPort:           Word;
    WaZoo:              Word;
    EMSI:               Word;
    Janus:              Word;
    NewAreasStorage:    Word;
    NewAreasPath:       array[0..63] of Char;
    NewAreasLevel:      Word;
    NewAreasWriteLevel: Word;
    NewAreasFlags:      LongWord;
    NewAreasDenyFlags:  LongWord;
    NewAreasWriteFlags: LongWord;
    NewAreasDenyWriteFlags: LongWord;
    Ansi:               Byte;
    IEMSI:              Byte;
    ImportEmpty:        Byte;
    ReplaceTear:        Byte;
    ForceIntl:          Byte;
    TearLine:           array[0..31] of Char;
    Secure:             Byte;
    KeepNetMail:        Byte;
    TrackNetMail:       Byte;
    MailOnly:           array[0..63] of Char;
    EnterBBS:           array[0..63] of Char;
    ImportCmd:          array[0..63] of Char;
    ExportCmd:          array[0..63] of Char;
    SinglePassCmd:      array[0..63] of Char;
    PackCmd:            array[0..63] of Char;
    NewsgroupCmd:       array[0..63] of Char;
    AfterCallerCmd:     array[0..63] of Char;
    AfterMailCmd:       array[0..63] of Char;
    UseSinglePass:      Byte;
    SeparateNetMail:    Byte;
    UseAreasBBS:        Byte;
    UpdateAreasBBS:     Byte;
    AreasBBS:           array[0..63] of Char;
    PPPCmd:             array[0..63] of Char;
    ZModemTelnet:       Byte;
    EnablePPP:          Byte;
    PPPTimeLimit:       Word;
    OLRPacketName:      array[0..15] of Char;
    OLRMaxMessages:     Word;
    ExternalFax:        Byte;
    FaxFormat:          Byte;
    FaxPath:            array[0..63] of Char;
    AfterFaxCmd:        array[0..63] of Char;
    FaxAlertNodes:      array[0..63] of Char;
    FaxAlertUser:       array[0..63] of Char;
    ReloadLog:          Byte;
    MakeProcessLog:     Byte;
    RetriveMaxMessages: Word;
    UseAvatar:          Byte;
    UseColor:           Byte;
    UseFullScreenEditor: Byte;
    UseHotKey:          Byte;
    UseIBMChars:        Byte;
    AskLines:           Byte;
    UsePause:           Byte;
    UseScreenClear:     Byte;
    AskBirthDate:       Byte;
    AskMailCheck:       Byte;
    AskFileCheck:       Byte;
    ExternalEditor:     Byte;
    EditorCmd:          array[0..63] of Char;
    HudsonPath:         array[0..63] of Char;
    GoldPath:           array[0..63] of Char;
    BadBoard:           Word;
    DupeBoard:          Word;
    MailBoard:          Word;
    NetMailBoard:       Word;
    UseFullScreenReader: Byte;
    UseFullScreenLists:  Byte;
    UseFullScreenAreaLists: Byte;
    AreafixActive:      Byte;
    AllowRescan:        Byte;
    CheckZones:         Byte;
    RaidActive:         Byte;
    AreafixNames:       array[0..63] of Char;
    AreafixHelp:        array[0..63] of Char;
    RaidNames:          array[0..63] of Char;
    RaidHelp:           array[0..63] of Char;
    NewTicPath:         array[0..63] of Char;
    TextPasswords:      Byte;
    MailAddress:        TAddress;

    constructor Create;
    destructor Destroy; override;

    procedure Default;
    function  FixPath(path: PChar): PChar;
    function  AdjustPath(path: PChar): PChar;
    function  Load(pszConfig: PChar = nil; pszChannel: PChar = nil): Word;
    procedure New_;
    procedure NewChannel;
    function  Reload: Word;
    function  Save(pszConfig: PChar = nil; pszChannel: PChar = nil): Word;

  private
    ConfigFile:  array[0..127] of Char;
    ChannelFile: array[0..127] of Char;
    procedure Struct2Class(var Cfg: CONFIG_REC);
  end;

implementation

constructor TConfig.Create;
begin
  inherited Create;
  StrCopy(ConfigFile, 'config.dat');
  StrCopy(ChannelFile, 'channel.dat');
  TaskNumber := 1;
  MailAddress := TAddress.Create;
end;

destructor TConfig.Destroy;
begin
  MailAddress.Free;
  inherited Destroy;
end;

function TConfig.FixPath(path: PChar): PChar;
var
  S: String;
begin
  S := StrPas(path);
  if S <> '' then
  begin
    S := IncludeTrailingPathDelimiter(S);
    {$IFDEF UNIX}
    S := StringReplace(S, '\', '/', [rfReplaceAll]);
    {$ELSE}
    S := StringReplace(S, '/', '\', [rfReplaceAll]);
    {$ENDIF}
    StrPCopy(path, S);
  end;
  Result := path;
end;

function TConfig.AdjustPath(path: PChar): PChar;
var
  S: String;
begin
  S := StrPas(path);
  if S <> '' then
  begin
    S := ExcludeTrailingPathDelimiter(S);
    {$IFDEF UNIX}
    S := StringReplace(S, '\', '/', [rfReplaceAll]);
    {$ELSE}
    S := StringReplace(S, '/', '\', [rfReplaceAll]);
    {$ENDIF}
    StrPCopy(path, S);
  end;
  Result := path;
end;

procedure TConfig.Default;
begin
  StrCopy(Device, 'COM2');
  Speed := 19200;
  StrCopy(Initialize[0], 'ATZ');
  Initialize[1][0] := #0;
  Initialize[2][0] := #0;
  StrCopy(Answer, 'ATA');
  StrCopy(Dial, 'ATDT%s');
  StrCopy(Hangup, 'v~^~+++~~ATH');
  StrCopy(OffHook, 'ATM0H1');
  LockSpeed := 1;
  StripDashes := 0;
  ManualAnswer := 1;
  StrCopy(FaxMessage, 'FAX');
  FaxCommand[0] := #0;
  StrCopy(SystemName, 'LoraBBS Test System');
  StrCopy(SysopName, 'LoraBBS Tester');
  StrCopy(Location, 'Nowhere');
  StrCopy(Phone, '-Unpublished-');
  StrCopy(NodelistFlags, 'CM,XA');
  DialTimeout := 45;
  CarrierDropTimeout := 1;
  LoginType := 0;
  NewUserLevel := 10;
  NewUserFlags := 0;
  NewUserDenyFlags := 0;
  NewUserLimits[0] := #0;
  UseAnsi := YES_;
  AskAlias := REQUIRED_;
  AskCompanyName := YES_;
  AskAddress := YES_;
  AskCity := REQUIRED_;
  AskPhoneNumber := YES_;
  AskGender := REQUIRED_;

  StrCopy(SystemPath, '.' + PathDelim);
  StrCopy(UserFile, 'users');
  StrCopy(NormalInbound, 'inbound' + PathDelim);
  StrCopy(KnownInbound, 'inbound' + PathDelim);
  StrCopy(ProtectedInbound, 'inbound' + PathDelim);
  StrCopy(Outbound, '.' + PathDelim + 'outbound' + PathDelim);
  StrCopy(SchedulerFile, 'events');
  StrCopy(NodelistPath, 'nodes' + PathDelim);
  StrCopy(UsersHomePath, 'home' + PathDelim);
  StrCopy(MenuPath, 'menu' + PathDelim);
  StrCopy(LanguageFile, 'language');
  StrCopy(TextFiles, 'misc' + PathDelim);
  StrCopy(NewAreasPath, '.' + PathDelim);
  StrCopy(TempPath, 'temp' + PathDelim);

  StrCopy(MainMenu, 'MAIN');
  StrCopy(HostName, 'unknown.host');
  StrCopy(NewsServer, 'news');
  StrCopy(MailServer, 'mail');
  StrCopy(PopServer, 'mail');
  StrCopy(LogFile, 'lora%u.log');
  FakeNet := 0;
  MailStorage := ST_SQUISH;
  NetMailStorage := ST_SQUISH;
  BadStorage := ST_SQUISH;
  DupeStorage := ST_SQUISH;
  StrCopy(MailPath, 'email');
  StrCopy(NetMailPath, 'netmail');
  StrCopy(BadPath, 'bad_msgs');
  StrCopy(DupePath, 'dupes');
  TelnetPort := 23;
  FtpPort := 21;
  WebPort := 80;
  SMTPPort := 25;
  POP3Port := 109;
  NNTPPort := 119;
  WaZoo := 1;
  EMSI := 1;
  Janus := 0;
  NewAreasStorage := ST_SQUISH;
  Ansi := 1;
  IEMSI := 1;
  UseSinglePass := 0;
  SeparateNetMail := 1;
  ZModemTelnet := 0;
  StrCopy(OLRPacketName, 'offline');
  TextPasswords := 1;

  MailAddress.Load(SystemPath);
end;

procedure TConfig.New_;
var
  Cfg: CONFIG_REC;
begin
  FillChar(Cfg, SizeOf(CONFIG_REC), 0);
  Struct2Class(Cfg);
end;

procedure TConfig.NewChannel;
begin
  Speed := 19200;
  Initialize[0][0] := #0;
  Initialize[1][0] := #0;
  Initialize[2][0] := #0;
  StrCopy(Answer, 'ATA');
  StrCopy(Dial, 'ATDT%s');
  StrCopy(Hangup, 'v~^~+++~~ATH');
  StrCopy(OffHook, 'ATM0H1');
  LockSpeed := 0;
  StripDashes := 0;
  FaxMessage[0] := #0;
  FaxCommand[0] := #0;
  StrCopy(Ring, 'RING');
  ManualAnswer := 1;
  LimitedHours := 0;
  StartTime := 0;
  EndTime := 0;
  CallIf[0] := #0;
  DontCallIf[0] := #0;
end;

procedure TConfig.Struct2Class(var Cfg: CONFIG_REC);
begin
  StrCopy(Device, Cfg.Device);
  Speed := Cfg.Speed;
  StrCopy(Initialize[0], Cfg.Initialize[0]);
  StrCopy(Initialize[1], Cfg.Initialize[1]);
  StrCopy(Initialize[2], Cfg.Initialize[2]);
  StrCopy(Answer, Cfg.Answer);
  StrCopy(Dial, Cfg.Dial);
  StrCopy(Hangup, Cfg.Hangup);
  StrCopy(OffHook, Cfg.OffHook);
  LockSpeed := Cfg.LockSpeed;
  StripDashes := Cfg.StripDashes;
  StrCopy(FaxMessage, Cfg.FaxMessage);
  StrCopy(FaxCommand, Cfg.FaxCommand);
  DialTimeout := Cfg.DialTimeout;
  CarrierDropTimeout := Cfg.CarrierDropTimeout;
  StrCopy(SystemName, Cfg.SystemName);
  StrCopy(SysopName, Cfg.SysopName);
  StrCopy(Location, Cfg.Location);
  StrCopy(Phone, Cfg.Phone);
  StrCopy(NodelistFlags, Cfg.NodelistFlags);
  LoginType := Cfg.LoginType;
  NewUserLevel := Cfg.NewUserLevel;
  NewUserFlags := Cfg.NewUserFlags;
  NewUserDenyFlags := Cfg.NewUserDenyFlags;
  StrCopy(NewUserLimits, Cfg.NewUserLimits);
  UseAnsi := Cfg.UseAnsi;
  AskAlias := Cfg.AskAlias;
  AskCompanyName := Cfg.AskCompanyName;
  AskAddress := Cfg.AskAddress;
  AskCity := Cfg.AskCity;
  AskPhoneNumber := Cfg.AskPhoneNumber;
  AskGender := Cfg.AskGender;
  StrCopy(SystemPath, Cfg.SystemPath);  FixPath(SystemPath);
  StrCopy(UserFile, Cfg.UserFile);      AdjustPath(UserFile);
  StrCopy(NormalInbound, Cfg.NormalInbound);  FixPath(NormalInbound);
  StrCopy(KnownInbound, Cfg.KnownInbound);    FixPath(KnownInbound);
  StrCopy(ProtectedInbound, Cfg.ProtectedInbound);  FixPath(ProtectedInbound);
  StrCopy(Outbound, Cfg.Outbound);      FixPath(Outbound);
  StrCopy(SchedulerFile, Cfg.SchedulerFile);  AdjustPath(SchedulerFile);
  StrCopy(NodelistPath, Cfg.NodelistPath);    FixPath(NodelistPath);
  StrCopy(UsersHomePath, Cfg.UsersHomePath);  FixPath(UsersHomePath);
  StrCopy(MenuPath, Cfg.MenuPath);      FixPath(MenuPath);
  StrCopy(LanguageFile, Cfg.LanguageFile);  AdjustPath(LanguageFile);
  StrCopy(TextFiles, Cfg.TextFiles);    FixPath(TextFiles);
  StrCopy(MainMenu, Cfg.MainMenu);
  StrCopy(HostName, Cfg.HostName);
  StrCopy(NewsServer, Cfg.NewsServer);
  StrCopy(MailServer, Cfg.MailServer);
  StrCopy(PopServer, Cfg.PopServer);
  StrCopy(LogFile, Cfg.LogFile);        AdjustPath(LogFile);
  FakeNet := Cfg.FakeNet;
  MailStorage := Cfg.MailStorage;
  NetMailStorage := Cfg.NetMailStorage;
  BadStorage := Cfg.BadStorage;
  DupeStorage := Cfg.DupeStorage;
  StrCopy(MailPath, Cfg.MailPath);
  if MailStorage = ST_FIDO then FixPath(MailPath) else AdjustPath(MailPath);
  StrCopy(NetMailPath, Cfg.NetMailPath);
  if NetMailStorage = ST_FIDO then FixPath(NetMailPath) else AdjustPath(NetMailPath);
  StrCopy(BadPath, Cfg.BadPath);
  if BadStorage = ST_FIDO then FixPath(BadPath) else AdjustPath(BadPath);
  StrCopy(DupePath, Cfg.DupePath);
  if DupeStorage = ST_FIDO then FixPath(DupePath) else AdjustPath(DupePath);
  TelnetServer := Cfg.TelnetServer;
  TelnetPort := Cfg.TelnetPort;
  FtpServer := Cfg.FtpServer;
  FtpPort := Cfg.FtpPort;
  WebServer := Cfg.WebServer;
  WebPort := Cfg.WebPort;
  SMTPServer := Cfg.SMTPServer;
  SMTPPort := Cfg.SMTPPort;
  POP3Server := Cfg.POP3Server;
  POP3Port := Cfg.POP3Port;
  NNTPServer := Cfg.NNTPServer;
  NNTPPort := Cfg.NNTPPort;
  WaZoo := Cfg.WaZoo;
  EMSI := Cfg.EMSI;
  Janus := Cfg.Janus;
  NewAreasStorage := Cfg.NewAreasStorage;
  StrCopy(NewAreasPath, Cfg.NewAreasPath);  FixPath(NewAreasPath);
  NewAreasLevel := Cfg.NewAreasLevel;
  NewAreasFlags := Cfg.NewAreasFlags;
  NewAreasDenyFlags := Cfg.NewAreasDenyFlags;
  NewAreasWriteLevel := Cfg.NewAreasWriteLevel;
  NewAreasWriteFlags := Cfg.NewAreasWriteFlags;
  NewAreasDenyWriteFlags := Cfg.NewAreasDenyWriteFlags;
  Ansi := Cfg.Ansi;
  IEMSI := Cfg.IEMSI;
  ImportEmpty := Cfg.ImportEmpty;
  ReplaceTear := Cfg.ReplaceTear;
  StrCopy(TearLine, Cfg.TearLine);
  ForceIntl := Cfg.ForceIntl;
  Secure := Cfg.Secure;
  KeepNetMail := Cfg.KeepNetMail;
  TrackNetMail := Cfg.TrackNetMail;
  StrCopy(MailOnly, Cfg.MailOnly);
  StrCopy(EnterBBS, Cfg.EnterBBS);
  StrCopy(ImportCmd, Cfg.ImportCmd);
  StrCopy(ExportCmd, Cfg.ExportCmd);
  StrCopy(PackCmd, Cfg.PackCmd);
  StrCopy(SinglePassCmd, Cfg.SinglePassCmd);
  UseSinglePass := Cfg.UseSinglePass;
  SeparateNetMail := Cfg.SeparateNetMail;
  StrCopy(AreasBBS, Cfg.AreasBBS);  AdjustPath(AreasBBS);
  UseAreasBBS := Cfg.UseAreasBBS;
  UpdateAreasBBS := Cfg.UpdateAreasBBS;
  StrCopy(AfterCallerCmd, Cfg.AfterCallerCmd);
  StrCopy(AfterMailCmd, Cfg.AfterMailCmd);
  ZModemTelnet := Cfg.ZModemTelnet;
  EnablePPP := Cfg.EnablePPP;
  PPPTimeLimit := Cfg.PPPTimeLimit;
  StrCopy(PPPCmd, Cfg.PPPCmd);
  StrCopy(TempPath, Cfg.TempPath);  FixPath(TempPath);
  StrCopy(OLRPacketName, Cfg.OLRPacketName);
  OLRMaxMessages := Cfg.OLRMaxMessages;
  ExternalFax := Cfg.ExternalFax;
  FaxFormat := Cfg.FaxFormat;
  StrCopy(FaxPath, Cfg.FaxPath);  FixPath(FaxPath);
  StrCopy(AfterFaxCmd, Cfg.AfterFaxCmd);
  StrCopy(FaxAlertNodes, Cfg.FaxAlertNodes);
  StrCopy(FaxAlertUser, Cfg.FaxAlertUser);
  ReloadLog := Cfg.ReloadLog;
  MakeProcessLog := Cfg.MakeProcessLog;
  RetriveMaxMessages := Cfg.RetriveMaxMessages;
  UseAvatar := Cfg.UseAvatar;
  UseColor := Cfg.UseColor;
  UseFullScreenEditor := Cfg.UseFullScreenEditor;
  UseHotKey := Cfg.UseHotKey;
  UseIBMChars := Cfg.UseIBMChars;
  AskLines := Cfg.AskLines;
  UsePause := Cfg.UsePause;
  UseScreenClear := Cfg.UseScreenClear;
  AskBirthDate := Cfg.AskBirthDate;
  AskMailCheck := Cfg.AskMailCheck;
  AskFileCheck := Cfg.AskFileCheck;
  ExternalEditor := Cfg.ExternalEditor;
  StrCopy(EditorCmd, Cfg.EditorCmd);
  StrCopy(HudsonPath, Cfg.HudsonPath);
  StrCopy(GoldPath, Cfg.GoldPath);
  BadBoard := Cfg.BadBoard;
  DupeBoard := Cfg.DupeBoard;
  MailBoard := Cfg.MailBoard;
  NetMailBoard := Cfg.NetMailBoard;
  UseFullScreenReader := Cfg.UseFullScreenReader;
  UseFullScreenLists := Cfg.UseFullScreenLists;
  UseFullScreenAreaLists := Cfg.UseFullScreenAreaLists;
  AreafixActive := Cfg.AreafixActive;
  AllowRescan := Cfg.AllowRescan;
  CheckZones := Cfg.CheckZones;
  RaidActive := Cfg.RaidActive;
  StrCopy(AreafixNames, Cfg.AreafixNames);
  StrCopy(AreafixHelp, Cfg.AreafixHelp);
  StrCopy(RaidNames, Cfg.RaidNames);
  StrCopy(RaidHelp, Cfg.RaidHelp);
  StrCopy(NewTicPath, Cfg.NewTicPath);  FixPath(NewTicPath);
  TextPasswords := Cfg.TextPasswords;
end;

function TConfig.Load(pszConfig: PChar; pszChannel: PChar): Word;
begin
  if pszConfig <> nil then
    StrCopy(ConfigFile, pszConfig);
  if pszChannel <> nil then
    StrCopy(ChannelFile, pszChannel);
  Result := Reload;
end;

function TConfig.Reload: Word;
var
  fs: TFileStream;
  Cfg: CONFIG_REC;
  Ch: CHANNEL;
begin
  Result := 0;

  { Read main config }
  if FileExists(StrPas(ConfigFile)) then
  begin
    try
      fs := TFileStream.Create(StrPas(ConfigFile), fmOpenRead or fmShareDenyNone);
      try
        FillChar(Cfg, SizeOf(CONFIG_REC), 0);
        if fs.Read(Cfg, SizeOf(CONFIG_REC)) = SizeOf(CONFIG_REC) then
        begin
          Struct2Class(Cfg);
          Result := 1;
        end;
      finally
        fs.Free;
      end;
    except
    end;
  end;

  { Read channel config }
  if FileExists(StrPas(ChannelFile)) then
  begin
    try
      fs := TFileStream.Create(StrPas(ChannelFile), fmOpenRead or fmShareDenyNone);
      try
        while fs.Read(Ch, SizeOf(CHANNEL)) = SizeOf(CHANNEL) do
        begin
          if Ch.TaskNumber = TaskNumber then
          begin
            StrCopy(Device, Ch.Device);
            Speed := Ch.Speed;
            StrCopy(Initialize[0], Ch.Initialize[0]);
            StrCopy(Initialize[1], Ch.Initialize[1]);
            StrCopy(Initialize[2], Ch.Initialize[2]);
            StrCopy(Answer, Ch.Answer);
            StrCopy(Dial, Ch.Dial);
            StrCopy(Hangup, Ch.Hangup);
            StrCopy(OffHook, Ch.OffHook);
            LockSpeed := Ch.LockSpeed;
            StripDashes := Ch.StripDashes;
            StrCopy(FaxMessage, Ch.FaxMessage);
            StrCopy(FaxCommand, Ch.FaxCommand);
            DialTimeout := Ch.DialTimeout;
            CarrierDropTimeout := Ch.CarrierDropTimeout;
            StrCopy(SchedulerFile, Ch.SchedulerFile);
            StrCopy(MainMenu, Ch.MainMenu);
            StrCopy(Ring, Ch.Ring);
            ManualAnswer := Ch.ManualAnswer;
            LimitedHours := Ch.LimitedHours;
            StartTime := Ch.StartTime;
            EndTime := Ch.EndTime;
            StrCopy(CallIf, Ch.CallIf);
            StrCopy(DontCallIf, Ch.DontCallIf);
            Break;
          end;
        end;
      finally
        fs.Free;
      end;
    except
    end;
  end;

  MailAddress.Load(SystemPath);
end;

function TConfig.Save(pszConfig: PChar; pszChannel: PChar): Word;
var
  fs: TFileStream;
  Cfg: CONFIG_REC;
  Ch: CHANNEL;
  CfgName, ChName: String;
  Found: Boolean;
begin
  Result := 0;

  if pszConfig <> nil then
    CfgName := StrPas(pszConfig)
  else
    CfgName := StrPas(ConfigFile);
  if pszChannel <> nil then
    ChName := StrPas(pszChannel)
  else
    ChName := StrPas(ChannelFile);

  { Write main config }
  try
    fs := TFileStream.Create(CfgName, fmCreate);
    try
      FillChar(Cfg, SizeOf(CONFIG_REC), 0);
      Result := 1;

      Cfg.Version_ := CONFIG_REC_VERSION;
      Cfg.Speed := Speed;
      StrCopy(Cfg.Device, Device);
      StrCopy(Cfg.Initialize[0], Initialize[0]);
      StrCopy(Cfg.Initialize[1], Initialize[1]);
      StrCopy(Cfg.Initialize[2], Initialize[2]);
      StrCopy(Cfg.Answer, Answer);
      StrCopy(Cfg.Dial, Dial);
      StrCopy(Cfg.Hangup, Hangup);
      StrCopy(Cfg.OffHook, OffHook);
      Cfg.LockSpeed := LockSpeed;
      Cfg.StripDashes := StripDashes;
      StrCopy(Cfg.FaxMessage, FaxMessage);
      StrCopy(Cfg.FaxCommand, FaxCommand);
      Cfg.DialTimeout := DialTimeout;
      Cfg.CarrierDropTimeout := CarrierDropTimeout;
      StrCopy(Cfg.SystemName, SystemName);
      StrCopy(Cfg.SysopName, SysopName);
      StrCopy(Cfg.Location, Location);
      StrCopy(Cfg.Phone, Phone);
      StrCopy(Cfg.NodelistFlags, NodelistFlags);
      Cfg.LoginType := LoginType;
      Cfg.NewUserLevel := NewUserLevel;
      Cfg.NewUserFlags := NewUserFlags;
      Cfg.NewUserDenyFlags := NewUserDenyFlags;
      StrCopy(Cfg.NewUserLimits, NewUserLimits);
      Cfg.UseAnsi := UseAnsi;
      Cfg.AskAlias := AskAlias;
      Cfg.AskCompanyName := AskCompanyName;
      Cfg.AskAddress := AskAddress;
      Cfg.AskCity := AskCity;
      Cfg.AskPhoneNumber := AskPhoneNumber;
      Cfg.AskGender := AskGender;
      StrCopy(Cfg.SystemPath, SystemPath);
      StrCopy(Cfg.UserFile, UserFile);
      StrCopy(Cfg.NormalInbound, NormalInbound);
      StrCopy(Cfg.KnownInbound, KnownInbound);
      StrCopy(Cfg.ProtectedInbound, ProtectedInbound);
      StrCopy(Cfg.Outbound, Outbound);
      StrCopy(Cfg.SchedulerFile, SchedulerFile);
      StrCopy(Cfg.NodelistPath, NodelistPath);
      StrCopy(Cfg.UsersHomePath, UsersHomePath);
      StrCopy(Cfg.MenuPath, MenuPath);
      StrCopy(Cfg.LanguageFile, LanguageFile);
      StrCopy(Cfg.TextFiles, TextFiles);
      StrCopy(Cfg.MainMenu, MainMenu);
      StrCopy(Cfg.HostName, HostName);
      StrCopy(Cfg.NewsServer, NewsServer);
      StrCopy(Cfg.MailServer, MailServer);
      StrCopy(Cfg.PopServer, PopServer);
      StrCopy(Cfg.LogFile, LogFile);
      Cfg.FakeNet := FakeNet;
      Cfg.MailStorage := MailStorage;
      Cfg.NetMailStorage := NetMailStorage;
      Cfg.BadStorage := BadStorage;
      Cfg.DupeStorage := DupeStorage;
      StrCopy(Cfg.MailPath, MailPath);
      StrCopy(Cfg.NetMailPath, NetMailPath);
      StrCopy(Cfg.BadPath, BadPath);
      StrCopy(Cfg.DupePath, DupePath);
      Cfg.TelnetServer := TelnetServer;
      Cfg.TelnetPort := TelnetPort;
      Cfg.FtpServer := FtpServer;
      Cfg.FtpPort := FtpPort;
      Cfg.WebServer := WebServer;
      Cfg.WebPort := WebPort;
      Cfg.SMTPServer := SMTPServer;
      Cfg.SMTPPort := SMTPPort;
      Cfg.POP3Server := POP3Server;
      Cfg.POP3Port := POP3Port;
      Cfg.NNTPServer := NNTPServer;
      Cfg.NNTPPort := NNTPPort;
      Cfg.WaZoo := WaZoo;
      Cfg.EMSI := EMSI;
      Cfg.Janus := Janus;
      Cfg.NewAreasStorage := NewAreasStorage;
      StrCopy(Cfg.NewAreasPath, NewAreasPath);
      Cfg.NewAreasLevel := NewAreasLevel;
      Cfg.NewAreasFlags := NewAreasFlags;
      Cfg.NewAreasDenyFlags := NewAreasDenyFlags;
      Cfg.NewAreasWriteLevel := NewAreasWriteLevel;
      Cfg.NewAreasWriteFlags := NewAreasWriteFlags;
      Cfg.NewAreasDenyWriteFlags := NewAreasDenyWriteFlags;
      Cfg.Ansi := Ansi;
      Cfg.IEMSI := IEMSI;
      Cfg.ImportEmpty := ImportEmpty;
      Cfg.ReplaceTear := ReplaceTear;
      StrCopy(Cfg.TearLine, TearLine);
      Cfg.ForceIntl := ForceIntl;
      Cfg.Secure := Secure;
      Cfg.KeepNetMail := KeepNetMail;
      Cfg.TrackNetMail := TrackNetMail;
      StrCopy(Cfg.MailOnly, MailOnly);
      StrCopy(Cfg.EnterBBS, EnterBBS);
      StrCopy(Cfg.ImportCmd, ImportCmd);
      StrCopy(Cfg.ExportCmd, ExportCmd);
      StrCopy(Cfg.PackCmd, PackCmd);
      StrCopy(Cfg.SinglePassCmd, SinglePassCmd);
      Cfg.UseSinglePass := UseSinglePass;
      Cfg.SeparateNetMail := SeparateNetMail;
      StrCopy(Cfg.AreasBBS, AreasBBS);
      Cfg.UseAreasBBS := UseAreasBBS;
      Cfg.UpdateAreasBBS := UpdateAreasBBS;
      StrCopy(Cfg.AfterCallerCmd, AfterCallerCmd);
      StrCopy(Cfg.AfterMailCmd, AfterMailCmd);
      Cfg.ZModemTelnet := ZModemTelnet;
      Cfg.EnablePPP := EnablePPP;
      Cfg.PPPTimeLimit := PPPTimeLimit;
      StrCopy(Cfg.PPPCmd, PPPCmd);
      StrCopy(Cfg.TempPath, TempPath);
      StrCopy(Cfg.OLRPacketName, OLRPacketName);
      Cfg.OLRMaxMessages := OLRMaxMessages;
      Cfg.ExternalFax := ExternalFax;
      Cfg.FaxFormat := FaxFormat;
      StrCopy(Cfg.FaxPath, FaxPath);
      StrCopy(Cfg.AfterFaxCmd, AfterFaxCmd);
      StrCopy(Cfg.FaxAlertNodes, FaxAlertNodes);
      StrCopy(Cfg.FaxAlertUser, FaxAlertUser);
      Cfg.ReloadLog := ReloadLog;
      Cfg.MakeProcessLog := MakeProcessLog;
      Cfg.RetriveMaxMessages := RetriveMaxMessages;
      Cfg.UseAvatar := UseAvatar;
      Cfg.UseColor := UseColor;
      Cfg.UseFullScreenEditor := UseFullScreenEditor;
      Cfg.UseHotKey := UseHotKey;
      Cfg.UseIBMChars := UseIBMChars;
      Cfg.AskLines := AskLines;
      Cfg.UsePause := UsePause;
      Cfg.UseScreenClear := UseScreenClear;
      Cfg.AskBirthDate := AskBirthDate;
      Cfg.AskMailCheck := AskMailCheck;
      Cfg.AskFileCheck := AskFileCheck;
      Cfg.ExternalEditor := ExternalEditor;
      StrCopy(Cfg.EditorCmd, EditorCmd);
      StrCopy(Cfg.HudsonPath, HudsonPath);
      StrCopy(Cfg.GoldPath, GoldPath);
      Cfg.BadBoard := BadBoard;
      Cfg.DupeBoard := DupeBoard;
      Cfg.MailBoard := MailBoard;
      Cfg.NetMailBoard := NetMailBoard;
      Cfg.UseFullScreenReader := UseFullScreenReader;
      Cfg.UseFullScreenLists := UseFullScreenLists;
      Cfg.UseFullScreenAreaLists := UseFullScreenAreaLists;
      Cfg.AreafixActive := AreafixActive;
      Cfg.AllowRescan := AllowRescan;
      Cfg.CheckZones := CheckZones;
      Cfg.RaidActive := RaidActive;
      StrCopy(Cfg.AreafixNames, AreafixNames);
      StrCopy(Cfg.AreafixHelp, AreafixHelp);
      StrCopy(Cfg.RaidNames, RaidNames);
      StrCopy(Cfg.RaidHelp, RaidHelp);
      StrCopy(Cfg.NewTicPath, NewTicPath);
      Cfg.TextPasswords := TextPasswords;

      fs.Write(Cfg, SizeOf(CONFIG_REC));
    finally
      fs.Free;
    end;
  except
    Result := 0;
  end;

  { Write channel config }
  try
    if FileExists(ChName) then
      fs := TFileStream.Create(ChName, fmOpenReadWrite or fmShareDenyNone)
    else
      fs := TFileStream.Create(ChName, fmCreate);
    try
      Found := False;
      while fs.Read(Ch, SizeOf(CHANNEL)) = SizeOf(CHANNEL) do
      begin
        if Ch.TaskNumber = TaskNumber then
        begin
          FillChar(Ch, SizeOf(CHANNEL), 0);
          Found := True;

          Ch.TaskNumber := TaskNumber;
          StrCopy(Ch.Device, Device);
          Ch.Speed := Speed;
          StrCopy(Ch.Initialize[0], Initialize[0]);
          StrCopy(Ch.Initialize[1], Initialize[1]);
          StrCopy(Ch.Initialize[2], Initialize[2]);
          StrCopy(Ch.Answer, Answer);
          StrCopy(Ch.Dial, Dial);
          StrCopy(Ch.Hangup, Hangup);
          StrCopy(Ch.OffHook, OffHook);
          Ch.LockSpeed := LockSpeed;
          Ch.StripDashes := StripDashes;
          StrCopy(Ch.FaxMessage, FaxMessage);
          StrCopy(Ch.FaxCommand, FaxCommand);
          Ch.DialTimeout := DialTimeout;
          Ch.CarrierDropTimeout := CarrierDropTimeout;
          StrCopy(Ch.SchedulerFile, SchedulerFile);
          StrCopy(Ch.MainMenu, MainMenu);
          StrCopy(Ch.Ring, Ring);
          Ch.ManualAnswer := ManualAnswer;
          Ch.LimitedHours := LimitedHours;
          Ch.StartTime := StartTime;
          Ch.EndTime := EndTime;
          StrCopy(Ch.CallIf, CallIf);
          StrCopy(Ch.DontCallIf, DontCallIf);

          fs.Seek(fs.Position - SizeOf(CHANNEL), soFromBeginning);
          fs.Write(Ch, SizeOf(CHANNEL));
          Break;
        end;
      end;

      if not Found then
      begin
        FillChar(Ch, SizeOf(CHANNEL), 0);
        Ch.TaskNumber := TaskNumber;
        StrCopy(Ch.Device, Device);
        Ch.Speed := Speed;
        StrCopy(Ch.Initialize[0], Initialize[0]);
        StrCopy(Ch.Initialize[1], Initialize[1]);
        StrCopy(Ch.Initialize[2], Initialize[2]);
        StrCopy(Ch.Answer, Answer);
        StrCopy(Ch.Dial, Dial);
        StrCopy(Ch.Hangup, Hangup);
        StrCopy(Ch.OffHook, OffHook);
        Ch.LockSpeed := LockSpeed;
        Ch.StripDashes := StripDashes;
        StrCopy(Ch.FaxMessage, FaxMessage);
        StrCopy(Ch.FaxCommand, FaxCommand);
        Ch.DialTimeout := DialTimeout;
        Ch.CarrierDropTimeout := CarrierDropTimeout;
        StrCopy(Ch.SchedulerFile, SchedulerFile);
        StrCopy(Ch.MainMenu, MainMenu);
        StrCopy(Ch.Ring, Ring);
        StrCopy(Ch.CallIf, CallIf);
        StrCopy(Ch.DontCallIf, DontCallIf);

        fs.Seek(0, soFromEnd);
        fs.Write(Ch, SizeOf(CHANNEL));
      end;
    finally
      fs.Free;
    end;
  except
  end;

  if SystemPath[0] <> #0 then
    MailAddress.Save(SystemPath);
end;

end.
