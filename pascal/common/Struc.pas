{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of struc299.h
}

unit Struc;

{$MODE OBJFPC}
{$H+}
{$PACKRECORDS 1}

interface

uses
  Defs;

const
  VERSION_       = '2.99.70';
  VER_MAJOR      = 2;
  VER_MINOR      = 99;
  PRODUCT_ID     = $4E;

  { Index flags }
  IDX_DELETED    = $0001;

  { Message base type IDs }
  ST_JAM         = 0;
  ST_SQUISH      = 1;
  ST_USENET      = 2;
  ST_FIDO        = 3;
  ST_ADEPT       = 4;
  ST_HUDSON      = 5;
  ST_GOLDBASE    = 6;
  ST_PASSTHROUGH = 7;

  { Origin index special values }
  OIDX_DEFAULT   = 0;
  OIDX_RANDOM    = -1;

  { FileBase constants }
  DATA_EXT       = '.dat';
  INDEX_EXT      = '.idx';
  FILE_DELETED   = $8000;
  FILE_OFFLINE   = $4000;
  FILE_UNAPPROVED = $2000;
  FILE_CDROM     = $1000;
  FILEBASE_ID    = $602C789F;

  { Config constants }
  CONFIG_VERSION = 2942;
  NO_            = 0;
  YES_           = 1;
  ASK_           = 2;
  AUTO_          = 2;
  REQUIRED_      = 2;
  PROMPT_        = 3;

  { OS flags for packers }
  OS_DOS         = $0001;
  OS_OS2         = $0002;
  OS_WINDOWS     = $0004;
  OS_LINUX       = $0008;

  { Day-of-week flags }
  DAY_SUNDAY     = $01;
  DAY_MONDAY     = $02;
  DAY_TUESDAY    = $04;
  DAY_WEDNESDAY  = $08;
  DAY_THURSDAY   = $10;
  DAY_FRIDAY     = $20;
  DAY_SATURDAY   = $40;

  MAXCOST        = 7;

type
  { Index file for message and file areas }
  PINDEX = ^INDEX;
  INDEX = packed record
    Key:         array[0..15] of Char;
    Level:       Word;
    AccessFlags: LongWord;
    DenyFlags:   LongWord;
    Position:    LongWord;
    Flags:       Word;
  end;

  { Message areas structure }
  PMESSAGE_REC = ^MESSAGE_REC;
  MESSAGE_REC = packed record
    Size:           Word;
    Display:        array[0..127] of Char;
    Key:            array[0..15] of Char;
    Level:          Word;
    AccessFlags:    LongWord;
    DenyFlags:      LongWord;
    WriteLevel:     Word;
    WriteFlags:     LongWord;
    DenyWriteFlags: LongWord;
    Age:            Byte;
    Storage:        Word;
    Path:           array[0..127] of Char;
    Board:          Word;
    Flags:          Word;
    Group:          Word;
    EchoMail:       Char;
    ShowGlobal:     Char;
    UpdateNews:     Char;
    Offline:        Char;
    MenuName:       array[0..31] of Char;
    Moderator:      array[0..63] of Char;
    Cost:           LongWord;
    DaysOld:        Word;
    RecvDaysOld:    Word;
    MaxMessages:    Word;
    ActiveMsgs:     LongWord;
    NewsGroup:      array[0..127] of Char;
    Highest:        LongWord;
    EchoTag:        array[0..63] of Char;
    OriginIndex:    SmallInt;
    Origin:         array[0..79] of Char;
    HighWaterMark:  LongWord;
    Address:        array[0..47] of Char;
    FirstMessage:   LongWord;
    LastMessage:    LongWord;
    NewsHWM:        LongWord;
  end;

  { EchoMail link structure }
  PECHOLINK = ^ECHOLINK;
  ECHOLINK = packed record
    Free:         Word;
    EchoTag:      LongWord;
    Zone:         Word;
    Net:          Word;
    Node:         Word;
    Point:        Word;
    Domain:       array[0..31] of Char;
    SendOnly:     Byte;
    ReceiveOnly:  Byte;
    PersonalOnly: Byte;
    Passive:      Byte;
    Skip:         Byte;
  end;

  { File areas structure }
  PFILES_REC = ^FILES_REC;
  FILES_REC = packed record
    Size:             Word;
    Display:          array[0..127] of Char;
    Key:              array[0..15] of Char;
    Level:            Word;
    AccessFlags:      LongWord;
    DenyFlags:        LongWord;
    UploadLevel:      Word;
    UploadFlags:      LongWord;
    UploadDenyFlags:  LongWord;
    DownloadLevel:    Word;
    DownloadFlags:    LongWord;
    DownloadDenyFlags: LongWord;
    Age:              Byte;
    Download:         array[0..127] of Char;
    Upload:           array[0..127] of Char;
    CdRom:            Char;
    FreeDownload:     Char;
    ShowGlobal:       Char;
    MenuName:         array[0..31] of Char;
    Moderator:        array[0..63] of Char;
    Cost:             LongWord;
    ActiveFiles:      LongWord;
    UnapprovedFiles:  LongWord;
    EchoTag:          array[0..63] of Char;
    UseFilesBBS:      Byte;
    DlCost:           Byte;
    FileList:         array[0..127] of Char;
  end;

  { FileBase data structure }
  PFILEDATA = ^FILEDATA;
  FILEDATA = packed record
    Id:          LongWord;
    Area:        array[0..31] of Char;
    Name:        array[0..31] of Char;
    Complete:    array[0..127] of Char;
    Description: Word;
    Uploader:    Word;
    Keyword:     array[0..31] of Char;
    Size:        LongWord;
    DlTimes:     LongWord;
    FileDate:    LongWord;
    UploadDate:  LongWord;
    Cost:        LongWord;
    Password:    LongWord;
    Level:       Word;
    AccessFlags: LongWord;
    DenyFlags:   LongWord;
    Flags:       Word;
  end;

  { FileBase index structure }
  PFILEINDEX = ^FILEINDEX;
  FILEINDEX = packed record
    Area:       LongWord;
    Name:       array[0..31] of Char;
    UploadDate: LongWord;
    Offset:     LongWord;
    Flags:      Word;
  end;

  { User index structure }
  PUINDEX = ^UINDEX;
  UINDEX = packed record
    Deleted:     Word;
    NameCrc:     LongWord;
    RealNameCrc: LongWord;
    Position:    LongWord;
  end;

  { User record structure }
  PUSER_REC = ^USER_REC;
  USER_REC = packed record
    Size:           Word;
    Name:           array[0..47] of Char;
    Password:       LongWord;
    RealName:       array[0..47] of Char;
    Company:        array[0..35] of Char;
    Address:        array[0..47] of Char;
    City:           array[0..47] of Char;
    DayPhone:       array[0..25] of Char;
    Ansi:           Char;
    Avatar:         Char;
    Color:          Char;
    HotKey:         Char;
    System_:        Char;
    Sex:            Char;
    FullEd:         Byte;
    FullReader:     Byte;
    NoDisturb:      Byte;
    AccessFailed:   Byte;
    ScreenHeight:   Word;
    ScreenWidth:    Word;
    Level:          Word;
    AccessFlags:    LongWord;
    DenyFlags:      LongWord;
    CreationDate:   LongWord;
    LastCall:       LongWord;
    MailBox:        array[0..31] of Char;
    LimitClass:     array[0..15] of Char;
    TotalCalls:     LongWord;
    TodayTime:      LongWord;
    WeekTime:       LongWord;
    MonthTime:      LongWord;
    YearTime:       LongWord;
    Language:       array[0..15] of Char;
    FtpHost:        array[0..47] of Char;
    FtpName:        array[0..31] of Char;
    FtpPwd:         array[0..31] of Char;
    LastMsgArea:    array[0..15] of Char;
    LastFileArea:   array[0..15] of Char;
    UploadFiles:    Word;
    UploadBytes:    LongWord;
    DownloadFiles:  Word;
    DownloadBytes:  LongWord;
    FilesToday:     Word;
    BytesToday:     LongWord;
    ImportPOP3Mail: Byte;
    UseInetAddress: Byte;
    InetAddress:    array[0..63] of Char;
    Pop3Pwd:        array[0..31] of Char;
    Archiver:       array[0..15] of Char;
    Protocol:       array[0..15] of Char;
    Signature:      array[0..63] of Char;
    FullScreen:     Char;
    IBMChars:       Char;
    MorePrompt:     Char;
    ScreenClear:    Char;
    InUserList:     Char;
    Kludges:        Char;
    MailCheck:      Char;
    NewFileCheck:   Char;
    BirthDay:       Byte;
    BirthMonth:     Byte;
    BirthYear:      Word;
    LastPwdChange:  LongWord;
    PwdLength:      Word;
    PwdText:        array[0..31] of Char;
  end;

  { Tagged message areas }
  PMSGTAGS = ^MSGTAGS;
  MSGTAGS = packed record
    Free:     Byte;
    Tagged:   Byte;
    UserId:   LongWord;
    Area:     array[0..15] of Char;
    LastRead: LongWord;
    OlderMsg: LongWord;
  end;

  { Files tagged for download }
  PFILETAGS = ^FILETAGS;
  FILETAGS = packed record
    Free:        Byte;
    UserId:      LongWord;
    Index_:      Word;
    Area:        array[0..15] of Char;
    Name:        array[0..31] of Char;
    Size:        LongWord;
    Complete:    array[0..127] of Char;
    DeleteAfter: Word;
    CdRom:       Word;
  end;

  { OK file list }
  POKFILE = ^OKFILE;
  OKFILE = packed record
    Size:      Word;
    Name:      array[0..31] of Char;
    Path:      array[0..127] of Char;
    Pwd:       array[0..31] of Char;
    Normal:    Char;
    Known:     Char;
    Protected_: Char;
  end;

  { FidoNet address }
  PMAILADDRESS = ^MAILADDRESS;
  MAILADDRESS = packed record
    Zone:    Word;
    Net:     Word;
    Node:    Word;
    Point:   Word;
    Domain:  array[0..31] of Char;
    FakeNet: Word;
  end;

  { Cost record for TRANSLATION }
  TCOSTENTRY = packed record
    Days:      Word;
    Start:     Word;
    Stop:      Word;
    CostFirst: Word;
    TimeFirst: Word;
    Cost:      Word;
    Time_:     Word;
  end;

  { Main configuration }
  PCONFIG = ^CONFIG;
  CONFIG = packed record
    Size:               Word;
    Version_:           Word;
    Device:             array[0..31] of Char;
    Speed:              LongWord;
    LockSpeed:          Word;
    Initialize:         array[0..2, 0..47] of Char;
    Answer:             array[0..47] of Char;
    Dial:               array[0..47] of Char;
    Hangup:             array[0..47] of Char;
    OffHook:            array[0..47] of Char;
    DialTimeout:        Word;
    CarrierDropTimeout: Word;
    StripDashes:        Word;
    FaxMessage:         array[0..47] of Char;
    FaxCommand:         array[0..63] of Char;
    SystemName:         array[0..63] of Char;
    SysopName:          array[0..47] of Char;
    Location:           array[0..47] of Char;
    Phone:              array[0..31] of Char;
    NodelistFlags:      array[0..63] of Char;
    NewUserLevel:       Word;
    NewUserFlags:       LongWord;
    NewUserDenyFlags:   LongWord;
    NewUserLimits:      array[0..15] of Char;
    LoginType:          Byte;
    UseAnsi:            Byte;
    AskAlias:           Byte;
    AskCompanyName:     Byte;
    AskAddress:         Byte;
    AskCity:            Byte;
    AskPhoneNumber:     Byte;
    AskGender:          Byte;
    LogFile:            array[0..63] of Char;
    SystemPath:         array[0..63] of Char;
    UserFile:           array[0..63] of Char;
    NormalInbound:      array[0..63] of Char;
    KnownInbound:       array[0..63] of Char;
    ProtectedInbound:   array[0..63] of Char;
    Outbound:           array[0..63] of Char;
    NodelistPath:       array[0..63] of Char;
    UsersHomePath:      array[0..63] of Char;
    MenuPath:           array[0..63] of Char;
    LanguageFile:       array[0..63] of Char;
    TextFiles:          array[0..63] of Char;
    SchedulerFile:      array[0..63] of Char;
    MainMenu:           array[0..31] of Char;
    HostName:           array[0..47] of Char;
    NewsServer:         array[0..47] of Char;
    MailServer:         array[0..47] of Char;
    PopServer:          array[0..47] of Char;
    FakeNet:            Word;
    MailStorage:        Word;
    MailPath:           array[0..63] of Char;
    NetMailStorage:     Word;
    NetMailPath:        array[0..63] of Char;
    BadStorage:         Word;
    BadPath:            array[0..63] of Char;
    DupeStorage:        Word;
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
    Hydra:              Word;
    NewAreasStorage:    Word;
    NewAreasPath:       array[0..63] of Char;
    NewAreasLevel:      Word;
    NewAreasFlags:      LongWord;
    NewAreasDenyFlags:  LongWord;
    NewAreasWriteLevel: Word;
    NewAreasWriteFlags: LongWord;
    NewAreasDenyWriteFlags: LongWord;
    Ansi:               Byte;
    IEMSI:              Byte;
    ImportEmpty:        Byte;
    ReplaceTear:        Byte;
    TearLine:           array[0..31] of Char;
    ForceIntl:          Byte;
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
    UseSinglePass:      Byte;
    SeparateNetMail:    Byte;
    AreasBBS:           array[0..63] of Char;
    UseAreasBBS:        Byte;
    UpdateAreasBBS:     Byte;
    AfterCallerCmd:     array[0..63] of Char;
    AfterMailCmd:       array[0..63] of Char;
    Ring:               array[0..31] of Char;
    ZModemTelnet:       Byte;
    EnablePPP:          Byte;
    PPPTimeLimit:       Word;
    PPPCmd:             array[0..63] of Char;
    TempPath:           array[0..63] of Char;
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
  end;

  { Channel configuration }
  PCHANNEL = ^CHANNEL;
  CHANNEL = packed record
    TaskNumber:         Word;
    Device:             array[0..31] of Char;
    Speed:              LongWord;
    LockSpeed:          Word;
    Initialize:         array[0..2, 0..47] of Char;
    Answer:             array[0..47] of Char;
    Dial:               array[0..47] of Char;
    Hangup:             array[0..47] of Char;
    OffHook:            array[0..47] of Char;
    DialTimeout:        Word;
    CarrierDropTimeout: Word;
    StripDashes:        Word;
    FaxMessage:         array[0..47] of Char;
    FaxCommand:         array[0..63] of Char;
    SchedulerFile:      array[0..63] of Char;
    MainMenu:           array[0..31] of Char;
    Ring:               array[0..31] of Char;
    ManualAnswer:       Byte;
    LimitedHours:       Byte;
    StartTime:          Word;
    EndTime:            Word;
    CallIf:             array[0..63] of Char;
    DontCallIf:         array[0..63] of Char;
  end;

  { FidoNet nodes definition }
  PNODES_REC = ^NODES_REC;
  NODES_REC = packed record
    Address:         array[0..63] of Char;
    SystemName:      array[0..63] of Char;
    SysopName:       array[0..47] of Char;
    Location:        array[0..47] of Char;
    Speed:           LongWord;
    MinSpeed:        LongWord;
    Phone:           array[0..47] of Char;
    Flags:           array[0..47] of Char;
    DialCmd:         array[0..31] of Char;
    SessionPwd:      array[0..31] of Char;
    AreaMgrPwd:      array[0..31] of Char;
    OutPktPwd:       array[0..8] of Char;
    InPktPwd:        array[0..8] of Char;
    TicPwd:          array[0..31] of Char;
    RemapMail:       Byte;
    UsePkt22:        Byte;
    CreateNewAreas:  Byte;
    NewAreasFilter:  array[0..127] of Char;
    Packer:          array[0..15] of Char;
    ImportPOP3Mail:  Byte;
    UseInetAddress:  Byte;
    InetAddress:     array[0..63] of Char;
    Pop3Pwd:         array[0..31] of Char;
    Level:           Word;
    AccessFlags:     LongWord;
    DenyFlags:       LongWord;
    TicLevel:        Word;
    TicAccessFlags:  LongWord;
    TicDenyFlags:    LongWord;
    LinkNewEcho:     Byte;
    EchoMaint:       Byte;
    ChangeEchoTag:   Byte;
    NotifyAreafix:   Byte;
    CreateNewTic:    Byte;
    LinkNewTic:      Byte;
    TicMaint:        Byte;
    ChangeTicTag:    Byte;
    NotifyRaid:      Byte;
    MailerAka:       array[0..47] of Char;
    EchoAka:         array[0..47] of Char;
    TicAka:          array[0..47] of Char;
    NewTicFilter:    array[0..127] of Char;
  end;

  { Packer definition }
  PPACKER_REC = ^PACKER_REC;
  PACKER_REC = packed record
    Key:       array[0..15] of Char;
    Display:   array[0..31] of Char;
    PackCmd:   array[0..127] of Char;
    UnpackCmd: array[0..127] of Char;
    Id:        array[0..31] of Char;
    Position:  LongInt;
    OS:        Word;
  end;

  { Event scheduler record }
  PEVENT_REC = ^EVENT_REC;
  EVENT_REC = packed record
    Label_:          array[0..31] of Char;
    Hour:            Byte;
    Minute:          Byte;
    WeekDays:        Word;
    Length_:         Word;
    LastDay:         Word;
    Dynamic:         Byte;
    Force:           Byte;
    MailOnly:        Byte;
    ForceCall:       Byte;
    Address:         array[0..31] of Char;
    SendNormal:      Byte;
    SendCrash:       Byte;
    SendDirect:      Byte;
    SendImmediate:   Byte;
    CallDelay:       Word;
    StartImport:     Byte;
    StartExport:     Byte;
    ExportMail:      Byte;
    ImportNormal:    Byte;
    ImportKnown:     Byte;
    ImportProtected: Byte;
    RouteCmd:        array[0..63] of Char;
    Command:         array[0..127] of Char;
    MaxCalls:        Word;
    MaxConnects:     Word;
    AllowRequests:   Byte;
    MakeRequests:    Byte;
    ProcessTIC:      Byte;
    ClockAdjustment: Byte;
    Completed:       Byte;
    Dummy:           array[0..126] of Byte;
  end;

  { Protocol definition }
  PPROTOCOL_REC = ^PROTOCOL_REC;
  PROTOCOL_REC = packed record
    Size:              Word;
    Key:               array[0..15] of Char;
    Description:       array[0..63] of Char;
    Active:            Byte;
    Batch:             Byte;
    DisablePort:       Byte;
    ChangeToUploadPath: Byte;
    DownloadCmd:       array[0..63] of Char;
    UploadCmd:         array[0..63] of Char;
    LogFileName:       array[0..63] of Char;
    CtlFileName:       array[0..63] of Char;
    DownloadCtlString: array[0..31] of Char;
    UploadCtlString:   array[0..31] of Char;
    DownloadKeyword:   array[0..31] of Char;
    UploadKeyword:     array[0..31] of Char;
    FileNamePos:       Word;
    SizePos:           Word;
    CpsPos:            Word;
  end;

  { Nodelist flags mapping }
  PNODEFLAGS_REC = ^NODEFLAGS_REC;
  NODEFLAGS_REC = packed record
    Size:  Word;
    Flags: array[0..63] of Char;
    Cmd:   array[0..63] of Char;
  end;

  { Translation table }
  PTRANSLATION = ^TRANSLATION;
  TRANSLATION = packed record
    Size:     Word;
    Location: array[0..47] of Char;
    Search:   array[0..31] of Char;
    Traslate: array[0..63] of Char;
    Cost:     array[0..MAXCOST-1] of TCOSTENTRY;
  end;

  { User limits }
  PLIMITS_REC = ^LIMITS_REC;
  LIMITS_REC = packed record
    Size:           Word;
    Key:            array[0..15] of Char;
    Description:    array[0..31] of Char;
    Level:          Word;
    Flags:          LongWord;
    DenyFlags:      LongWord;
    CallTimeLimit:  Word;
    DayTimeLimit:   Word;
    DownloadLimit:  Word;
    DownloadAt2400: Word;
    DownloadAt9600: Word;
    DownloadAt14400: Word;
    DownloadAt28800: Word;
    DownloadAt33600: Word;
    DownloadRatio:  Word;
    RatioStart:     Word;
    DownloadSpeed:  LongWord;
    FreeSpace:      array[0..63] of Char;
  end;

implementation

end.
