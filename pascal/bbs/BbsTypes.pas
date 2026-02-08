{
  FreePascal BBS type declarations
  Converted from lora.h - class declarations for the BBS library
  All classes are declared here; implementations are in separate units.
}

unit BbsTypes;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect, Defs, ComBase, Tcpip, Log, Config, Language,
  User, MsgData, FileData, Address, Menu, Events, Protocol, MsgBase, FileBase,
  Stats, FTrans;

{ ---- Input attribute flags ---- }
const
  INP_FIELD    = $0001;
  INP_FANCY    = $0002;
  INP_NOCRLF   = $0004;
  INP_PWD      = $0008;
  INP_NOCOLOR  = $0010;
  INP_HOTKEY   = $0020;
  INP_NUMERIC  = $0040;
  INP_NONUMHOT = $0080;

{ ---- Ask flags ---- }
const
  ASK_DEFYES   = $0001;
  ASK_DEFNO    = $0002;
  ASK_HELP     = $0004;

{ ---- Answer results ---- }
const
  ANSWER_YES   = 1;
  ANSWER_NO    = 2;
  ANSWER_HELP  = 3;

{ ---- Remote type ---- }
const
  REMOTE_NONE         = 0;
  REMOTE_USER         = 1;
  REMOTE_MAILER       = 2;
  REMOTE_MAILRECEIVED = 3;
  REMOTE_PPP          = 4;

{ ---- Internet port constants ---- }
const
  FTP_PORT     = 21;
  TELNET_PORT  = 23;
  FINGER_PORT  = 79;
  FTPDATA_PORT = 2048;
  VMODEM_PORT  = 3141;
  IRC_PORT     = 6667;

{ ---- Message range/action/type constants ---- }
const
  RANGE_UNDEFINED = 0;
  RANGE_ALL       = 1;
  RANGE_TAGGED    = 2;
  RANGE_CURRENT   = 3;

  ACTION_UNDEFINED = 0;
  ACTION_READ      = 1;
  ACTION_LIST      = 2;

  TYPE_ALL         = 0;
  TYPE_PERSONAL    = 1;
  TYPE_KEYWORD     = 2;
  TYPE_NEW         = 3;
  TYPE_PERSONALNEW = 4;

{ ---- Mail editor types ---- }
const
  MAIL_LOCAL    = 0;
  MAIL_FIDONET  = 1;
  MAIL_INTERNET = 2;

{ ---- Listings data record ---- }
type
  PListData = ^TListData;
  TListData = packed record
    Key:         array[0..15] of Char;
    ActiveFiles: LongWord;
    ActiveMsgs:  LongWord;
    Display:     array[0..127] of Char;
  end;

{ ---- QWK packet header ---- }
type
  PQWKHDR = ^TQWKHDR;
  TQWKHDR = packed record
    Msgstat:   Byte;
    Msgnum:    array[0..6] of Byte;
    Msgdate:   array[0..7] of Byte;
    Msgtime:   array[0..4] of Byte;
    MsgTo:     array[0..24] of Char;
    MsgFrom:   array[0..24] of Char;
    MsgSubj:   array[0..24] of Char;
    Msgpass:   array[0..11] of Byte;
    Msgrply:   array[0..7] of Byte;
    Msgrecs:   array[0..5] of Byte;
    Msglive:   Byte;
    Msgarealo: Byte;
    Msgareahi: Byte;
    Msgfiller: array[0..2] of Byte;
  end;

{ ---- Forward declarations ---- }
type
  TEmbedded = class;
  TBbsMessage = class;
  TInquire = class;
  TLibrary = class;
  TBbsEMail = class;
  TMailerStatus = class;
  TBbsStatus = class;
  TBbs = class;
  TDetect = class;
  TInternet = class;
  TEditor = class;
  TMsgEditor = class;
  TCommentEditor = class;
  TMailEditor = class;
  TOffline = class;
  TBlueWave = class;
  TQWK = class;
  TAsciiOffline = class;
  TPointOffline = class;
  TListings = class;

{ ======================================================================
  TEmbedded - terminal I/O, display files, embedded scripting
  ====================================================================== }

  TEmbedded = class
  public
    Task:          Word;
    EndRun:        Word;
    Hangup:        Word;
    TimeLimit:     Word;
    StartCall:     LongWord;
    Ansi:          Word;
    Avatar:        Word;
    Color:         Word;
    Rip:           Word;
    HotKey:        Word;
    More:          Word;
    ScreenHeight:  Word;
    Path:          String;
    AltPath:       String;
    CarrierSpeed:  LongWord;
    Com:           TCom;
    Snoop:         TCom;
    UserObj:       TUser;
    LanguageObj:   TLanguage;
    Cfg:           TConfig;
    LogObj:        TLog;
    MsgArea:       TMsgData;
    FileArea:      TFileData;

    constructor Create;
    destructor Destroy; override;

    function  AbortSession: Boolean;
    procedure BufferedPrintf(const Fmt: String; const Args: array of const);
    procedure BufferedPrintfAt(Row, Col: Word; const Fmt: String; const Args: array of const);
    procedure ClrEol;
    function  DisplayFile(const FileName: String): Boolean;
    function  DisplayPrompt(const Str: String; AColor, AHilight: Word; DoUnbuffer: Boolean = False): Boolean;
    function  DisplayString(const Str: String): Boolean;
    function  GetAnswer(Flags: Word): Word;
    function  Getch: Word;
    function  GetString(MaxLen: Word; Attrib: Word = 0): String;
    function  KBHit: Boolean;
    procedure Idle;
    function  Input(MaxLen: Word; Attrib: Word = 0): String;
    function  MoreQuestion(nLine: SmallInt): SmallInt;
    procedure OutString(const Fmt: String; const Args: array of const);
    procedure PressEnter;
    procedure Printf(const Fmt: String; const Args: array of const);
    procedure PrintfAt(Row, Col: Word; const Fmt: String; const Args: array of const);
    procedure Putch(B: Byte);
    procedure RunExternal(const Command: String);
    procedure SetColor(AColor: Word);
    function  TimeRemain(InSeconds: Boolean = False): LongWord;
    procedure UnbufferBytes;

  private
    fp:           TFileStream;
    AnswerFile:   TFileStream;
    LastColor:    Word;
    IsMec:        Word;
    TrasLen:      Word;
    IsDown:       Word;
    Required:     Word;
    LastChar:     SmallInt;
    Stop:         SmallInt;
    StopNested:   SmallInt;
    Nested:       SmallInt;
    Line:         SmallInt;
    Temp:         String;
    Temp2:        String;
    Response:     Char;
    OnExit:       String;
    Position:     PChar;
    LastActivity: LongWord;
    Traslate:     String;
    TrasPtr:      PChar;
    LastTime:     LongInt;

    function  GetNextChar: SmallInt;
    function  OpenFile(const AName: String; const AAccess: String = 'rb'): TFileStream;
    function  PeekNextChar: SmallInt;
    procedure ProcessControl(Control: Byte);
    procedure ProcessControlF;
    procedure ProcessControlO;
    procedure ProcessControlP;
    procedure ProcessControlK;
    procedure ProcessControlW;
    procedure TranslateKeyword;
  end;

{ ======================================================================
  TBbsMessage - message area reading/writing
  (Named TBbsMessage to avoid collision with SysUtils.TMessage)
  ====================================================================== }

  TBbsMessage = class
  public
    ShowKludges: Word;
    Width:       Word;
    Height:      Word;
    More:        Word;
    DoCls:       Word;
    Current:     TMsgData;
    Cfg:         TConfig;
    LogObj:      TLog;
    Embedded:    TEmbedded;
    LanguageObj: TLanguage;
    UserObj:     TUser;
    Msg:         TMsgBase;

    constructor Create(const DataFile: String);
    destructor Destroy; override;

    procedure BriefList;
    procedure BuildDate(const Fmt: String; var Dest: String; Date: Pointer);
    procedure Delete;
    procedure DisplayCurrent;
    procedure DisplayText;
    procedure GetOrigin(Data: TMsgData; var Origin: String);
    procedure OpenArea(const Area: String);
    procedure Read_(Number: LongWord);
    procedure ReadMessages;
    procedure ReadNext;
    procedure ReadNonStop;
    procedure ReadOriginal;
    procedure ReadPrevious;
    procedure ReadReply;
    procedure Reply;
    function  SelectArea(const Area: String): Boolean;
    function  SelectNewArea(const Area: String): Boolean;
    procedure StartMessageQuestion(ulFirst, ulLast: LongWord;
                fNewMessages: Boolean; var ulMsg: LongWord; var fForward: Boolean);
    procedure TitleList;
    procedure Unreceive;
    procedure Write_;

  private
    DataPath: String;
  end;

{ ======================================================================
  TInquire - multi-area message inquiry
  ====================================================================== }

  TInquire = class
  public
    InqType:     Word;
    Action:      Word;
    Range:       Word;
    Stop:        Word;
    ShowKludges: Word;
    Keyword:     String;
    Cfg:         TConfig;
    Embedded:    TEmbedded;
    UserObj:     TUser;
    LanguageObj: TLanguage;
    Current:     TMsgData;
    LogObj:      TLog;

    constructor Create;
    destructor Destroy; override;

    procedure DeleteCurrent;
    procedure DisplayCurrent;
    function  First: Boolean;
    function  Next: Boolean;
    function  Previous: Boolean;
    procedure Query;

  private
    Number: LongWord;
    Msg:    TMsgBase;
    Data:   TMsgData;

    procedure BuildDate(const Fmt: String; var Dest: String; Date: Pointer);
    function  FirstMessage: Boolean;
    function  NextMessage: Boolean;
    function  PreviousMessage: Boolean;
    function  SearchAction: Boolean;
    function  SearchRange: Boolean;
  end;

{ ======================================================================
  TLibrary - file library operations
  ====================================================================== }

  TLibrary = class
  public
    Task:          Word;
    CarrierSpeed:  LongWord;
    Cfg:           TConfig;
    Embedded:      TEmbedded;
    LogObj:        TLog;
    UserObj:       TUser;
    Current:       TFileData;
    Progress:      TProgress;
    LanguageObj:   TLanguage;

    constructor Create(const DataFile: String);
    destructor Destroy; override;

    procedure Download(Files: TObject = nil; AnyLibrary: Boolean = False);
    function  DownloadFile(const AFile, AName: String; ASize: LongWord): Boolean;
    procedure DownloadList;
    procedure ExternalProtocols(Batch: Boolean);
    procedure FileDetails(AFile: TFileBase);
    procedure ListDownloadedFiles;
    procedure ListFiles(Data: TFileBase = nil);
    procedure ListRecentFiles;
    procedure AddTagged;
    procedure ListTagged;
    procedure DeleteTagged;
    procedure DeleteAllTagged;
    procedure RemoveFiles;
    procedure SearchFileName;
    procedure SearchKeyword;
    procedure SearchNewFiles;
    function  SearchRange: Boolean;
    procedure SearchText;
    function  SelectArea(const Area: String): Boolean;
    procedure TypeFile;
    procedure Upload;
    procedure UploadUser(const AUser: String);

  private
    DataPath: String;
    StatsObj: TStatistics;

    function  MoreQuestion(nLine: SmallInt): SmallInt;
    procedure TagListed;
  end;

{ ======================================================================
  TBbsEMail - personal email handling
  (Named TBbsEMail to avoid collision)
  ====================================================================== }

  TBbsEMail = class
  public
    ShowKludges: Word;
    Storage:     Word;
    Width:       Word;
    Height:      Word;
    More:        Word;
    DoCls:       Word;
    BasePath:    String;
    Cfg:         TConfig;
    LogObj:      TLog;
    Embedded:    TEmbedded;
    LanguageObj: TLanguage;
    UserObj:     TUser;
    Msg:         TMsgBase;

    constructor Create;
    destructor Destroy; override;

    procedure BriefList;
    procedure BuildDate(const Fmt: String; var Dest: String; Date: Pointer);
    procedure CheckUnread;
    procedure Delete;
    procedure DisplayCurrent;
    procedure DisplayText;
    procedure Read_(Number: LongWord);
    procedure ReadMessages(Unread: Boolean = False);
    procedure ReadNext;
    procedure ReadNonStop;
    procedure ReadPrevious;
    procedure Reply(ToCurrent: Boolean = False);
    procedure StartMessageQuestion(ulFirst, ulLast: LongWord;
                var ulMsg: LongWord; var fForward: Boolean);
    procedure Write_(MailType: Word; const Argument: String = '');

  end;

{ ======================================================================
  TMailerStatus - mailer session status display (virtual base)
  ====================================================================== }

  TMailerStatus = class
  public
    SystemName:   String;
    SysopName:    String;
    Location:     String;
    Addr:         String;
    Akas:         String;
    Program_:     String;
    InPktFiles:   Word;
    InDataFiles:  Word;
    OutPktFiles:  Word;
    OutDataFiles: Word;
    InPktBytes:   LongWord;
    InDataBytes:  LongWord;
    OutPktBytes:  LongWord;
    OutDataBytes: LongWord;
    Speed:        LongWord;

    constructor Create; virtual;
    destructor Destroy; override;

    procedure Update; virtual;
  end;

{ ======================================================================
  TBbsStatus - status line display (virtual base)
  ====================================================================== }

  TBbsStatus = class
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure Clear; virtual;
    procedure SetLine(ALine: Word; const Text: String; const Args: array of const); virtual;
  end;

{ ======================================================================
  TDetect - terminal detection, EMSI/WaZOO handshake
  ====================================================================== }

  TDetect = class
  public
    Task:           Word;
    Remote:         Word;
    Ansi:           Byte;
    Avatar:         Byte;
    Rip:            Byte;
    FullEd:         Byte;
    MorePrompt:     Byte;
    IBMChars:       Byte;
    HotKeys:        Byte;
    ScreenClear:    Byte;
    MailCheck:      Byte;
    FileCheck:      Byte;
    EMSI:           Word;
    YooHoo:         Word;
    IEMSI:          Word;
    Capabilities:   Word;
    Name:           String;
    RealName:       String;
    City:           String;
    Password_:      String;
    RemoteSystem:   String;
    RemoteSysop:    String;
    RemoteLocation: String;
    RemoteProgram:  String;
    Inbound:        String;
    Speed:          LongWord;
    Addr:           TAddress;
    Com:            TCom;
    EventsObj:      TEvents;
    Cfg:            TConfig;
    LogObj:         TLog;
    Progress:       TProgress;
    MailerStatusObj: TMailerStatus;
    StatusObj:      TBbsStatus;

    constructor Create;
    destructor Destroy; override;

    function  AbortSession: Boolean;
    function  EMSIReceiver: Boolean;
    function  EMSISender: Boolean;
    procedure IEMSIReceiver;
    function  RemoteMailer: Word;
    procedure Terminal;
    function  WaZOOReceiver: Boolean;
    function  WaZOOSender: Boolean;

  private
    ReceiveIEMSI: String;
    ReceiveEMSIBuf: PChar;
    SendIEMSI:    String;
    SendEMSIBuf:  PChar;
    StartCall:    LongWord;
    LastPktName:  LongWord;

    function  CheckEMSIPacket: Boolean;
    procedure ParseEMSIPacket;
    procedure ParseIEMSIPacket;
    function  ReceiveHello: Boolean;
    function  ReceiveEMSIPacket: Boolean;
    function  ReceiveIEMSIPacket: Boolean;
    procedure Receiver;
    procedure Sender;
    function  SendHello: Boolean;
    procedure SendEMSIPacket;
    procedure SendIEMSIPacket;
    function  TimedRead: SmallInt;
  end;

{ ======================================================================
  TInternet - Internet protocol clients (Telnet, FTP, Finger, IRC)
  ====================================================================== }

  TInternet = class
  public
    Cfg:       TConfig;
    Com:       TCom;
    Snoop:     TCom;
    Embedded:  TEmbedded;
    LogObj:    TLog;
    UserObj:   TUser;

    constructor Create;
    destructor Destroy; override;

    procedure Finger(const Server: String = ''; Port: Word = FINGER_PORT);
    procedure FTP(const Server: String = ''; Port: Word = FTP_PORT);
    procedure IRC(const Server: String = ''; const Nick: String = ''; Port: Word = IRC_PORT);
    procedure Telnet_(const Server: String = ''; Port: Word = TELNET_PORT);

  private
    Hash:     Word;
    Binary:   Word;
    DataPort: Word;
    Temp:     String;
    CmdStr:   String;
    Host:     String;
    Buffer:   array[0..2047] of Byte;
    Tcp:      TTcpip;
    DataConn: TTcpip;

    function  GetResponse(var Response: String; MaxLen: Word): Boolean;
    procedure FTP_GET(const AFile, AName: String; DoHash: Boolean);
    procedure FTP_MGET(const AFile: String);
    procedure FTP_PUT(const AFile: String; DoHash, DoBinary: Boolean);
  end;

{ ======================================================================
  TEditor - base text editor (virtual)
  ====================================================================== }

  TEditor = class
  public
    UseFullScreen: Word;
    StartCol:      Word;
    StartRow:      Word;
    Width:         Word;
    Height:        Word;
    Embedded:      TEmbedded;
    LanguageObj:   TLanguage;

    constructor Create; virtual;
    destructor Destroy; override;

    function  AppendText: Boolean; virtual;
    procedure ChangeText; virtual;
    procedure Clear; virtual;
    procedure DeleteLine; virtual;
    procedure DisplayScreen; virtual;
    function  ExternalEditor(const EditorCmd: String): Boolean; virtual;
    function  FullScreen: Boolean; virtual;
    function  InputText: Boolean; virtual;
    function  InsertLines: Boolean; virtual;
    procedure ListText; virtual;
    procedure RetypeLine; virtual;

  protected
    cx, cy:      Word;
    Wrap:        String;
    Buffer:      PChar;
    Cursor_:     PChar;
    ActualLine:  String;
    LineCrc:     array[0..50] of LongWord;
    Text:        TCollection;

    procedure BuildDate(const Fmt: String; var Dest: String; Date: Pointer);
    procedure Display(ALine: Word);
    function  GetFirstChar(Start, ALine: Word): String;
    function  GetString(MaxLen: Word): String;
    procedure GotoXY(x, y: Word);
    procedure MoveCursor(Start: Word);
    procedure SetCursor(Start: Word);
    function  StringReplace_(const Str, Search, Replace: String): String;
    procedure UpdateLine(y: Word; const ALine: String);
  end;

{ ======================================================================
  TMsgEditor - message area editor
  ====================================================================== }

  TMsgEditor = class(TEditor)
  public
    EchoMail:  Word;
    AreaKey:   String;
    AreaTitle: String;
    UserName:  String;
    Addr:      String;
    Origin:    String;
    Cfg:       TConfig;
    LogObj:    TLog;
    Msg:       TMsgBase;

    constructor Create; override;
    destructor Destroy; override;

    procedure DisplayScreen; override;
    procedure Forward;
    procedure InputSubject;
    function  InputTo: Boolean;
    procedure Menu_;
    function  Modify: Boolean;
    procedure QuoteText;
    function  Reply: Boolean;
    procedure Save;
    function  Write_: Boolean;

  private
    To_:     String;
    Subject: String;
    Number:  LongWord;
    Msgn:    LongWord;
  end;

{ ======================================================================
  TCommentEditor - file comment editor
  ====================================================================== }

  TCommentEditor = class(TEditor)
  public
    FileObj: TFileBase;

    constructor Create; override;
    destructor Destroy; override;

    procedure Menu_;
    procedure Save;
    function  Write_: Boolean;
  end;

{ ======================================================================
  TMailEditor - personal mail editor
  ====================================================================== }

  TMailEditor = class(TEditor)
  public
    MailType:   Word;
    Storage:    Word;
    Private_:   Byte;
    BasePath:   String;
    UserName:   String;
    Origin:     String;
    Addr:       String;
    AreaTitle:  String;
    To_:        String;
    ToAddress:  String;
    Subject:    String;
    Cfg:        TConfig;
    LogObj:     TLog;
    Msg:        TMsgBase;

    constructor Create; override;
    destructor Destroy; override;

    procedure DisplayScreen; override;
    procedure Forward;
    function  InputAddress: Boolean;
    function  InputSubject: Boolean;
    function  InputTo: Boolean;
    procedure Menu_;
    function  Modify: Boolean;
    procedure QuoteText;
    function  Reply: Boolean;
    procedure Save;
    function  Write_: Boolean;

  private
    Number: LongWord;
  end;

{ ======================================================================
  TOffline - offline mail reader base class (virtual)
  ====================================================================== }

  TOffline = class
  public
    Area:          Word;
    Id:            String;
    Path:          String;
    Limit:         LongWord;
    CarrierSpeed:  LongWord;
    Current_:      LongWord;
    Total:         LongWord;
    Personal:      LongWord;
    TotalPersonal: LongWord;
    Reply_:        LongWord;
    Cfg:           TConfig;
    LogObj:        TLog;
    Embedded:      TEmbedded;
    UserObj:       TUser;
    LanguageObj:   TLanguage;
    Progress:      TProgress;

    constructor Create; virtual;
    destructor Destroy; override;

    procedure AddConference; virtual;
    procedure AddKludges(AText: TCollection; Data: TMsgData); virtual;
    function  CreatePacket: Boolean; virtual;
    function  Compress(const Packet: String): Boolean; virtual;
    procedure Display; virtual;
    procedure Download(const AFile, AName: String); virtual;
    procedure ManageTagged; virtual;
    function  FetchReply: Boolean; virtual;
    procedure PackArea(var ulLast: LongWord); virtual;
    procedure PackEMail(var ulLast: LongWord); virtual;
    function  Prescan: Boolean; virtual;
    procedure RemoveArea; virtual;
    procedure RestrictDate; virtual;
    procedure Scan(const Key: String; ulLast: LongWord); virtual;
    function  TooOld(Restrict: LongWord; AMsg: TMsgBase): Boolean; virtual;
    procedure Upload; virtual;

  protected
    Work:      String;
    BarWidth:  Word;
    TotalPack: LongWord;
    MsgArea:   TMsgData;
    Msg:       TMsgBase;
  end;

{ ======================================================================
  TBlueWave - BlueWave offline reader
  ====================================================================== }

  TBlueWave = class(TOffline)
  public
    constructor Create; override;
    destructor Destroy; override;

    function  CreatePacket: Boolean; override;
    function  FetchReply: Boolean; override;
    procedure PackArea(var ulLast: LongWord); override;

  private
    { BlueWave format structures - defined in bluewave.h }
  end;

{ ======================================================================
  TQWK - QWK offline reader
  ====================================================================== }

  TQWK = class(TOffline)
  public
    constructor Create; override;
    destructor Destroy; override;

    function  CreatePacket: Boolean; override;
    function  FetchReply: Boolean; override;
    procedure PackArea(var ulLast: LongWord); override;

  private
    TempStr: String;
    Blocks:  LongWord;
    Qwk:     TQWKHDR;
  end;

{ ======================================================================
  TAsciiOffline - ASCII text offline reader
  ====================================================================== }

  TAsciiOffline = class(TOffline)
  public
    constructor Create; override;
    destructor Destroy; override;

    function  CreatePacket: Boolean; override;
    procedure PackArea(var ulLast: LongWord); override;
  end;

{ ======================================================================
  TPointOffline - FidoNet point offline reader
  ====================================================================== }

  TPointOffline = class(TOffline)
  public
    constructor Create; override;
    destructor Destroy; override;

    function  CreatePacket: Boolean; override;
    function  FetchReply: Boolean; override;
    procedure PackArea(var ulLast: LongWord); override;
  end;

{ ======================================================================
  TListings - base class for interactive list displays (virtual)
  ====================================================================== }

  TListings = class
  public
    Embedded:    TEmbedded;
    LogObj:      TLog;
    UserObj:     TUser;
    LanguageObj: TLanguage;

    constructor Create; virtual;
    destructor Destroy; override;

    procedure Begin_; virtual;
    procedure Down; virtual;
    procedure Exit_; virtual;
    procedure DownloadTag; virtual;
    function  DrawScreen: Boolean; virtual;
    procedure PageDown; virtual;
    procedure PageUp; virtual;
    procedure PrintCursor(y: Word); virtual;
    procedure PrintLine; virtual;
    procedure PrintTitles; virtual;
    procedure RemoveCursor(y: Word); virtual;
    function  Run: Boolean; virtual;
    procedure Select; virtual;
    procedure Tag; virtual;
    procedure Up; virtual;

  protected
    y_:       Word;
    RetVal:   Word;
    End_:     Word;
    Found:    Word;
    Redraw:   Word;
    Titles:   Word;
    List:     TCollection;
    Data:     TCollection;
    pld:      PListData;
  end;

{ ======================================================================
  TBbs - main BBS engine
  ====================================================================== }

  TBbs = class
  public
    Task:            Word;
    AutoDetect:      Word;
    TimeLimit:       Word;
    Remote:          Word;
    Local:           Word;
    FancyNames:      Word;
    Logoff:          Word;
    Speed:           LongWord;
    StartCall:       LongWord;
    Com:             TCom;
    Snoop:           TCom;
    LogObj:          TLog;
    EventsObj:       TEvents;
    Cfg:             TConfig;
    Embedded:        TEmbedded;
    Progress:        TProgress;
    MailerStatusObj: TMailerStatus;
    StatusObj:       TBbsStatus;

    constructor Create;
    destructor Destroy; override;

    procedure ExecuteCommand(AMenu: TMenu);
    function  FileExist(const FileName: String): Boolean;
    procedure IEMSILogin;
    function  Login: Boolean;
    procedure Run;

  private
    whStatus:   Word;
    Reload:     Word;
    Name:       String;
    Password_:  String;
    CmdStr:     String;
    MenuName:   String;
    Stack:      TCollection;
    UserObj:    TUser;
    LanguageObj: TLanguage;
    MenuObj:    TMenu;
    MessageObj: TBbsMessage;
    LibraryObj: TLibrary;
    EMailObj:   TBbsEMail;

    procedure CheckBirthday;
    procedure DisableUseronRecord;
    procedure SetBirthDate;
    procedure SetUseronRecord(const AStatus: String);
    procedure ToggleNoDisturb;
  end;

implementation

{ All implementations are in separate units/include files.
  This unit only provides the class declarations. }

end.
