{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of outbound.cpp
  Bink/Opus outbound directory management: scans outbound directories for
  mail packets, file attaches, file requests, and poll flags. Manages a
  sorted node queue with attempt/failure tracking.
}

unit Outbound;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect, Struc299, Address
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

type
  TOutbound = class
  private
    FPath: String;
    FOutbound: String;
    FFiles: TCollection;
    FNodes: TCollection;
    function AddQueue(var Out: OUTFILE): Boolean;
    procedure CopyOutToFields(P: POUTFILE);
    procedure CopyQueueToFields(Q: PQUEUE);
    function BuildAddress: String;
  public
    Zone, Net, Node, Point: Word;
    Domain: String;
    Name: String;
    Complete: String;
    Size: LongWord;
    ArcMail, MailPKT, Request, Poll: Boolean;
    DeleteAfter, TruncateAfter: Boolean;
    Status: Char;

    Number: Word;
    Address_: String;
    Crash, Direct, Hold, Immediate, Normal: Boolean;
    Attempts, Failed: Word;
    LastCall: String;

    DefaultZone: Word;
    TotalFiles, TotalNodes: Word;
    TotalSize: LongWord;

    constructor Create(const APath: String);
    constructor Create(const APath: String; AZone, ANet, ANode: Word;
      APoint: Word = 0; const ADomain: String = '');
    destructor Destroy; override;

    function Add: Boolean; overload;
    function Add(AZone, ANet, ANode: Word; APoint: Word = 0;
      const ADomain: String = ''): Boolean; overload;
    procedure BuildQueue(const APath: String);
    procedure Clear;
    function First: Boolean;
    function FirstNode: Boolean;
    procedure New_;
    function Next: Boolean;
    function NextNode: Boolean;
    procedure PollNode(const AAddress: String; Flag: Char);
    procedure Remove;
    procedure Update;

    procedure AddAttempt(const AAddress: String; AFailed: Boolean;
      const AStatus: String = '');
    procedure ClearAttempt(const AAddress: String);
  end;

implementation

const
  ArcFlags: array[0..6] of String = ('.mo', '.tu', '.we', '.th', '.fr', '.sa', '.su');

function GetFileSize(const AFileName: String): Int64;
var
  SR: TSearchRec;
begin
  if SysUtils.FindFirst(AFileName, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    SysUtils.FindClose(SR);
  end
  else
    Result := 0;
end;

function AdjustPath(const S: String): String;
begin
  {$IFDEF UNIX}
  Result := StringReplace(S, '\', '/', [rfReplaceAll]);
  {$ELSE}
  Result := StringReplace(S, '/', '\', [rfReplaceAll]);
  {$ENDIF}
end;

function ExtractNameFromPath(const Path: String): String;
var
  I: Integer;
begin
  I := Length(Path);
  while (I > 0) and not (Path[I] in ['\', '/', ':']) do
    Dec(I);
  Result := Copy(Path, I + 1, MaxInt);
end;

{ TOutbound }

constructor TOutbound.Create(const APath: String);
begin
  inherited Create;
  FFiles := TCollection.Create;
  FNodes := TCollection.Create;
  DefaultZone := 2;
  TotalNodes := 0;
  TotalFiles := 0;
  TotalSize := 0;
  FPath := IncludeTrailingPathDelimiter(APath);
end;

constructor TOutbound.Create(const APath: String; AZone, ANet, ANode: Word;
  APoint: Word; const ADomain: String);
begin
  inherited Create;
  FFiles := TCollection.Create;
  FNodes := TCollection.Create;
  DefaultZone := 2;
  TotalFiles := 0;
  TotalSize := 0;
  TotalNodes := 0;
  FPath := IncludeTrailingPathDelimiter(APath);
  Add(AZone, ANet, ANode, APoint, ADomain);
end;

destructor TOutbound.Destroy;
begin
  FFiles.Clear;
  FNodes.Clear;
  FreeAndNil(FFiles);
  FreeAndNil(FNodes);
  inherited Destroy;
end;

function TOutbound.BuildAddress: String;
begin
  if Point <> 0 then
    Result := Format('%u:%u/%u.%u', [Zone, Net, Node, Point])
  else
    Result := Format('%u:%u/%u', [Zone, Net, Node]);
  if Domain <> '' then
    Result := Result + '@' + Domain;
end;

procedure TOutbound.CopyOutToFields(P: POUTFILE);
begin
  Zone := P^.Zone;
  Net := P^.Net;
  Node := P^.Node;
  Point := P^.Point;
  Domain := StrPas(P^.Domain);
  Address_ := BuildAddress;
  Name := StrPas(P^.Name);
  Complete := StrPas(P^.Complete);
  Size := P^.Size;
  ArcMail := P^.ArcMail <> 0;
  MailPKT := P^.MailPKT <> 0;
  Request := P^.Request <> 0;
  Poll := P^.Poll <> 0;
  DeleteAfter := P^.DeleteAfter <> 0;
  TruncateAfter := P^.TruncateAfter <> 0;
  Status := P^.Status;
end;

procedure TOutbound.CopyQueueToFields(Q: PQUEUE);
begin
  Zone := Q^.Zone;
  Net := Q^.Net;
  Node := Q^.Node;
  Point := Q^.Point;
  Domain := StrPas(Q^.Domain);
  Address_ := BuildAddress;
  Number := Q^.Files;
  Size := Q^.Size;
  Crash := Q^.Crash <> 0;
  Direct := Q^.Direct <> 0;
  Hold := Q^.Hold <> 0;
  Immediate := Q^.Immediate <> 0;
  Normal := Q^.Normal <> 0;
  Attempts := Q^.Attempts;
  Failed := Q^.Failed;
  LastCall := StrPas(Q^.LastCall);
end;

procedure TOutbound.New_;
begin
  Zone := 0;
  Net := 0;
  Node := 0;
  Point := 0;
  Domain := '';
  Name := '';
  Complete := '';
  Size := 0;
  ArcMail := False;
  MailPKT := False;
  Request := False;
  DeleteAfter := False;
  TruncateAfter := False;
  Poll := False;
  Status := #0;
end;

procedure TOutbound.Clear;
begin
  FFiles.Clear;
  FNodes.Clear;
  TotalFiles := 0;
  TotalSize := 0;
  TotalNodes := 0;
  New_;
end;

function TOutbound.AddQueue(var Out: OUTFILE): Boolean;
var
  Temp: PQUEUE;
  QRec: QUEUE;
  Inserted: Boolean;
begin
  Result := False;

  { Check if node already in queue }
  Temp := PQUEUE(FNodes.First);
  while Temp <> nil do
  begin
    if (Temp^.Zone = Out.Zone) and (Temp^.Net = Out.Net) and
       (Temp^.Node = Out.Node) and (Temp^.Point = Out.Point) and
       (StrIComp(Temp^.Domain, Out.Domain) = 0) then
    begin
      Inc(Temp^.Files);
      Inc(Temp^.Size, Out.Size);
      case Out.Status of
        'C', 'c': Temp^.Crash := 1;
        'D', 'd': Temp^.Direct := 1;
        'H', 'h': Temp^.Hold := 1;
        'I', 'i': Temp^.Immediate := 1;
        'O', 'o', 'F', 'f': Temp^.Normal := 1;
      end;
      Result := True;
      Exit;
    end;
    Temp := PQUEUE(FNodes.Next);
  end;

  { New node - create queue entry }
  FillChar(QRec, SizeOf(QRec), 0);
  QRec.Zone := Out.Zone;
  QRec.Net := Out.Net;
  QRec.Node := Out.Node;
  QRec.Point := Out.Point;
  StrCopy(QRec.Domain, Out.Domain);
  QRec.Files := 1;
  QRec.Size := Out.Size;
  case Out.Status of
    'C', 'c': QRec.Crash := 1;
    'D', 'd': QRec.Direct := 1;
    'H', 'h': QRec.Hold := 1;
    'I', 'i': QRec.Immediate := 1;
    'N', 'n': QRec.Normal := 1;
  end;

  { Sorted insert by Zone/Net/Node/Point }
  Inserted := False;
  Temp := PQUEUE(FNodes.First);
  if Temp <> nil then
  begin
    if (Temp^.Zone > QRec.Zone) or
       ((Temp^.Zone = QRec.Zone) and (Temp^.Net > QRec.Net)) or
       ((Temp^.Zone = QRec.Zone) and (Temp^.Net = QRec.Net) and (Temp^.Node > QRec.Node)) or
       ((Temp^.Zone = QRec.Zone) and (Temp^.Net = QRec.Net) and (Temp^.Node = QRec.Node) and (Temp^.Point > QRec.Point)) then
    begin
      { Insert before first - replicate C logic: Insert new, Insert copy of first, remove original first }
      FNodes.Insert(@QRec, SizeOf(QUEUE));
      FNodes.Insert(Temp, SizeOf(QUEUE));
      FNodes.First;
      FNodes.Remove;
      FNodes.First;
      Inc(TotalNodes);
      Inserted := True;
    end
    else
    begin
      Temp := PQUEUE(FNodes.Next);
      while Temp <> nil do
      begin
        if (Temp^.Zone > QRec.Zone) or
           ((Temp^.Zone = QRec.Zone) and (Temp^.Net > QRec.Net)) or
           ((Temp^.Zone = QRec.Zone) and (Temp^.Net = QRec.Net) and (Temp^.Node > QRec.Node)) or
           ((Temp^.Zone = QRec.Zone) and (Temp^.Net = QRec.Net) and (Temp^.Node = QRec.Node) and (Temp^.Point > QRec.Point)) then
        begin
          FNodes.Previous;
          FNodes.Insert(@QRec, SizeOf(QUEUE));
          Inc(TotalNodes);
          Inserted := True;
          Break;
        end;
        Temp := PQUEUE(FNodes.Next);
      end;
      if not Inserted then
      begin
        FNodes.Add(@QRec, SizeOf(QUEUE));
        Inc(TotalNodes);
        Inserted := True;
      end;
    end;
  end;

  if not Inserted then
  begin
    FNodes.Add(@QRec, SizeOf(QUEUE));
    Inc(TotalNodes);
  end;

  Result := True;
end;

function TOutbound.Add: Boolean;
var
  Out: OUTFILE;
  TmpName: String;
begin
  Result := False;
  FillChar(Out, SizeOf(Out), 0);
  Out.Zone := Zone;
  Out.Net := Net;
  Out.Node := Node;
  Out.Point := Point;
  StrPCopy(Out.Domain, Domain);

  if Name = '' then
  begin
    TmpName := ExtractNameFromPath(Complete);
    StrPCopy(Out.Name, TmpName);
  end
  else
    StrPCopy(Out.Name, Name);

  StrPCopy(Out.Complete, Complete);
  Out.Size := Size;
  if ArcMail then Out.ArcMail := 1;
  if MailPKT then Out.MailPKT := 1;
  if Request then Out.Request := 1;
  if Poll then Out.Poll := 1;
  if DeleteAfter then Out.DeleteAfter := 1;
  if TruncateAfter then Out.TruncateAfter := 1;

  if Poll then
  begin
    if Crash then
      Status := 'C'
    else if Direct then
      Status := 'D'
    else if Normal then
      Status := 'F'
    else if Immediate then
      Status := 'I';
  end;
  Out.Status := Status;

  if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
  begin
    if AddQueue(Out) then
    begin
      Inc(TotalSize, Out.Size);
      Inc(TotalFiles);
      Result := True;
    end;
  end;
end;

function TOutbound.Add(AZone, ANet, ANode: Word; APoint: Word;
  const ADomain: String): Boolean;
var
  I, X, J: Integer;
  FileName, Line, PFile: String;
  Flags: array[0..5] of Char;
  Out: OUTFILE;
  SR: TSearchRec;
  Lines: TStringList;
  FileSize: Int64;
  Readed: Boolean;
begin
  Result := False;
  Flags[0] := 'h'; Flags[1] := 'c'; Flags[2] := 'd';
  Flags[3] := 'f'; Flags[4] := 'o'; Flags[5] := 'i';

  { Build Bink/Opus outbound path }
  FOutbound := FPath;
  if AZone <> DefaultZone then
    FOutbound := ExcludeTrailingPathDelimiter(FOutbound) +
      Format('.%3.3x', [AZone]) + PathDelim;

  { Check mail packets (.hut, .cut, .dut, .fut, .out, .iut) }
  for I := 0 to 5 do
  begin
    if APoint <> 0 then
      FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.%sut',
        [FOutbound, ANet, ANode, PathDelim, APoint, Flags[I]])
    else
      FileName := Format('%s%4.4x%4.4x.%sut',
        [FOutbound, ANet, ANode, Flags[I]]);

    FileName := AdjustPath(FileName);
    if FileExists(FileName) then
    begin
      FillChar(Out, SizeOf(Out), 0);
      Out.Zone := AZone;
      Out.Net := ANet;
      Out.Node := ANode;
      Out.Point := APoint;
      if ADomain <> '' then
        StrPCopy(Out.Domain, ADomain);
      if APoint <> 0 then
        StrPCopy(Out.Name, Format('%8.8x.%sut', [APoint, Flags[I]]))
      else
        StrPCopy(Out.Name, Format('%4.4x%4.4x.%sut', [ANet, ANode, Flags[I]]));
      StrPCopy(Out.Complete, FileName);
      FileSize := GetFileSize(FileName);
      Out.Size := LongWord(FileSize);
      Out.MailPKT := 1;
      Out.DeleteAfter := 1;
      Out.Status := Flags[I];
      if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
        if AddQueue(Out) then
        begin
          Inc(TotalSize, Out.Size);
          Inc(TotalFiles);
          Result := True;
        end;
    end;
  end;

  { Check file attaches (.hlo, .clo, .dlo, .flo, .olo, .ilo) }
  for I := 0 to 5 do
  begin
    if APoint <> 0 then
      FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.%slo',
        [FOutbound, ANet, ANode, PathDelim, APoint, Flags[I]])
    else
      FileName := Format('%s%4.4x%4.4x.%slo',
        [FOutbound, ANet, ANode, Flags[I]]);

    FileName := AdjustPath(FileName);
    if FileExists(FileName) then
    begin
      Readed := False;
      Lines := TStringList.Create;
      try
        Lines.LoadFromFile(FileName);
        for X := 0 to Lines.Count - 1 do
        begin
          Line := Trim(Lines[X]);
          if Line = '' then Continue;
          PFile := Line;
          if (Line[1] = '^') or (Line[1] = '#') then
            PFile := Copy(Line, 2, MaxInt);
          if (PFile = '') or (PFile[1] = '~') then Continue;
          PFile := AdjustPath(PFile);
          if not FileExists(PFile) then Continue;

          FillChar(Out, SizeOf(Out), 0);
          Out.Zone := AZone;
          Out.Net := ANet;
          Out.Node := ANode;
          Out.Point := APoint;
          if ADomain <> '' then
            StrPCopy(Out.Domain, ADomain);

          { Check for rename marker (!) }
          if Pos('!', PFile) > 0 then
            StrPCopy(Out.Name, Copy(PFile, Pos('!', PFile) + 1, MaxInt))
          else
            StrPCopy(Out.Name, ExtractFileName(PFile));

          StrPCopy(Out.Complete, PFile);
          FileSize := GetFileSize(PFile);
          Out.Size := LongWord(FileSize);

          { Check if mail PKT or arcmail }
          if Pos('.pk', LowerCase(StrPas(Out.Name))) > 0 then
            Out.MailPKT := 1
          else
          begin
            for J := 0 to 6 do
              if Pos(ArcFlags[J], LowerCase(StrPas(Out.Name))) > 0 then
              begin
                Out.ArcMail := 1;
                Break;
              end;
          end;

          if Line[1] = '^' then
            Out.DeleteAfter := 1
          else if Line[1] = '#' then
            Out.TruncateAfter := 1;

          Out.Status := Flags[I];
          if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
            if AddQueue(Out) then
            begin
              Inc(TotalSize, Out.Size);
              Inc(TotalFiles);
              Readed := True;
              Result := True;
            end;
        end;
      finally
        Lines.Free;
      end;

      { If no files found in .?lo, it's a poll }
      if not Readed then
      begin
        FillChar(Out, SizeOf(Out), 0);
        Out.Zone := AZone;
        Out.Net := ANet;
        Out.Node := ANode;
        Out.Point := APoint;
        if ADomain <> '' then
          StrPCopy(Out.Domain, ADomain);
        Out.Status := Flags[I];
        Out.Poll := 1;
        if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
          if AddQueue(Out) then
          begin
            Inc(TotalSize, Out.Size);
            Inc(TotalFiles);
            Result := True;
          end;
      end;
    end;
  end;

  { Check file requests (.req) }
  if APoint <> 0 then
    FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.req',
      [FOutbound, ANet, ANode, PathDelim, APoint])
  else
    FileName := Format('%s%4.4x%4.4x.req',
      [FOutbound, ANet, ANode]);

  FileName := AdjustPath(FileName);
  if FileExists(FileName) then
  begin
    FillChar(Out, SizeOf(Out), 0);
    Out.Zone := AZone;
    Out.Net := ANet;
    Out.Node := ANode;
    Out.Point := APoint;
    if ADomain <> '' then
      StrPCopy(Out.Domain, ADomain);
    if APoint <> 0 then
      StrPCopy(Out.Name, Format('%8.8x.req', [APoint]))
    else
      StrPCopy(Out.Name, Format('%4.4x%4.4x.req', [ANet, ANode]));
    StrPCopy(Out.Complete, FileName);
    FileSize := GetFileSize(FileName);
    Out.Size := LongWord(FileSize);
    Out.Request := 1;
    Out.DeleteAfter := 1;
    if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
      if AddQueue(Out) then
      begin
        Inc(TotalSize, Out.Size);
        Inc(TotalFiles);
        Result := True;
      end;
  end;
end;

procedure TOutbound.BuildQueue(const APath: String);
var
  BasePath, BaseOut, ZoneDir, EntryPath, SubPath: String;
  SR, SR2, SR3: TSearchRec;
  Out: OUTFILE;
  QPtr: PQUEUE;
  Ext: String;
  I, X, J: Integer;
  Flag: Char;
  Lines: TStringList;
  Line, PFile: String;
  FileSize: Int64;
  Added: Boolean;
  ParsedZone, ParsedNet, ParsedNode, ParsedPoint: Word;
  FD: TFileStream;
  AttemptData: Word;
begin
  FFiles.Clear;
  FNodes.Clear;
  TotalNodes := 0;
  TotalFiles := 0;
  TotalSize := 0;
  Number := 0;

  BasePath := ExcludeTrailingPathDelimiter(APath);
  BaseOut := UpperCase(ExtractFileName(BasePath));

  { Scan parent directory for outbound dirs (base + zone extensions) }
  if FindFirst(BasePath + '*', faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) = 0 then Continue;
        if not SameText(Copy(SR.Name, 1, Length(BaseOut)), BaseOut) then Continue;

        FillChar(Out, SizeOf(Out), 0);
        Ext := ExtractFileExt(SR.Name);
        if Ext <> '' then
        begin
          try
            ParsedZone := StrToInt('$' + Copy(Ext, 2, 3));
          except
            ParsedZone := 0;
          end;
          if ParsedZone <> 0 then
            ZoneDir := BasePath + '.' + LowerCase(Format('%3.3x', [ParsedZone]))
          else
          begin
            ParsedZone := DefaultZone;
            ZoneDir := BasePath;
          end;
        end
        else
        begin
          ParsedZone := DefaultZone;
          ZoneDir := BasePath;
        end;
        Out.Zone := ParsedZone;

        { Scan outbound directory for files }
        if FindFirst(IncludeTrailingPathDelimiter(AdjustPath(ZoneDir)) + '*', faAnyFile, SR2) = 0 then
        begin
          try
            repeat
              if (SR2.Name = '.') or (SR2.Name = '..') then Continue;
              Ext := UpperCase(ExtractFileExt(SR2.Name));
              if Length(Ext) < 4 then Continue;

              if (Ext[3] = 'L') and (Ext[4] = 'O') then
              begin
                { File attach (.?lo) }
                Out.Point := 0;
                try
                  ParsedNet := StrToInt('$' + Copy(SR2.Name, 1, 4));
                  ParsedNode := StrToInt('$' + Copy(SR2.Name, 5, 4));
                except
                  Continue;
                end;
                Out.Net := ParsedNet;
                Out.Node := ParsedNode;
                Out.Status := UpCase(Ext[2]);

                EntryPath := IncludeTrailingPathDelimiter(AdjustPath(ZoneDir)) + SR2.Name;
                Out.Size := 0;
                Added := False;

                Lines := TStringList.Create;
                try
                  Lines.LoadFromFile(AdjustPath(EntryPath));
                  for I := 0 to Lines.Count - 1 do
                  begin
                    Line := Trim(Lines[I]);
                    if Line = '' then Continue;
                    PFile := Line;
                    if (Line[1] = '^') or (Line[1] = '#') then
                      PFile := Copy(Line, 2, MaxInt);
                    if (PFile = '') or (PFile[1] = '~') then Continue;
                    PFile := AdjustPath(PFile);
                    if not FileExists(PFile) then Continue;

                    StrPCopy(Out.Complete, PFile);
                    StrPCopy(Out.Name, ExtractFileName(PFile));
                    FileSize := GetFileSize(PFile);
                    Out.Size := LongWord(FileSize);

                    Out.MailPKT := 0;
                    Out.ArcMail := 0;
                    Out.DeleteAfter := 0;
                    Out.TruncateAfter := 0;

                    if Pos('.pk', LowerCase(StrPas(Out.Name))) > 0 then
                      Out.MailPKT := 1
                    else
                    begin
                      for J := 0 to 6 do
                        if Pos(ArcFlags[J], LowerCase(StrPas(Out.Name))) > 0 then
                        begin
                          Out.ArcMail := 1;
                          Break;
                        end;
                    end;

                    if Line[1] = '^' then
                      Out.DeleteAfter := 1
                    else if Line[1] = '#' then
                      Out.TruncateAfter := 1;

                    if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                      if AddQueue(Out) then
                      begin
                        Inc(TotalSize, Out.Size);
                        Inc(TotalFiles);
                        Added := True;
                      end;
                  end;
                finally
                  Lines.Free;
                end;

                if not Added then
                begin
                  Out.Poll := 1;
                  if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                    if AddQueue(Out) then
                    begin
                      Inc(TotalSize, Out.Size);
                      Inc(TotalFiles);
                    end;
                  Out.Poll := 0;
                end;
              end
              else if (Ext[3] = 'U') and (Ext[4] = 'T') then
              begin
                { Mail packet (.?ut) }
                Out.Point := 0;
                try
                  ParsedNet := StrToInt('$' + Copy(SR2.Name, 1, 4));
                  ParsedNode := StrToInt('$' + Copy(SR2.Name, 5, 4));
                except
                  Continue;
                end;
                Out.Net := ParsedNet;
                Out.Node := ParsedNode;
                Out.Status := UpCase(Ext[2]);

                EntryPath := IncludeTrailingPathDelimiter(AdjustPath(ZoneDir)) + SR2.Name;
                StrPCopy(Out.Complete, AdjustPath(EntryPath));
                StrPCopy(Out.Name, SR2.Name);
                if FileExists(AdjustPath(EntryPath)) then
                  Out.Size := LongWord(GetFileSize(AdjustPath(EntryPath)))
                else
                  Out.Size := 0;
                Out.DeleteAfter := 1;
                Out.MailPKT := 1;
                if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                  if AddQueue(Out) then
                  begin
                    Inc(TotalSize, Out.Size);
                    Inc(TotalFiles);
                  end;
                Out.DeleteAfter := 0;
                Out.MailPKT := 0;
              end
              else if (Ext[2] = 'R') and (Ext[3] = 'E') and (Ext[4] = 'Q') then
              begin
                { File request (.req) }
                Out.Point := 0;
                try
                  ParsedNet := StrToInt('$' + Copy(SR2.Name, 1, 4));
                  ParsedNode := StrToInt('$' + Copy(SR2.Name, 5, 4));
                except
                  Continue;
                end;
                Out.Net := ParsedNet;
                Out.Node := ParsedNode;

                EntryPath := IncludeTrailingPathDelimiter(AdjustPath(ZoneDir)) + SR2.Name;
                StrPCopy(Out.Complete, AdjustPath(EntryPath));
                StrPCopy(Out.Name, SR2.Name);
                if FileExists(AdjustPath(EntryPath)) then
                  Out.Size := LongWord(GetFileSize(AdjustPath(EntryPath)))
                else
                  Out.Size := 0;
                Out.DeleteAfter := 1;
                Out.Request := 1;
                if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                  if AddQueue(Out) then
                  begin
                    Inc(TotalSize, Out.Size);
                    Inc(TotalFiles);
                  end;
                Out.DeleteAfter := 0;
                Out.Request := 0;
              end
              else if (Ext[2] = '$') and (Ext[3] = '$') then
              begin
                { Attempt counter (.$$N) }
                Out.Point := 0;
                try
                  ParsedNet := StrToInt('$' + Copy(SR2.Name, 1, 4));
                  ParsedNode := StrToInt('$' + Copy(SR2.Name, 5, 4));
                except
                  Continue;
                end;
                Out.Net := ParsedNet;
                Out.Node := ParsedNode;

                if AddQueue(Out) then
                begin
                  QPtr := PQUEUE(FNodes.Value);
                  if QPtr <> nil then
                  begin
                    QPtr^.Failed := Ord(Ext[4]) - Ord('0');
                    EntryPath := IncludeTrailingPathDelimiter(AdjustPath(ZoneDir)) + SR2.Name;
                    if FileExists(AdjustPath(EntryPath)) then
                    begin
                      try
                        FD := TFileStream.Create(AdjustPath(EntryPath), fmOpenRead or fmShareDenyNone);
                        try
                          if FD.Size >= 2 then
                          begin
                            FD.Read(AttemptData, 2);
                            QPtr^.Attempts := AttemptData;
                          end;
                          if FD.Size >= 2 + SizeOf(QPtr^.LastCall) then
                            FD.Read(QPtr^.LastCall, SizeOf(QPtr^.LastCall));
                        finally
                          FD.Free;
                        end;
                      except
                      end;
                    end;
                  end;
                end;
              end
              else if (Ext[2] = 'P') and (Ext[3] = 'N') and (Ext[4] = 'T') then
              begin
                { Point subdirectory (.pnt) }
                try
                  ParsedNet := StrToInt('$' + Copy(SR2.Name, 1, 4));
                  ParsedNode := StrToInt('$' + Copy(SR2.Name, 5, 4));
                except
                  Continue;
                end;

                SubPath := IncludeTrailingPathDelimiter(AdjustPath(ZoneDir)) + SR2.Name;
                if FindFirst(IncludeTrailingPathDelimiter(SubPath) + '*', faAnyFile, SR3) = 0 then
                begin
                  try
                    repeat
                      if (SR3.Name = '.') or (SR3.Name = '..') then Continue;
                      Ext := UpperCase(ExtractFileExt(SR3.Name));
                      if Length(Ext) < 4 then Continue;

                      FillChar(Out, SizeOf(Out), 0);
                      Out.Zone := ParsedZone;
                      Out.Net := ParsedNet;
                      Out.Node := ParsedNode;

                      if (Ext[3] = 'L') and (Ext[4] = 'O') then
                      begin
                        { Point file attach }
                        try
                          ParsedPoint := StrToInt('$' + Copy(SR3.Name, 1, 8));
                        except
                          Continue;
                        end;
                        Out.Point := ParsedPoint;
                        Out.Status := UpCase(Ext[2]);
                        Added := False;

                        Lines := TStringList.Create;
                        try
                          Lines.LoadFromFile(IncludeTrailingPathDelimiter(SubPath) + SR3.Name);
                          for I := 0 to Lines.Count - 1 do
                          begin
                            Line := Trim(Lines[I]);
                            if Line = '' then Continue;
                            PFile := Line;
                            if (Line[1] = '^') or (Line[1] = '#') then
                              PFile := Copy(Line, 2, MaxInt);
                            if (PFile = '') or (PFile[1] = '~') then Continue;
                            PFile := AdjustPath(PFile);
                            if not FileExists(PFile) then Continue;

                            StrPCopy(Out.Complete, PFile);
                            StrPCopy(Out.Name, ExtractFileName(PFile));
                            FileSize := GetFileSize(PFile);
                            Out.Size := LongWord(FileSize);
                            Out.MailPKT := 0;
                            Out.ArcMail := 0;
                            Out.DeleteAfter := 0;
                            Out.TruncateAfter := 0;

                            if Pos('.pk', LowerCase(StrPas(Out.Name))) > 0 then
                              Out.MailPKT := 1
                            else
                            begin
                              for J := 0 to 6 do
                                if Pos(ArcFlags[J], LowerCase(StrPas(Out.Name))) > 0 then
                                begin
                                  Out.ArcMail := 1;
                                  Break;
                                end;
                            end;

                            if Line[1] = '^' then
                              Out.DeleteAfter := 1
                            else if Line[1] = '#' then
                              Out.TruncateAfter := 1;

                            if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                              if AddQueue(Out) then
                              begin
                                Inc(TotalSize, Out.Size);
                                Inc(TotalFiles);
                              end;

                            Out.DeleteAfter := 0;
                            Out.TruncateAfter := 0;
                            Out.ArcMail := 0;
                            Out.MailPKT := 0;
                          end;
                        finally
                          Lines.Free;
                        end;

                        if not Added then
                        begin
                          Out.Poll := 1;
                          if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                            if AddQueue(Out) then
                            begin
                              Inc(TotalSize, Out.Size);
                              Inc(TotalFiles);
                            end;
                          Out.Poll := 0;
                        end;
                      end
                      else if (Ext[3] = 'U') and (Ext[4] = 'T') then
                      begin
                        { Point mail packet }
                        try
                          ParsedPoint := StrToInt('$' + Copy(SR3.Name, 1, 8));
                        except
                          Continue;
                        end;
                        Out.Point := ParsedPoint;
                        Out.Status := UpCase(Ext[2]);
                        EntryPath := IncludeTrailingPathDelimiter(SubPath) + SR3.Name;
                        StrPCopy(Out.Complete, AdjustPath(EntryPath));
                        StrPCopy(Out.Name, SR3.Name);
                        if FileExists(AdjustPath(EntryPath)) then
                          Out.Size := LongWord(GetFileSize(AdjustPath(EntryPath)))
                        else
                          Out.Size := 0;
                        Out.DeleteAfter := 1;
                        Out.MailPKT := 1;
                        if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                          if AddQueue(Out) then
                          begin
                            Inc(TotalSize, Out.Size);
                            Inc(TotalFiles);
                          end;
                      end
                      else if (Ext[2] = 'R') and (Ext[3] = 'E') and (Ext[4] = 'Q') then
                      begin
                        { Point file request }
                        try
                          ParsedPoint := StrToInt('$' + Copy(SR3.Name, 1, 8));
                        except
                          Continue;
                        end;
                        Out.Point := ParsedPoint;
                        EntryPath := IncludeTrailingPathDelimiter(SubPath) + SR3.Name;
                        StrPCopy(Out.Complete, AdjustPath(EntryPath));
                        StrPCopy(Out.Name, SR3.Name);
                        if FileExists(AdjustPath(EntryPath)) then
                          Out.Size := LongWord(GetFileSize(AdjustPath(EntryPath)))
                        else
                          Out.Size := 0;
                        Out.DeleteAfter := 1;
                        Out.Request := 1;
                        if FFiles.Add(@Out, SizeOf(Out)) <> 0 then
                          if AddQueue(Out) then
                          begin
                            Inc(TotalSize, Out.Size);
                            Inc(TotalFiles);
                          end;
                      end;
                    until FindNext(SR3) <> 0;
                  finally
                    FindClose(SR3);
                  end;
                end;
              end;
            until FindNext(SR2) <> 0;
          finally
            FindClose(SR2);
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure TOutbound.PollNode(const AAddress: String; Flag: Char);
var
  Addr: TAddress;
  Outb, PollFile, PntDir: String;
  F: TextFile;
begin
  Addr := TAddress.Create;
  try
    Addr.Parse(PChar(AAddress));

    Outb := ExcludeTrailingPathDelimiter(FPath);

    if (Addr.Zone = 0) or (DefaultZone = Addr.Zone) then
    begin
      if Addr.Point <> 0 then
      begin
        PntDir := Format('%s%s%4.4x%4.4x.pnt', [Outb, PathDelim, Addr.Net, Addr.Node]);
        ForceDirectories(PntDir);
        PollFile := Format('%s%s%8.8x.%slo', [PntDir, PathDelim, Addr.Point, Flag]);
      end
      else
        PollFile := Format('%s%s%4.4x%4.4x.%slo', [Outb, PathDelim, Addr.Net, Addr.Node, Flag]);
    end
    else
    begin
      PntDir := Format('%s.%3.3x', [Outb, Addr.Zone]);
      ForceDirectories(PntDir);
      if Addr.Point <> 0 then
      begin
        PntDir := Format('%s.%3.3x%s%4.4x%4.4x.pnt',
          [Outb, Addr.Zone, PathDelim, Addr.Net, Addr.Node]);
        ForceDirectories(PntDir);
        PollFile := Format('%s.%3.3x%s%4.4x%4.4x.pnt%s%8.8x.%slo',
          [Outb, Addr.Zone, PathDelim, Addr.Net, Addr.Node, PathDelim, Addr.Point, Flag]);
      end
      else
        PollFile := Format('%s.%3.3x%s%4.4x%4.4x.%slo',
          [Outb, Addr.Zone, PathDelim, Addr.Net, Addr.Node, Flag]);
    end;

    { Create empty poll file (touch) }
    try
      AssignFile(F, AdjustPath(PollFile));
      Append(F);
      CloseFile(F);
    except
      try
        Rewrite(F);
        CloseFile(F);
      except
      end;
    end;
  finally
    Addr.Free;
  end;
end;

function TOutbound.First: Boolean;
var
  P: POUTFILE;
begin
  P := POUTFILE(FFiles.First);
  if P <> nil then
  begin
    CopyOutToFields(P);
    Result := True;
  end
  else
    Result := False;
end;

function TOutbound.Next: Boolean;
var
  P: POUTFILE;
begin
  P := POUTFILE(FFiles.Next);
  if P <> nil then
  begin
    CopyOutToFields(P);
    Result := True;
  end
  else
    Result := False;
end;

function TOutbound.FirstNode: Boolean;
var
  Q: PQUEUE;
begin
  Q := PQUEUE(FNodes.First);
  if Q <> nil then
  begin
    CopyQueueToFields(Q);
    Result := True;
  end
  else
    Result := False;
end;

function TOutbound.NextNode: Boolean;
var
  Q: PQUEUE;
begin
  Q := PQUEUE(FNodes.Next);
  if Q <> nil then
  begin
    CopyQueueToFields(Q);
    Result := True;
  end
  else
    Result := False;
end;

procedure TOutbound.Remove;
var
  P: POUTFILE;
  Temp: PQUEUE;
  FileName: String;
  More, Stop: Boolean;
  I: Char;
  FD: Integer;
begin
  P := POUTFILE(FFiles.Value);
  if P = nil then Exit;

  { Delete or truncate the file }
  if P^.DeleteAfter <> 0 then
    SysUtils.DeleteFile(AdjustPath(StrPas(P^.Complete)))
  else if P^.TruncateAfter <> 0 then
  begin
    FD := FileCreate(AdjustPath(StrPas(P^.Complete)));
    if FD <> -1 then
      FileClose(FD);
  end;

  Dec(TotalFiles);
  Dec(TotalSize, P^.Size);

  { Update node queue }
  Stop := False;
  Temp := PQUEUE(FNodes.First);
  while (Temp <> nil) and not Stop do
  begin
    if (Temp^.Zone = Zone) and (Temp^.Net = Net) and
       (Temp^.Node = Node) and (Temp^.Point = Point) and
       (StrIComp(Temp^.Domain, PChar(Domain)) = 0) then
    begin
      Dec(Temp^.Files);
      Dec(Temp^.Size, P^.Size);
      if Temp^.Files = 0 then
      begin
        FNodes.Remove;
        Dec(TotalNodes);
      end;
      Stop := True;
    end;
    if not Stop then
      Temp := PQUEUE(FNodes.Next);
  end;

  FFiles.Remove;

  { Clean up .?lo and .$$? files if no more file attaches for this node }
  if (not MailPKT) and (not Request) then
  begin
    More := False;
    P := POUTFILE(FFiles.First);
    while (P <> nil) and not More do
    begin
      if (P^.MailPKT = 0) and (P^.Request = 0) and (P^.Status = Status) and
         (P^.Zone = Zone) and (P^.Net = Net) and (P^.Node = Node) and
         (P^.Point = Point) and (StrIComp(P^.Domain, PChar(Domain)) = 0) then
        More := True;
      if not More then
        P := POUTFILE(FFiles.Next);
    end;

    if not More then
    begin
      FOutbound := FPath;
      if Zone <> DefaultZone then
        FOutbound := ExcludeTrailingPathDelimiter(FOutbound) +
          Format('.%3.3x%s', [Zone, PathDelim]);

      if Point <> 0 then
        FileName := Format('%s%4.4x%4.4x.PNT%s%8.8x.%sLO',
          [FOutbound, Net, Node, PathDelim, Point, Status])
      else
        FileName := Format('%s%4.4x%4.4x.%sLO',
          [FOutbound, Net, Node, Status]);
      SysUtils.DeleteFile(AdjustPath(FileName));

      for I := '0' to '9' do
      begin
        if Point <> 0 then
          FileName := Format('%s%4.4x%4.4x.PNT%s%8.8x.$$%s',
            [FOutbound, Net, Node, PathDelim, Point, I])
        else
          FileName := Format('%s%4.4x%4.4x.$$%s',
            [FOutbound, Net, Node, I]);
        SysUtils.DeleteFile(AdjustPath(FileName));
      end;
    end;
  end;
end;

procedure TOutbound.AddAttempt(const AAddress: String; AFailed: Boolean;
  const AStatus: String);
var
  Addr: TAddress;
  FileName: String;
  I: Char;
  AttemptCount: Word;
  StatusBuf: array[0..31] of Char;
  FD: TFileStream;
  QPtr, Current: PQUEUE;
begin
  Addr := TAddress.Create;
  try
    Addr.Parse(PChar(AAddress));

    FOutbound := FPath;
    if Addr.Zone <> DefaultZone then
      FOutbound := ExcludeTrailingPathDelimiter(FOutbound) +
        Format('.%3.3x%s', [Addr.Zone, PathDelim]);

    AttemptCount := 0;
    FillChar(StatusBuf, SizeOf(StatusBuf), 0);
    I := '0';

    { Find existing attempt file }
    while I <= '9' do
    begin
      if Addr.Point <> 0 then
        FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.$$%s',
          [FOutbound, Addr.Net, Addr.Node, PathDelim, Addr.Point, I])
      else
        FileName := Format('%s%4.4x%4.4x.$$%s',
          [FOutbound, Addr.Net, Addr.Node, I]);
      FileName := AdjustPath(FileName);

      if FileExists(FileName) then
      begin
        try
          FD := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
          try
            if FD.Size >= 2 then
              FD.Read(AttemptCount, 2);
            if FD.Size >= 2 + SizeOf(StatusBuf) then
              FD.Read(StatusBuf, SizeOf(StatusBuf));
          finally
            FD.Free;
          end;
        except
        end;
        Break;
      end;
      Inc(I);
    end;

    if I > '9' then
      I := '0';

    if AFailed and (I < '9') then
    begin
      SysUtils.DeleteFile(FileName);
      Inc(I);
    end;

    if Addr.Point <> 0 then
      FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.$$%s',
        [FOutbound, Addr.Net, Addr.Node, PathDelim, Addr.Point, I])
    else
      FileName := Format('%s%4.4x%4.4x.$$%s',
        [FOutbound, Addr.Net, Addr.Node, I]);
    FileName := AdjustPath(FileName);

    FillChar(StatusBuf, SizeOf(StatusBuf), 0);
    StrPCopy(StatusBuf, AStatus);
    Inc(AttemptCount);

    try
      FD := TFileStream.Create(FileName, fmCreate);
      try
        FD.Write(AttemptCount, 2);
        FD.Write(StatusBuf, SizeOf(StatusBuf));
      finally
        FD.Free;
      end;
    except
    end;

    { Update queue }
    Current := PQUEUE(FNodes.Value);
    QPtr := PQUEUE(FNodes.First);
    while QPtr <> nil do
    begin
      if (Addr.Zone = QPtr^.Zone) and (Addr.Net = QPtr^.Net) and
         (Addr.Node = QPtr^.Node) and (Addr.Point = QPtr^.Point) then
      begin
        QPtr^.Attempts := AttemptCount;
        QPtr^.Failed := Ord(I) - Ord('0');
        FillChar(QPtr^.LastCall, SizeOf(QPtr^.LastCall), 0);
        StrPCopy(QPtr^.LastCall, AStatus);
        Break;
      end;
      QPtr := PQUEUE(FNodes.Next);
    end;

    { Restore current position }
    QPtr := PQUEUE(FNodes.First);
    while QPtr <> nil do
    begin
      if QPtr = Current then Break;
      QPtr := PQUEUE(FNodes.Next);
    end;
  finally
    Addr.Free;
  end;
end;

procedure TOutbound.ClearAttempt(const AAddress: String);
var
  Addr: TAddress;
  FileName: String;
  I: Char;
  QPtr, Current: PQUEUE;
begin
  Addr := TAddress.Create;
  try
    Addr.Parse(PChar(AAddress));

    FOutbound := FPath;
    if Addr.Zone <> DefaultZone then
      FOutbound := ExcludeTrailingPathDelimiter(FOutbound) +
        Format('.%3.3x%s', [Addr.Zone, PathDelim]);

    for I := '0' to '9' do
    begin
      if Addr.Point <> 0 then
        FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.$$%s',
          [FOutbound, Addr.Net, Addr.Node, PathDelim, Addr.Point, I])
      else
        FileName := Format('%s%4.4x%4.4x.$$%s',
          [FOutbound, Addr.Net, Addr.Node, I]);
      SysUtils.DeleteFile(AdjustPath(FileName));
    end;

    { Update queue }
    Current := PQUEUE(FNodes.Value);
    QPtr := PQUEUE(FNodes.First);
    while QPtr <> nil do
    begin
      if (Addr.Zone = QPtr^.Zone) and (Addr.Net = QPtr^.Net) and
         (Addr.Node = QPtr^.Node) and (Addr.Point = QPtr^.Point) then
      begin
        QPtr^.Attempts := 0;
        QPtr^.Failed := 0;
        FillChar(QPtr^.LastCall, SizeOf(QPtr^.LastCall), 0);
        Break;
      end;
      QPtr := PQUEUE(FNodes.Next);
    end;

    { Restore current position }
    QPtr := PQUEUE(FNodes.First);
    while QPtr <> nil do
    begin
      if QPtr = Current then Break;
      QPtr := PQUEUE(FNodes.Next);
    end;
  finally
    Addr.Free;
  end;
end;

procedure TOutbound.Update;
var
  FileName, OutDir, PntDir: String;
  I: Char;
  FD: TFileStream;
  F: TextFile;
begin
  { First pass: clear all attempt files }
  if FirstNode then
    repeat
      FOutbound := FPath;
      if Zone <> DefaultZone then
        FOutbound := ExcludeTrailingPathDelimiter(FOutbound) +
          Format('.%3.3x%s', [Zone, PathDelim]);
      for I := '0' to '9' do
      begin
        if Point <> 0 then
          FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.$$%s',
            [FOutbound, Net, Node, PathDelim, Point, I])
        else
          FileName := Format('%s%4.4x%4.4x.$$%s',
            [FOutbound, Net, Node, I]);
        SysUtils.DeleteFile(AdjustPath(FileName));
      end;
    until not NextNode;

  { Second pass: delete all .?lo files }
  if First then
    repeat
      if (not MailPKT) and (not Request) then
      begin
        FOutbound := FPath;
        if Zone <> DefaultZone then
          FOutbound := ExcludeTrailingPathDelimiter(FOutbound) +
            Format('.%3.3x%s', [Zone, PathDelim]);
        if Point <> 0 then
          FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.%slo',
            [FOutbound, Net, Node, PathDelim, Point, Status])
        else
          FileName := Format('%s%4.4x%4.4x.%slo',
            [FOutbound, Net, Node, Status]);
        SysUtils.DeleteFile(AdjustPath(FileName));
      end;
    until not Next;

  { Third pass: write attempt files }
  if FirstNode then
    repeat
      if (Attempts <> 0) or (Failed <> 0) then
      begin
        FOutbound := FPath;
        if Zone <> DefaultZone then
          FOutbound := ExcludeTrailingPathDelimiter(FOutbound) +
            Format('.%3.3x%s', [Zone, PathDelim]);
        if Point <> 0 then
          FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.$$%s',
            [FOutbound, Net, Node, PathDelim, Point, Chr(Failed + Ord('0'))])
        else
          FileName := Format('%s%4.4x%4.4x.$$%s',
            [FOutbound, Net, Node, Chr(Failed + Ord('0'))]);
        try
          FD := TFileStream.Create(AdjustPath(FileName), fmCreate);
          try
            FD.Write(Attempts, 2);
          finally
            FD.Free;
          end;
        except
        end;
      end;
    until not NextNode;

  { Fourth pass: write .?lo attach files }
  if First then
    repeat
      if (not MailPKT) and (not Request) then
      begin
        FOutbound := FPath;
        if Zone <> DefaultZone then
        begin
          OutDir := ExcludeTrailingPathDelimiter(FOutbound) +
            Format('.%3.3x', [Zone]);
          ForceDirectories(OutDir);
          FOutbound := OutDir + PathDelim;
        end;

        if Point <> 0 then
        begin
          PntDir := Format('%s%4.4x%4.4x.pnt', [FOutbound, Net, Node]);
          ForceDirectories(PntDir);
          FileName := Format('%s%4.4x%4.4x.pnt%s%8.8x.%slo',
            [FOutbound, Net, Node, PathDelim, Point, Status]);
        end
        else
          FileName := Format('%s%4.4x%4.4x.%slo',
            [FOutbound, Net, Node, Status]);

        try
          AssignFile(F, AdjustPath(FileName));
          if FileExists(AdjustPath(FileName)) then
            Append(F)
          else
            Rewrite(F);
          try
            if TruncateAfter then
              WriteLn(F, '#' + Complete)
            else if DeleteAfter then
              WriteLn(F, '^' + Complete)
            else if not Poll then
              WriteLn(F, Complete);
          finally
            CloseFile(F);
          end;
        except
        end;
      end;
    until not Next;
end;

end.
