{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of events.cpp - TEvents class
  Manages scheduled BBS events - time-based tasks like mail processing,
  forced calls, and external commands. Uses TCollection for in-memory
  list, persists to events.dat.
}

unit Events;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, DateUtils, Defs, Struc299, Collect;

type
  TEvents = class
  public
    Number:      Word;
    NextNumber:  Word;
    NextLabel:   array[0..31] of Char;
    Started:     Word;
    TimeRemain:  Word;

    Label_:      array[0..31] of Char;
    Hour:        Byte;
    Minute:      Byte;
    Sunday:      Byte;
    Monday:      Byte;
    Tuesday:     Byte;
    Wednesday:   Byte;
    Thursday:    Byte;
    Friday:      Byte;
    Saturday:    Byte;
    Length_:     Word;
    LastDay:     Word;
    Dynamic:     Byte;
    Force:       Byte;
    MailOnly:    Byte;
    ForceCall:   Byte;
    Address:     array[0..31] of Char;
    SendNormal:  Byte;
    SendCrash:   Byte;
    SendDirect:  Byte;
    SendImmediate: Byte;
    CallDelay:   Word;
    StartImport: Byte;
    StartExport: Byte;
    ExportMail:  Byte;
    ImportNormal: Byte;
    ImportKnown: Byte;
    ImportProtected: Byte;
    RouteCmd:    array[0..63] of Char;
    Command:     array[0..127] of Char;
    MaxCalls:    Word;
    MaxConnects: Word;
    AllowRequests: Byte;
    MakeRequests: Byte;
    ProcessTIC:  Byte;
    ClockAdjustment: Byte;
    Completed:   Byte;

    constructor Create; overload;
    constructor Create(pszDataFile: PChar); overload;
    destructor Destroy; override;

    procedure Add;
    procedure Delete;
    function  First: Word;
    function  SetCurrent: Word;
    function  Load: Word;
    procedure New_;
    function  Next: Word;
    function  Previous: Word;
    function  Read(evtNum: Word): Word;
    procedure Save;
    procedure TimeToNext;
    procedure Update;

  private
    DataFile: String;
    Event:    EVENT_REC;
    Data:     TCollection;

    procedure Class2Struct(var Evt: EVENT_REC);
    procedure Struct2Class(var Evt: EVENT_REC);
  end;

implementation

constructor TEvents.Create;
begin
  inherited Create;
  DataFile := 'events.dat';
  Data := TCollection.Create;
end;

constructor TEvents.Create(pszDataFile: PChar);
var
  S: String;
begin
  inherited Create;
  Data := TCollection.Create;
  S := LowerCase(StrPas(pszDataFile));
  if Pos('.', ExtractFileName(S)) = 0 then
    S := S + '.dat';
  DataFile := S;
end;

destructor TEvents.Destroy;
begin
  Data.Clear;
  Data.Free;
  inherited Destroy;
end;

procedure TEvents.Class2Struct(var Evt: EVENT_REC);
begin
  FillChar(Evt, SizeOf(EVENT_REC), 0);

  StrCopy(Evt.Label_, Label_);
  Evt.Hour := Hour;
  Evt.Minute := Minute;
  Evt.WeekDays := 0;
  if Sunday <> 0 then
    Evt.WeekDays := Evt.WeekDays or DAY_SUNDAY;
  if Monday <> 0 then
    Evt.WeekDays := Evt.WeekDays or DAY_MONDAY;
  if Tuesday <> 0 then
    Evt.WeekDays := Evt.WeekDays or DAY_TUESDAY;
  if Wednesday <> 0 then
    Evt.WeekDays := Evt.WeekDays or DAY_WEDNESDAY;
  if Thursday <> 0 then
    Evt.WeekDays := Evt.WeekDays or DAY_THURSDAY;
  if Friday <> 0 then
    Evt.WeekDays := Evt.WeekDays or DAY_FRIDAY;
  if Saturday <> 0 then
    Evt.WeekDays := Evt.WeekDays or DAY_SATURDAY;
  Evt.Length_ := Length_;
  Evt.LastDay := LastDay;
  Evt.Dynamic := Dynamic;
  Evt.Force := Force;
  Evt.MailOnly := MailOnly;
  Evt.ForceCall := ForceCall;
  StrCopy(Evt.Address, Address);
  Evt.SendNormal := SendNormal;
  Evt.SendCrash := SendCrash;
  Evt.SendDirect := SendDirect;
  Evt.SendImmediate := SendImmediate;
  Evt.CallDelay := CallDelay;
  Evt.StartImport := StartImport;
  Evt.StartExport := StartExport;
  Evt.ExportMail := ExportMail;
  Evt.ImportNormal := ImportNormal;
  Evt.ImportKnown := ImportKnown;
  Evt.ImportProtected := ImportProtected;
  StrCopy(Evt.RouteCmd, RouteCmd);
  StrCopy(Evt.Command, Command);
  Evt.MaxCalls := MaxCalls;
  Evt.MaxConnects := MaxConnects;
  Evt.AllowRequests := AllowRequests;
  Evt.MakeRequests := MakeRequests;
  Evt.ProcessTIC := ProcessTIC;
  Evt.ClockAdjustment := ClockAdjustment;
  Evt.Completed := Completed;
end;

procedure TEvents.Struct2Class(var Evt: EVENT_REC);
begin
  StrCopy(Label_, Evt.Label_);
  Hour := Evt.Hour;
  Minute := Evt.Minute;
  Sunday := Ord((Evt.WeekDays and DAY_SUNDAY) <> 0);
  Monday := Ord((Evt.WeekDays and DAY_MONDAY) <> 0);
  Tuesday := Ord((Evt.WeekDays and DAY_TUESDAY) <> 0);
  Wednesday := Ord((Evt.WeekDays and DAY_WEDNESDAY) <> 0);
  Thursday := Ord((Evt.WeekDays and DAY_THURSDAY) <> 0);
  Friday := Ord((Evt.WeekDays and DAY_FRIDAY) <> 0);
  Saturday := Ord((Evt.WeekDays and DAY_SATURDAY) <> 0);
  Length_ := Evt.Length_;
  LastDay := Evt.LastDay;
  Dynamic := Evt.Dynamic;
  Force := Evt.Force;
  MailOnly := Evt.MailOnly;
  ForceCall := Evt.ForceCall;
  StrCopy(Address, Evt.Address);
  SendNormal := Evt.SendNormal;
  SendCrash := Evt.SendCrash;
  SendDirect := Evt.SendDirect;
  SendImmediate := Evt.SendImmediate;
  CallDelay := Evt.CallDelay;
  StartImport := Evt.StartImport;
  StartExport := Evt.StartExport;
  ExportMail := Evt.ExportMail;
  ImportNormal := Evt.ImportNormal;
  ImportKnown := Evt.ImportKnown;
  ImportProtected := Evt.ImportProtected;
  StrCopy(RouteCmd, Evt.RouteCmd);
  StrCopy(Command, Evt.Command);
  MaxCalls := Evt.MaxCalls;
  MaxConnects := Evt.MaxConnects;
  AllowRequests := Evt.AllowRequests;
  MakeRequests := Evt.MakeRequests;
  ProcessTIC := Evt.ProcessTIC;
  ClockAdjustment := Evt.ClockAdjustment;
  Completed := Evt.Completed;
end;

procedure TEvents.Add;
var
  TimeNew, TimeEvent: Word;
  lpEvent: PEVENT_REC;
  Value: Pointer;
  Found: Boolean;
begin
  Class2Struct(Event);
  Found := False;
  Value := nil;

  TimeNew := Word(Event.Hour) * 60 + Event.Minute;

  lpEvent := PEVENT_REC(Data.First);
  if lpEvent <> nil then
  begin
    TimeEvent := Word(lpEvent^.Hour) * 60 + lpEvent^.Minute;
    if (TimeNew + Event.Length_) <= (TimeEvent + lpEvent^.Length_) then
    begin
      Data.Insert(@Event, SizeOf(EVENT_REC));
      Value := Data.Value;
      Data.Insert(lpEvent, SizeOf(EVENT_REC));
      Data.First;
      Data.Remove;
      Found := True;
    end;

    if not Found then
    begin
      repeat
        TimeEvent := Word(lpEvent^.Hour) * 60 + lpEvent^.Minute;
        if (TimeNew + Event.Length_) <= (TimeEvent + lpEvent^.Length_) then
        begin
          Data.Previous;
          Data.Insert(@Event, SizeOf(EVENT_REC));
          Value := Data.Value;
          Found := True;
        end;
        if Found then Break;
        lpEvent := PEVENT_REC(Data.Next);
      until lpEvent = nil;
    end;
  end;

  if not Found then
  begin
    Data.Add(@Event, SizeOf(EVENT_REC));
    Value := Data.Value;
  end;

  Number := 0;
  if Data.First <> nil then
  begin
    repeat
      Inc(Number);
      if Data.Value = Value then
        Break;
    until Data.Next = nil;
  end;
end;

procedure TEvents.Delete;
var
  Current: PEVENT_REC;
begin
  if Data.Value <> nil then
  begin
    Data.Remove;
    if Data.Value <> nil then
    begin
      Current := PEVENT_REC(Data.Value);
      Data.First;
      Number := 1;
      while Data.Value <> Pointer(Current) do
      begin
        Data.Next;
        Inc(Number);
      end;
      Struct2Class(Current^);
    end
    else
    begin
      Number := 0;
      New_;
    end;
  end;
end;

function TEvents.First: Word;
var
  Evt: PEVENT_REC;
begin
  Result := 0;
  Started := 0;

  Evt := PEVENT_REC(Data.First);
  if Evt <> nil then
  begin
    Number := 1;
    Struct2Class(Evt^);
    Result := 1;
  end;
end;

function TEvents.Load: Word;
var
  fs: TFileStream;
begin
  Result := 0;
  Data.Clear;

  if not FileExists(DataFile) then
    Exit;

  try
    fs := TFileStream.Create(DataFile, fmOpenRead or fmShareDenyNone);
    try
      while fs.Read(Event, SizeOf(EVENT_REC)) = SizeOf(EVENT_REC) do
        Data.Add(@Event, SizeOf(EVENT_REC));
    finally
      fs.Free;
    end;

    Result := First;
  except
  end;
end;

procedure TEvents.New_;
begin
  FillChar(Label_, SizeOf(Label_), 0);
  Hour := 0;
  Minute := 0;
  Sunday := 0;
  Monday := 0;
  Tuesday := 0;
  Wednesday := 0;
  Thursday := 0;
  Friday := 0;
  Saturday := 0;
  Length_ := 1;
  LastDay := 0;
  Dynamic := 0;
  Force := 0;
  MailOnly := 0;
  ForceCall := 0;
  FillChar(Address, SizeOf(Address), 0);
  SendNormal := 0;
  SendCrash := 0;
  SendDirect := 0;
  SendImmediate := 0;
  CallDelay := 30;
  StartImport := 0;
  StartExport := 0;
  ExportMail := 0;
  ImportNormal := 0;
  ImportProtected := 0;
  ImportKnown := 0;
  FillChar(RouteCmd, SizeOf(RouteCmd), 0);
  FillChar(Command, SizeOf(Command), 0);
  MaxCalls := 0;
  MaxConnects := 0;
  AllowRequests := 0;
  MakeRequests := 0;
  ProcessTIC := 0;
  ClockAdjustment := 0;
end;

function TEvents.Next: Word;
var
  Evt: PEVENT_REC;
begin
  Result := 0;
  Started := 0;

  Evt := PEVENT_REC(Data.Next);
  if Evt <> nil then
  begin
    Inc(Number);
    Struct2Class(Evt^);
    Result := 1;
  end;
end;

function TEvents.Previous: Word;
var
  Evt: PEVENT_REC;
begin
  Result := 0;
  Started := 0;

  Evt := PEVENT_REC(Data.Previous);
  if Evt <> nil then
  begin
    Dec(Number);
    Struct2Class(Evt^);
    Result := 1;
  end;
end;

function TEvents.Read(evtNum: Word): Word;
begin
  Result := 0;

  if First = 1 then
  begin
    repeat
      if Number = evtNum then
      begin
        Result := 1;
        Break;
      end;
    until Next <> 1;
  end;
end;

procedure TEvents.Save;
var
  fs: TFileStream;
  Current: Word;
begin
  try
    fs := TFileStream.Create(DataFile, fmCreate);
    try
      Current := Number;

      if Data.First <> nil then
      begin
        repeat
          fs.Write(Data.Value^, SizeOf(EVENT_REC));
        until Data.Next = nil;
      end;
    finally
      fs.Free;
    end;

    { Restore position }
    if Data.First <> nil then
    begin
      repeat
        if Number = Current then
          Break;
      until Data.Next = nil;
    end;
  except
  end;
end;

function TEvents.SetCurrent: Word;
var
  TimeNow, TimeEvent, CurDay: Word;
  Evt: PEVENT_REC;
  NowDT: TDateTime;
  HourNow, MinNow, SecNow, MSec: Word;
  YearNow, MonthNow, DayNow: Word;
begin
  Result := 0;

  NowDT := Now;
  DecodeTime(NowDT, HourNow, MinNow, SecNow, MSec);
  DecodeDate(NowDT, YearNow, MonthNow, DayNow);
  TimeNow := HourNow * 60 + MinNow;
  CurDay := Word(1 shl DayOfTheWeek(NowDT));
  { DayOfTheWeek: 1=Mon..7=Sun, we need Sun=1, so remap }
  CurDay := Word(1 shl (DayOfWeek(NowDT) - 1));
  Number := 0;

  Evt := PEVENT_REC(Data.First);
  while Evt <> nil do
  begin
    Inc(Number);
    TimeEvent := Word(Evt^.Hour) * 60 + Evt^.Minute;
    if (TimeNow >= TimeEvent) and (TimeNow < (TimeEvent + Evt^.Length_)) and
       ((CurDay and Evt^.WeekDays) <> 0) then
    begin
      if Evt^.LastDay <> DayOfTheYear(NowDT) then
      begin
        Evt^.LastDay := Word(DayOfTheYear(NowDT));
        Evt^.Completed := 0;
        Started := 1;
      end
      else
        Started := 0;

      Struct2Class(Evt^);
      Result := 1;
      Exit;
    end;
    Evt := PEVENT_REC(Data.Next);
  end;
end;

procedure TEvents.TimeToNext;
var
  TimeNow, TimeEvent, ToMid, CurDay, Num: Word;
  Evt: PEVENT_REC;
  NowDT: TDateTime;
  HourNow, MinNow, SecNow, MSec: Word;
begin
  NowDT := Now;
  DecodeTime(NowDT, HourNow, MinNow, SecNow, MSec);
  TimeNow := HourNow * 60 + MinNow;
  CurDay := Word(1 shl (DayOfWeek(NowDT) - 1));

  NextNumber := 0;
  NextLabel[0] := #0;
  TimeRemain := 3000;
  Num := 0;

  Evt := PEVENT_REC(Data.First);
  while Evt <> nil do
  begin
    Inc(Num);
    TimeEvent := Word(Evt^.Hour) * 60 + Evt^.Minute;
    if (Evt^.LastDay <> DayOfTheYear(NowDT)) and (TimeEvent > TimeNow) and
       ((CurDay and Evt^.WeekDays) <> 0) then
    begin
      if TimeRemain > (TimeEvent - TimeNow) then
      begin
        TimeRemain := TimeEvent - TimeNow;
        StrCopy(NextLabel, Evt^.Label_);
        NextNumber := Num;
      end;
    end;
    Evt := PEVENT_REC(Data.Next);
  end;

  { If no event found today, check tomorrow }
  if TimeRemain > 1440 then
  begin
    ToMid := 1440 - TimeNow;
    TimeNow := 0;
    CurDay := CurDay shl 1;
    if CurDay > DAY_SATURDAY then
      CurDay := DAY_SUNDAY;
    Num := 0;

    Evt := PEVENT_REC(Data.First);
    while Evt <> nil do
    begin
      Inc(Num);
      TimeEvent := Word(Evt^.Hour) * 60 + Evt^.Minute;
      if (TimeEvent >= TimeNow) and ((CurDay and Evt^.WeekDays) <> 0) then
      begin
        if TimeRemain > (TimeEvent - TimeNow + ToMid) then
        begin
          TimeRemain := TimeEvent - TimeNow + ToMid;
          StrCopy(NextLabel, Evt^.Label_);
          NextNumber := Num;
        end;
      end;
      Evt := PEVENT_REC(Data.Next);
    end;
  end;

  if TimeRemain > 1440 then
    TimeRemain := 1440;
end;

procedure TEvents.Update;
var
  Evt: PEVENT_REC;
begin
  Evt := PEVENT_REC(Data.Value);
  if Evt <> nil then
  begin
    if (Evt^.Hour <> Hour) or (Evt^.Minute <> Minute) or (Evt^.Length_ <> Length_) then
    begin
      Data.Remove;
      Add;
      Evt := PEVENT_REC(Data.Value);
      if Evt <> nil then
        Struct2Class(Evt^);
    end
    else
      Class2Struct(Evt^);
  end;
end;

end.
