{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of language.cpp - TLanguage class
  Manages BBS language/translation files (.LNG format).
  Loads keyword=value pairs for all UI text strings.
  Uses TStringList for file parsing instead of C strtok/malloc.
}

unit Language;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs;

const
  { Language string IDs - matches C++ enum in lora_api.h }
  LNG_LANGUAGE_NAME = 1;
  LNG_YES = 2;
  LNG_NO = 3;
  LNG_NONE = 4;
  LNG_MALE = 5;
  LNG_FEMALE = 6;
  LNG_YESKEY = 7;
  LNG_NOKEY = 8;
  LNG_HELPKEY = 9;
  LNG_MALEKEY = 10;
  LNG_FEMALEKEY = 11;
  LNG_JANUARY = 12;
  LNG_FEBRUARY = 13;
  LNG_MARCH = 14;
  LNG_APRIL = 15;
  LNG_MAY = 16;
  LNG_JUNI = 17;
  LNG_JULY = 18;
  LNG_AUGUST = 19;
  LNG_SEPTEMBER = 20;
  LNG_OCTOBER = 21;
  LNG_NOVEMBER = 22;
  LNG_DECEMBER = 23;
  LNG_PRESSENTER = 24;
  LNG_DEFYESNO = 25;
  LNG_YESDEFNO = 26;
  LNG_DEFYESNOHELP = 27;
  LNG_YESDEFNOHELP = 28;
  LNG_ASKADDRESS = 29;
  LNG_ASKANSI = 30;
  LNG_ASKCITY = 31;
  LNG_ASKCOMPANYNAME = 32;
  LNG_ASKDAYPHONE = 33;
  LNG_ASKPASSWORD = 34;
  LNG_ASKALIAS = 35;
  LNG_ASKSEX = 36;
  LNG_ENTERNAME = 37;
  LNG_ENTERNAMEORNEW = 38;
  LNG_ENTERPASSWORD = 39;
  LNG_INVALIDPASSWORD = 40;
  LNG_HAVETAGGED = 41;
  LNG_DISCONNECT = 42;
  LNG_YOUSURE = 43;
  LNG_USERFROMCITY = 44;
  LNG_MENUERROR = 45;
  LNG_MESSAGEHDR = 46;
  LNG_MESSAGENUMBER = 47;
  LNG_MESSAGENUMBER1 = 48;
  LNG_MESSAGENUMBER2 = 49;
  LNG_MESSAGENUMBER3 = 50;
  LNG_MESSAGEDATE = 51;
  LNG_MESSAGEISREPLY = 52;
  LNG_MESSAGESEEALSO = 53;
  LNG_MESSAGEISBOTH = 54;
  LNG_MESSAGEFLAGS = 55;
  LNG_MESSAGEFROM = 56;
  LNG_MESSAGETO = 57;
  LNG_MESSAGESUBJECT = 58;
  LNG_MESSAGEFILE = 59;
  LNG_MESSAGETEXT = 60;
  LNG_MESSAGEQUOTE = 61;
  LNG_MESSAGEKLUDGE = 62;
  LNG_MESSAGEORIGIN = 63;
  LNG_MESSAGEAREAHEADER = 64;
  LNG_MESSAGEAREASEPARATOR = 65;
  LNG_MESSAGEAREADESCRIPTION1 = 66;
  LNG_MESSAGEAREADESCRIPTION2 = 67;
  LNG_MESSAGEAREACURSOR = 68;
  LNG_MESSAGEAREAKEY = 69;
  LNG_MESSAGEAREALIST = 70;
  LNG_MESSAGEAREAREQUEST = 71;
  LNG_MSGFLAG_RCV = 72;
  LNG_MSGFLAG_SNT = 73;
  LNG_MSGFLAG_PVT = 74;
  LNG_MSGFLAG_CRA = 75;
  LNG_MSGFLAG_KS = 76;
  LNG_MSGFLAG_LOC = 77;
  LNG_MSGFLAG_HLD = 78;
  LNG_MSGFLAG_ATT = 79;
  LNG_MSGFLAG_FRQ = 80;
  LNG_MSGFLAG_TRS = 81;
  LNG_ENDOFMESSAGES = 82;
  LNG_READMENU = 83;
  LNG_ENDREADMENU = 84;
  LNG_NEXTMESSAGE = 85;
  LNG_EXITREADMESSAGE = 86;
  LNG_REREADMESSAGE = 87;
  LNG_PREVIOUSMESSAGE = 88;
  LNG_REPLYMESSAGE = 89;
  LNG_EMAILREPLYMESSAGE = 90;
  LNG_MENUNAME = 91;
  LNG_CONFERENCENOTAVAILABLE = 92;
  LNG_STARTWITHMESSAGE = 93;
  LNG_NEWMESSAGES = 94;
  LNG_TEXTFILES = 95;
  LNG_FORUMNAME = 96;
  LNG_FORUMOPERATOR = 97;
  LNG_FORUMTOPIC = 98;
  LNG_MENUPATH = 99;
  LNG_MOREQUESTION = 100;
  LNG_DELETEMOREQUESTION = 101;
  LNG_NONSTOP = 102;
  LNG_QUIT = 103;
  LNG_CONTINUE = 104;
  LNG_NAMENOTFOUND = 105;
  LNG_FILEAREAREQUEST = 106;
  LNG_FILEAREAHEADER = 107;
  LNG_FILEAREALIST = 108;
  LNG_FILEAREANOTAVAILABLE = 109;
  LNG_FILEAREACURSOR = 110;
  LNG_FILEAREASEPARATOR = 111;
  LNG_FILEAREADESCRIPTION1 = 112;
  LNG_FILEAREADESCRIPTION2 = 113;
  LNG_FILEAREAKEY = 114;
  LNG_FILENOTFOUNDINAREA = 115;
  LNG_FILEDESCRIPTION = 116;
  LNG_FILEDOWNLOADNAME = 117;
  LNG_DOWNLOADFILENAME = 118;
  LNG_NOFILEHERE = 119;
  LNG_DISPLAYWHICHFILE = 120;
  LNG_FILELISTHEADER = 121;
  LNG_FILELISTSEPARATOR = 122;
  LNG_FILELISTDESCRIPTION1 = 123;
  LNG_FILELISTDESCRIPTION2 = 124;
  LNG_FILELISTTAGGED = 125;
  LNG_FILELISTNORMAL = 126;
  LNG_READERFROM = 127;
  LNG_READERTO = 128;
  LNG_READERSUBJECT = 129;
  LNG_READERFILE = 130;
  LNG_CONTINUEASNEW = 131;
  LNG_REENTERPASSWORD = 132;
  LNG_PASSWORDNOMATCH = 133;
  LNG_ASKAVATAR = 134;
  LNG_ASKCOLOR = 135;
  LNG_ASKFULLSCREEN = 136;
  LNG_ASKHOTKEY = 137;
  LNG_ASKIBMCHARS = 138;
  LNG_ASKLINES = 139;
  LNG_ASKPAUSE = 140;
  LNG_ASKSCREENCLEAR = 141;
  LNG_ASKBIRTHDATE = 142;
  LNG_ASKMAILCHECK = 143;
  LNG_ASKFILECHECK = 144;
  LNG_CURRENTPASSWORD = 145;
  LNG_WHYPASSWORD = 146;
  LNG_WRONGPASSWORD = 147;
  LNG_FILEPROTOCOLLIST = 148;
  LNG_FILETAGGEDWARNING = 149;
  LNG_FILENOBYTESWARNING = 150;
  LNG_FILENOTIMEWARNING = 151;
  LNG_FILEBEGINDOWNLOAD = 152;
  LNG_FILEBEGINDOWNLOAD2 = 153;
  LNG_FILETAGGEDHEADER = 154;
  LNG_FILETAGGEDLIST = 155;
  LNG_FILETAGGEDTOTAL = 156;
  LNG_FILEDOWNLOADERROR = 157;
  LNG_FILEDOWNLOADCOMPLETE = 158;
  LNG_FILEBUILDLIST = 159;
  LNG_FILENOTAGGED = 160;
  LNG_FILETAGLISTED = 161;
  LNG_FILELISTTAGCONFIRM = 162;
  LNG_FILELISTMOREQUESTION = 163;
  LNG_FILELISTDELETEMOREQUESTION = 164;
  LNG_FILELISTTAGKEY = 165;
  LNG_FILELISTNOFILESFOUND = 166;
  LNG_FILELISTCOMMENT = 167;
  LNG_FILELISTNOTFOUND = 168;
  LNG_FILENAMETODELETE = 169;
  LNG_FILEDELETED = 170;
  LNG_FILETODETAG = 171;
  LNG_FILEDETAGGED = 172;
  LNG_FILETAGEMPTY = 173;
  LNG_FILETOTAG = 174;
  LNG_FILETAGCONFIRM = 175;
  LNG_FILENOTFOUND = 176;
  LNG_ONLINETITLE = 177;
  LNG_ONLINEHEADER = 178;
  LNG_ONLINEENTRY = 179;
  LNG_MAX_ENTRIES = 180;

type
  TKeyword = record
    Id:   Word;
    Name: String;
  end;

  TLanguage = class
  public
    File_:    String;
    Comment:  String;
    MenuName: String;
    TextFiles: String;
    MenuPath: String;

    Months:   array[0..11] of String;
    Yes:      Char;
    No:       Char;
    Help:     Char;
    Male:     Char;
    Female:   Char;

    constructor Create; virtual;
    destructor Destroy; override;

    procedure Default;
    function  Load(pszFile: PChar): Word;
    function  Text(Id: Word): String;

  private
    Strings: array[0..LNG_MAX_ENTRIES - 1] of String;

    function  CheckKeyword(const Key: String): Word;
    function  ProcessEscapes(const Arg: String): String;
    procedure CopyString(Key: Word; const Arg: String);
  end;

implementation

const
  Keywords: array[0..179] of TKeyword = (
    (Id: LNG_LANGUAGE_NAME; Name: 'LanguageName'),
    (Id: LNG_MENUNAME; Name: 'MenuName'),
    (Id: LNG_TEXTFILES; Name: 'TextFiles'),
    (Id: LNG_MENUPATH; Name: 'MenuPath'),
    (Id: LNG_YES; Name: 'Yes'),
    (Id: LNG_NO; Name: 'No'),
    (Id: LNG_NONE; Name: 'None'),
    (Id: LNG_MALE; Name: 'Male'),
    (Id: LNG_FEMALE; Name: 'Female'),
    (Id: LNG_YESKEY; Name: 'YesKey'),
    (Id: LNG_NOKEY; Name: 'NoKey'),
    (Id: LNG_HELPKEY; Name: 'HelpKey'),
    (Id: LNG_MALEKEY; Name: 'MaleKey'),
    (Id: LNG_FEMALEKEY; Name: 'FemaleKey'),
    (Id: LNG_JANUARY; Name: 'January'),
    (Id: LNG_FEBRUARY; Name: 'February'),
    (Id: LNG_MARCH; Name: 'March'),
    (Id: LNG_APRIL; Name: 'April'),
    (Id: LNG_MAY; Name: 'May'),
    (Id: LNG_JUNI; Name: 'Juni'),
    (Id: LNG_JULY; Name: 'July'),
    (Id: LNG_AUGUST; Name: 'August'),
    (Id: LNG_SEPTEMBER; Name: 'September'),
    (Id: LNG_OCTOBER; Name: 'October'),
    (Id: LNG_NOVEMBER; Name: 'November'),
    (Id: LNG_DECEMBER; Name: 'December'),
    (Id: LNG_MOREQUESTION; Name: 'MoreQuestion'),
    (Id: LNG_DELETEMOREQUESTION; Name: 'DeleteMoreQuestion'),
    (Id: LNG_NONSTOP; Name: 'NonStop'),
    (Id: LNG_QUIT; Name: 'Quit'),
    (Id: LNG_CONTINUE; Name: 'Continue'),
    (Id: LNG_PRESSENTER; Name: 'PressEnter'),
    (Id: LNG_DEFYESNO; Name: 'DefYesNo'),
    (Id: LNG_YESDEFNO; Name: 'YesDefNo'),
    (Id: LNG_DEFYESNOHELP; Name: 'DefYesNoHelp'),
    (Id: LNG_YESDEFNOHELP; Name: 'YesDefNoHelp'),
    (Id: LNG_ENTERNAME; Name: 'EnterName'),
    (Id: LNG_NAMENOTFOUND; Name: 'NameNotFound'),
    (Id: LNG_CONTINUEASNEW; Name: 'ContinueAsNew'),
    (Id: LNG_READERFROM; Name: 'ReaderFrom'),
    (Id: LNG_READERTO; Name: 'ReaderTo'),
    (Id: LNG_READERSUBJECT; Name: 'ReaderSubject'),
    (Id: LNG_READERFILE; Name: 'ReaderFile'),
    (Id: LNG_MESSAGETEXT; Name: 'MessageText'),
    (Id: LNG_MESSAGEQUOTE; Name: 'MessageQuote'),
    (Id: LNG_MESSAGEKLUDGE; Name: 'MessageKludge'),
    (Id: LNG_MESSAGEORIGIN; Name: 'MessageOrigin'),
    (Id: LNG_MESSAGEDATE; Name: 'MessageDate'),
    (Id: LNG_MESSAGEISREPLY; Name: 'MessageIsReply'),
    (Id: LNG_MESSAGESEEALSO; Name: 'MessageSeeAlso'),
    (Id: LNG_MESSAGEISBOTH; Name: 'MessageIsBoth'),
    (Id: LNG_MESSAGEHDR; Name: 'MessageHdr'),
    (Id: LNG_MESSAGENUMBER; Name: 'MessageNumber'),
    (Id: LNG_MESSAGENUMBER1; Name: 'MessageNumber1'),
    (Id: LNG_MESSAGENUMBER2; Name: 'MessageNumber2'),
    (Id: LNG_MESSAGENUMBER3; Name: 'MessageNumber3'),
    (Id: LNG_MESSAGEFLAGS; Name: 'MessageFlags'),
    (Id: LNG_MESSAGEFROM; Name: 'MessageFrom'),
    (Id: LNG_MESSAGETO; Name: 'MessageTo'),
    (Id: LNG_MESSAGESUBJECT; Name: 'MessageSubject'),
    (Id: LNG_MESSAGEFILE; Name: 'MessageFile'),
    (Id: LNG_ASKANSI; Name: 'AskAnsi'),
    (Id: LNG_ASKAVATAR; Name: 'AskAvatar'),
    (Id: LNG_ASKCOLOR; Name: 'AskColor'),
    (Id: LNG_ASKFULLSCREEN; Name: 'AskFullScreen'),
    (Id: LNG_ASKALIAS; Name: 'AskAlias'),
    (Id: LNG_ASKHOTKEY; Name: 'AskHotkey'),
    (Id: LNG_ASKIBMCHARS; Name: 'AskIBMChars'),
    (Id: LNG_ASKLINES; Name: 'AskLines'),
    (Id: LNG_ASKPAUSE; Name: 'AskPause'),
    (Id: LNG_ASKSCREENCLEAR; Name: 'AskScreenClear'),
    (Id: LNG_ASKBIRTHDATE; Name: 'AskBirthDate'),
    (Id: LNG_ASKMAILCHECK; Name: 'AskMailCheck'),
    (Id: LNG_ASKFILECHECK; Name: 'AskFileCheck'),
    (Id: LNG_DISCONNECT; Name: 'Disconnect'),
    (Id: LNG_CURRENTPASSWORD; Name: 'CurrentPassword'),
    (Id: LNG_WHYPASSWORD; Name: 'WhyPassword'),
    (Id: LNG_INVALIDPASSWORD; Name: 'InvalidPassword'),
    (Id: LNG_WRONGPASSWORD; Name: 'WrongPassword'),
    (Id: LNG_MESSAGEAREAREQUEST; Name: 'MessageAreaRequest'),
    (Id: LNG_MESSAGEAREAHEADER; Name: 'MessageAreaHeader'),
    (Id: LNG_MESSAGEAREACURSOR; Name: 'MessageAreaCursor'),
    (Id: LNG_MESSAGEAREAKEY; Name: 'MessageAreaKey'),
    (Id: LNG_MESSAGEAREASEPARATOR; Name: 'MessageAreaSeparator'),
    (Id: LNG_MESSAGEAREADESCRIPTION1; Name: 'MessageAreaDescription1'),
    (Id: LNG_MESSAGEAREADESCRIPTION2; Name: 'MessageAreaDescription2'),
    (Id: LNG_MESSAGEAREALIST; Name: 'MessageAreaList'),
    (Id: LNG_FILEPROTOCOLLIST; Name: 'FileProtocolList'),
    (Id: LNG_FILETAGGEDWARNING; Name: 'FileTaggedWarning'),
    (Id: LNG_FILENOBYTESWARNING; Name: 'FileBytesWarning'),
    (Id: LNG_FILENOTIMEWARNING; Name: 'FileNoTimeWarning'),
    (Id: LNG_FILEBEGINDOWNLOAD; Name: 'FileBeginDownload'),
    (Id: LNG_FILEBEGINDOWNLOAD2; Name: 'FileBeginDownload2'),
    (Id: LNG_FILETAGGEDHEADER; Name: 'FileTaggedHeader'),
    (Id: LNG_FILETAGGEDLIST; Name: 'FileTaggedList'),
    (Id: LNG_FILETAGGEDTOTAL; Name: 'FileTaggedTotal'),
    (Id: LNG_FILEDOWNLOADERROR; Name: 'FileDownloadError'),
    (Id: LNG_FILEDOWNLOADCOMPLETE; Name: 'FileDownloadComplete'),
    (Id: LNG_FILEBUILDLIST; Name: 'FileBuildList'),
    (Id: LNG_FILENOTAGGED; Name: 'FileNoTagged'),
    (Id: LNG_FILETAGLISTED; Name: 'FileTagListed'),
    (Id: LNG_FILELISTTAGCONFIRM; Name: 'FileListTagConfirm'),
    (Id: LNG_FILELISTNOTFOUND; Name: 'FileListNotFound'),
    (Id: LNG_FILELISTHEADER; Name: 'FileListHeader'),
    (Id: LNG_FILELISTSEPARATOR; Name: 'FileListSeparator'),
    (Id: LNG_FILELISTDESCRIPTION1; Name: 'FileListDescription1'),
    (Id: LNG_FILELISTDESCRIPTION2; Name: 'FileListDescription2'),
    (Id: LNG_FILELISTTAGGED; Name: 'FileListTagged'),
    (Id: LNG_FILELISTNORMAL; Name: 'FileListNormal'),
    (Id: LNG_FILELISTMOREQUESTION; Name: 'FileListMoreQuestion'),
    (Id: LNG_FILELISTDELETEMOREQUESTION; Name: 'FileListDeleteMoreQuestion'),
    (Id: LNG_FILELISTTAGKEY; Name: 'FileListTagKey'),
    (Id: LNG_FILELISTNOFILESFOUND; Name: 'FileListNoFilesFound'),
    (Id: LNG_FILELISTCOMMENT; Name: 'FileListComment'),
    (Id: LNG_FILEAREAREQUEST; Name: 'FileAreaRequest'),
    (Id: LNG_FILEAREAHEADER; Name: 'FileAreaHeader'),
    (Id: LNG_FILEAREASEPARATOR; Name: 'FileAreaSeparator'),
    (Id: LNG_FILEAREADESCRIPTION1; Name: 'FileAreaDescription1'),
    (Id: LNG_FILEAREADESCRIPTION2; Name: 'FileAreaDescription2'),
    (Id: LNG_FILEAREACURSOR; Name: 'FileAreaCursor'),
    (Id: LNG_FILEAREAKEY; Name: 'FileAreaKey'),
    (Id: LNG_FILEAREALIST; Name: 'FileAreaList'),
    (Id: LNG_FILEAREANOTAVAILABLE; Name: 'FileAreaNotAvailable'),
    (Id: LNG_FILENAMETODELETE; Name: 'FileNameToDelete'),
    (Id: LNG_FILEDELETED; Name: 'FileDeleted'),
    (Id: LNG_FILETODETAG; Name: 'FileToDetag'),
    (Id: LNG_FILEDETAGGED; Name: 'FileDetagged'),
    (Id: LNG_FILETAGEMPTY; Name: 'FileTagEmpty'),
    (Id: LNG_FILETOTAG; Name: 'FileToTag'),
    (Id: LNG_FILETAGCONFIRM; Name: 'FileTagConfirm'),
    (Id: LNG_FILENOTFOUND; Name: 'FileNotFound'),
    (Id: LNG_REENTERPASSWORD; Name: 'ReenterPassword'),
    (Id: LNG_ONLINETITLE; Name: 'OnlineTitle'),
    (Id: LNG_ONLINEHEADER; Name: 'OnlineHeader'),
    (Id: LNG_ONLINEENTRY; Name: 'OnlineEntry'),
    (Id: LNG_ASKADDRESS; Name: 'AskAddress'),
    (Id: LNG_ASKCITY; Name: 'AskCity'),
    (Id: LNG_ASKCOMPANYNAME; Name: 'AskCompanyName'),
    (Id: LNG_ASKDAYPHONE; Name: 'AskDayPhone'),
    (Id: LNG_ASKPASSWORD; Name: 'AskPassword'),
    (Id: LNG_ASKSEX; Name: 'AskSex'),
    (Id: LNG_ENTERNAMEORNEW; Name: 'EnterNameOrNew'),
    (Id: LNG_ENTERPASSWORD; Name: 'EnterPassword'),
    (Id: LNG_HAVETAGGED; Name: 'HaveTagged'),
    (Id: LNG_YOUSURE; Name: 'YouSure'),
    (Id: LNG_USERFROMCITY; Name: 'UserFromCity'),
    (Id: LNG_MENUERROR; Name: 'MenuError'),
    (Id: LNG_MSGFLAG_RCV; Name: 'MessageFlagRcv'),
    (Id: LNG_MSGFLAG_SNT; Name: 'MessageFlagSnt'),
    (Id: LNG_MSGFLAG_PVT; Name: 'MessageFlagPvt'),
    (Id: LNG_MSGFLAG_CRA; Name: 'MessageFlagCra'),
    (Id: LNG_MSGFLAG_KS; Name: 'MessageFlagKS'),
    (Id: LNG_MSGFLAG_LOC; Name: 'MessageFlagLoc'),
    (Id: LNG_MSGFLAG_HLD; Name: 'MessageFlagHld'),
    (Id: LNG_MSGFLAG_ATT; Name: 'MessageFlagAtt'),
    (Id: LNG_MSGFLAG_FRQ; Name: 'MessageFlagFrq'),
    (Id: LNG_MSGFLAG_TRS; Name: 'MessageFlagTrs'),
    (Id: LNG_ENDOFMESSAGES; Name: 'EndOfMessages'),
    (Id: LNG_READMENU; Name: 'ReadMenu'),
    (Id: LNG_ENDREADMENU; Name: 'EndReadMenu'),
    (Id: LNG_NEXTMESSAGE; Name: 'NextMessage'),
    (Id: LNG_EXITREADMESSAGE; Name: 'ExitReadMessage'),
    (Id: LNG_REREADMESSAGE; Name: 'RereadMessage'),
    (Id: LNG_PREVIOUSMESSAGE; Name: 'PreviousMessage'),
    (Id: LNG_REPLYMESSAGE; Name: 'ReplyMessage'),
    (Id: LNG_EMAILREPLYMESSAGE; Name: 'EMailReplyMessage'),
    (Id: LNG_CONFERENCENOTAVAILABLE; Name: 'ConferenceNotAvailable'),
    (Id: LNG_STARTWITHMESSAGE; Name: 'StartWithMessage'),
    (Id: LNG_NEWMESSAGES; Name: 'NewMessages'),
    (Id: LNG_FORUMNAME; Name: 'ForumName'),
    (Id: LNG_FORUMOPERATOR; Name: 'ForumOperator'),
    (Id: LNG_FORUMTOPIC; Name: 'ForumTopic'),
    (Id: LNG_FILENOTFOUNDINAREA; Name: 'FileNotFoundInArea'),
    (Id: LNG_FILEDESCRIPTION; Name: 'FileDescription'),
    (Id: LNG_FILEDOWNLOADNAME; Name: 'FileDownloadName'),
    (Id: LNG_DOWNLOADFILENAME; Name: 'DownloadFileName'),
    (Id: LNG_NOFILEHERE; Name: 'NoFileHere'),
    (Id: LNG_DISPLAYWHICHFILE; Name: 'DisplayWhichFile'),
    (Id: LNG_PASSWORDNOMATCH; Name: 'PasswordNoMatch'),
    (Id: 0; Name: '')
  );

constructor TLanguage.Create;
begin
  inherited Create;
  Default;
end;

destructor TLanguage.Destroy;
begin
  inherited Destroy;
end;

function TLanguage.CheckKeyword(const Key: String): Word;
var
  i: Integer;
begin
  Result := 0;
  for i := Low(Keywords) to High(Keywords) do
  begin
    if Keywords[i].Name = '' then Break;
    if SameText(Keywords[i].Name, Key) then
    begin
      Result := Keywords[i].Id;
      Exit;
    end;
  end;
end;

function TLanguage.ProcessEscapes(const Arg: String): String;
var
  i: Integer;
  c, c1: Byte;
begin
  Result := '';
  i := 1;
  while i <= Length(Arg) do
  begin
    if (Arg[i] = '\') and (i < Length(Arg)) then
    begin
      Inc(i);
      case Arg[i] of
        'x': begin
          { Hex escape \xNN }
          if i + 2 <= Length(Arg) then
          begin
            c := Byte(UpCase(Arg[i+1])) - Byte('0');
            if c > 9 then Dec(c, 7);
            c1 := Byte(UpCase(Arg[i+2])) - Byte('0');
            if c1 > 9 then Dec(c1, 7);
            Result := Result + Chr((c shl 4) or c1);
            Inc(i, 3);
          end
          else
            Inc(i);
        end;
        'a': begin Result := Result + #7; Inc(i); end;
        'n': begin Result := Result + #10; Inc(i); end;
        'r': begin Result := Result + #13; Inc(i); end;
        't': begin Result := Result + #9; Inc(i); end;
        '0'..'7': begin
          { Octal escape \NNN }
          if (i + 2 <= Length(Arg)) then
          begin
            c := (Byte(Arg[i]) - Byte('0')) * 64 +
                 (Byte(Arg[i+1]) - Byte('0')) * 8 +
                 (Byte(Arg[i+2]) - Byte('0'));
            Result := Result + Chr(c);
            Inc(i, 3);
          end
          else
            Inc(i);
        end;
      else
        Result := Result + Arg[i];
        Inc(i);
      end;
    end
    else
    begin
      Result := Result + Arg[i];
      Inc(i);
    end;
  end;
end;

procedure TLanguage.CopyString(Key: Word; const Arg: String);
var
  Processed: String;
begin
  case Key of
    LNG_LANGUAGE_NAME:
      Comment := Arg;
    LNG_MENUPATH:
      MenuPath := Arg;
    LNG_MENUNAME:
      MenuName := Arg;
    LNG_TEXTFILES:
      TextFiles := Arg;
    LNG_YESKEY:
      if Arg <> '' then Yes := Arg[1];
    LNG_NOKEY:
      if Arg <> '' then No := Arg[1];
    LNG_HELPKEY:
      if Arg <> '' then Help := Arg[1];
    LNG_MALEKEY:
      if Arg <> '' then Male := Arg[1];
    LNG_FEMALEKEY:
      if Arg <> '' then Female := Arg[1];
    LNG_JANUARY..LNG_DECEMBER:
    begin
      Processed := ProcessEscapes(Arg);
      Months[Key - LNG_JANUARY] := Processed;
    end;
  else
    if (Key >= 1) and (Key < LNG_MAX_ENTRIES) then
    begin
      Processed := ProcessEscapes(Arg);
      Strings[Key] := Processed;
    end;
  end;
end;

procedure TLanguage.Default;
var
  i: Integer;
begin
  File_ := 'default.lng';
  Comment := 'Default';
  TextFiles := '';
  MenuName := '';
  MenuPath := '';

  for i := 0 to LNG_MAX_ENTRIES - 1 do
    Strings[i] := '';

  Strings[LNG_YES] := 'YES';
  Strings[LNG_NO] := 'NO ';
  Strings[LNG_NONE] := 'None';

  Yes := 'Y';
  No := 'N';
  Help := '?';
  Male := 'M';
  Female := 'F';

  Months[0] := 'January';
  Months[1] := 'February';
  Months[2] := 'March';
  Months[3] := 'April';
  Months[4] := 'May';
  Months[5] := 'Juni';
  Months[6] := 'July';
  Months[7] := 'August';
  Months[8] := 'September';
  Months[9] := 'October';
  Months[10] := 'November';
  Months[11] := 'December';

  { All the built-in default strings from the C++ source }
  Strings[LNG_MOREQUESTION] := #$16#$01#$0F'More [Y,n,=]? '#$16#$01#$07;
  Strings[LNG_DELETEMOREQUESTION] := #13'                '#13;
  Strings[LNG_NONSTOP] := '=';
  Strings[LNG_QUIT] := 'N';
  Strings[LNG_CONTINUE] := 'Y';
  Strings[LNG_PRESSENTER] := #$16#$01#$0F'Press [Enter] to continue: ';
  Strings[LNG_DEFYESNO] := ' [Y,n]? '#$16#$01#$1E;
  Strings[LNG_YESDEFNO] := ' [y,N]? '#$16#$01#$1E;
  Strings[LNG_DEFYESNOHELP] := ' [Y,n,?=help]? '#$16#$01#$1E;
  Strings[LNG_YESDEFNOHELP] := ' [y,N,?=help]? '#$16#$01#$1E;
  Strings[LNG_MENUERROR] := #10#$16#$01#$0D'Please select one of the choices presented.'#10#$06#$07#$06#$07;
end;

function TLanguage.Load(pszFile: PChar): Word;
var
  Lines: TStringList;
  i, EqPos, Q1, Q2: Integer;
  Line, Key, Arg: String;
  KeyId: Word;
begin
  Result := 0;

  if not FileExists(StrPas(pszFile)) then
    Exit;

  Default;
  File_ := StrPas(pszFile);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(File_);
    Result := 1;

    for i := 0 to Lines.Count - 1 do
    begin
      Line := Lines[i];
      if Line = '' then Continue;

      { Parse Key = "Value" format }
      EqPos := Pos('=', Line);
      if EqPos = 0 then
      begin
        EqPos := Pos(' ', Line);
        if EqPos = 0 then Continue;
      end;

      Key := Trim(Copy(Line, 1, EqPos - 1));
      Arg := Copy(Line, EqPos + 1, MaxInt);

      { Extract quoted value }
      Q1 := Pos('"', Arg);
      if Q1 = 0 then Continue;
      Q2 := Length(Arg);
      while (Q2 > Q1) and (Arg[Q2] <> '"') do
        Dec(Q2);
      if Q2 <= Q1 then Continue;

      Arg := Copy(Arg, Q1 + 1, Q2 - Q1 - 1);

      KeyId := CheckKeyword(Key);
      if KeyId <> 0 then
        CopyString(KeyId, Arg);
    end;
  finally
    Lines.Free;
  end;
end;

function TLanguage.Text(Id: Word): String;
begin
  if (Id >= 1) and (Id < LNG_MAX_ENTRIES) then
    Result := Strings[Id]
  else
    Result := '';
end;

end.
