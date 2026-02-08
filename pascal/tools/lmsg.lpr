{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of lmsg.cpp
  Message maintenance utility
}

program LMsg;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Classes, DateUtils, Collect, Defs, Struc299,
  Config, MsgData, MsgBase, JamMsg, Squish, FidoSdm, Adept, Hudson;

const
  PROG_NAME    = 'FastWay BBS';
  PROG_VERSION = '1.0.0';
  MSGTAGS_INDEX = 32;

var
  Cfg: TConfig;

type
  MSGLINK = packed record
    Subject: LongWord;
    Number: LongWord;
  end;

procedure UpdateLastread(const Area: string; TotalMsgs: LongWord; Active: PLongWord);
var
  fs: TFileStream;
  Buffer: array[0..MSGTAGS_INDEX - 1] of MSGTAGS;
  i, m, Count: Integer;
  Changed: Boolean;
  Position: Int64;
  LastRead_: LongWord;
begin
  if not FileExists('msgtags.dat') then Exit;

  try
    fs := TFileStream.Create('msgtags.dat', fmOpenReadWrite or fmShareDenyNone);
    try
      while fs.Position < fs.Size do
      begin
        Changed := False;
        Position := fs.Position;
        Count := fs.Read(Buffer, SizeOf(MSGTAGS) * MSGTAGS_INDEX) div SizeOf(MSGTAGS);

        for i := 0 to Count - 1 do
        begin
          if (Buffer[i].Free = 0) and (StrPas(Buffer[i].Area) = Area) then
          begin
            LastRead_ := 0;
            for m := 0 to Integer(TotalMsgs) - 1 do
            begin
              if (PLongWord(PByte(Active) + m * SizeOf(LongWord))^ <> 0) and
                 (PLongWord(PByte(Active) + m * SizeOf(LongWord))^ <= Buffer[i].LastRead) then
                LastRead_ := PLongWord(PByte(Active) + m * SizeOf(LongWord))^;
            end;
            if Buffer[i].LastRead <> LastRead_ then
            begin
              Buffer[i].LastRead := LastRead_;
              Changed := True;
            end;
          end;
        end;

        if Changed then
        begin
          fs.Position := Position;
          fs.Write(Buffer, SizeOf(MSGTAGS) * Count);
        end;
      end;
    finally
      fs.Free;
    end;
  except
  end;
end;

function CreateMsgBase(Storage: Byte; const Path: string; Board: Byte): TMsgBase;
begin
  Result := nil;
  case Storage of
    ST_JAM:    begin Result := TJamMsg.Create; TJamMsg(Result).Open(Path); end;
    ST_SQUISH: begin Result := TSquish.Create; TSquish(Result).Open(Path); end;
    ST_FIDO:   begin Result := TFidoSdm.Create; TFidoSdm(Result).Open(Path); end;
    ST_ADEPT:  begin Result := TAdept.Create; TAdept(Result).Open(Path); end;
    ST_HUDSON: begin Result := THudson.Create; THudson(Result).Open(Path, Board); end;
  end;
end;

procedure PurgeMessages(const Area: string; WriteDate: Boolean);
var
  i: Integer;
  Deleted: Word;
  Done: Boolean;
  Number_, Highest_, TotalMsgs, Counter: LongWord;
  Today, MsgDate: LongInt;
  Active: array of LongWord;
  Data: TMsgData;
  Msg: TMsgBase;
  yr, mo, dy, hr, mn, sc: Word;
begin
  WriteLn(' * Purging Messages');
  Today := DateTimeToUnix(Now) div 86400;

  Data := TMsgData.Create;
  try
    if Data.Open(Cfg.SystemPath) and Data.First then
    repeat
      if Area <> '' then
        if not Data.Read(Area) then Break;

      Msg := CreateMsgBase(Data.Storage, Data.Path, Data.Board);
      if Msg <> nil then
      try
        Write(Format(' +-- %-15s %-29s ', [Data.Key, Data.Display]));
        Msg.Lock(0);

        Counter := 0;
        Deleted := 0;
        TotalMsgs := Msg.Number;

        SetLength(Active, 0);
        if TotalMsgs > 0 then
        begin
          SetLength(Active, TotalMsgs + 100);
          i := 0;
          Number_ := Msg.Lowest;
          repeat
            Active[i] := Number_;
            Inc(i);
          until not Msg.Next(Number_);
        end;

        if (Data.DaysOld <> 0) or (Data.MaxMessages <> 0) then
        begin
          Number_ := Msg.Lowest;
          Highest_ := Msg.Highest;

          repeat
            if (Counter mod 10) = 0 then
              Write(Format('%6u / %6u'#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8, [Counter, TotalMsgs]));
            Inc(Counter);

            if Msg.ReadHeader(Number_) then
            begin
              Done := False;
              if Data.DaysOld <> 0 then
              begin
                if WriteDate then
                begin
                  yr := Msg.Written.Year; mo := Msg.Written.Month; dy := Msg.Written.Day;
                  hr := Msg.Written.Hour; mn := Msg.Written.Minute; sc := Msg.Written.Second;
                end
                else
                begin
                  yr := Msg.Arrived.Year; mo := Msg.Arrived.Month; dy := Msg.Arrived.Day;
                  hr := Msg.Arrived.Hour; mn := Msg.Arrived.Minute; sc := Msg.Arrived.Second;
                end;

                try
                  if (mo >= 1) and (mo <= 12) and (dy >= 1) and (dy <= 31) and (yr >= 1970) then
                    MsgDate := DateTimeToUnix(EncodeDate(yr, mo, dy)) div 86400
                  else
                    MsgDate := Today;
                except
                  MsgDate := Today;
                end;

                if (Today - MsgDate) > Data.DaysOld then
                begin
                  Msg.Delete(Number_);
                  Done := True;
                  Inc(Deleted);
                  for i := 0 to Integer(TotalMsgs) - 1 do
                    if Active[i] = Number_ then Active[i] := 0;
                end;
              end;

              if (not Done) and (Data.MaxMessages <> 0) and (Msg.Number > Data.MaxMessages) then
              begin
                Msg.Delete(Number_);
                Inc(Deleted);
                for i := 0 to Integer(TotalMsgs) - 1 do
                  if Active[i] = Number_ then Active[i] := 0;
              end;
            end;
          until not Msg.Next(Number_);
          Write(Format('%6u / %6u'#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8, [Counter, TotalMsgs]));
        end;

        WriteLn(Format('Total: %5u, Deleted: %5u', [TotalMsgs, Deleted]));
        Msg.UnLock;

        if Deleted > 0 then
        begin
          Data.ActiveMsgs := Msg.Number;
          Data.FirstMessage := Msg.Lowest;
          Data.LastMessage := Msg.Highest;
          Data.Update;
          if Length(Active) > 0 then
            UpdateLastread(Data.Key, TotalMsgs, @Active[0]);
        end;
      finally
        Msg.Free;
      end;

      if Area <> '' then Break;
    until not Data.Next;
  finally
    Data.Free;
  end;
end;

procedure PackMessages(const Area: string);
var
  Skip: Boolean;
  p: PChar;
  Data: TMsgData;
  Msg: TMsgBase;
  DoneList: TCollection;
begin
  WriteLn(' * Pack (Compressing) Messages');

  DoneList := TCollection.Create;
  try
    Data := TMsgData.Create;
    try
      if Data.Open(Cfg.SystemPath) and Data.First then
      repeat
        if Area <> '' then
          if not Data.Read(Area) then Break;

        Msg := nil;
        if Data.Storage = ST_HUDSON then
        begin
          { Only pack each Hudson base path once }
          Skip := False;
          p := PChar(DoneList.First);
          while p <> nil do
          begin
            if SameText(StrPas(p), Data.Path) then
            begin
              Skip := True;
              Break;
            end;
            p := PChar(DoneList.Next);
          end;
          if not Skip then
          begin
            DoneList.Add(PChar(Data.Path));
            Msg := CreateMsgBase(ST_HUDSON, Data.Path, Data.Board);
          end;
        end
        else
          Msg := CreateMsgBase(Data.Storage, Data.Path, Data.Board);

        if Msg <> nil then
        try
          Write(Format(' +-- %-15s %-49s ', [Data.Key, Data.Display]));
          Msg.Pack;
          if Data.Storage <> ST_HUDSON then
          begin
            Data.ActiveMsgs := Msg.Number;
            Data.FirstMessage := Msg.Lowest;
            Data.LastMessage := Msg.Highest;
            Data.Update;
          end;
          WriteLn;
        finally
          Msg.Free;
        end;

        if Area <> '' then Break;
      until not Data.Next;
    finally
      Data.Free;
    end;
  finally
    DoneList.Free;
  end;
end;

procedure LinkMessages(const Area: string);
var
  i, m: Integer;
  Number_, Prev, Next, Crc, Total: LongWord;
  Temp: string;
  Link: array of MSGLINK;
  Data: TMsgData;
  Msg: TMsgBase;
begin
  WriteLn(' * Reply-linking Messages');

  Data := TMsgData.Create;
  try
    if Data.Open(Cfg.SystemPath) and Data.First then
    repeat
      if Area <> '' then
        if not Data.Read(Area) then Break;

      Msg := CreateMsgBase(Data.Storage, Data.Path, Data.Board);
      if Msg <> nil then
      try
        Write(Format(' +-- %-15s %-40s ', [Data.Key, Data.Display]));
        Total := Msg.Number;
        if Total > 0 then
        begin
          Msg.Lock(0);
          SetLength(Link, Total);
          FillChar(Link[0], Total * SizeOf(MSGLINK), 0);

          { First pass: collect subjects }
          Number_ := Msg.Lowest;
          i := 0;
          repeat
            Msg.ReadHeader(Number_);
            Temp := UpperCase(StrPas(Msg.Subject_));
            if Copy(Temp, 1, 3) = 'RE:' then
            begin
              System.Delete(Temp, 1, 3);
              Temp := TrimLeft(Temp);
            end;
            Link[i].Subject := StringCrc32(PChar(Temp), $FFFFFFFF);
            Link[i].Number := Number_;
            Inc(i);
            if (i mod 10) = 0 then
              Write(Format('%6u / %6u'#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8, [i, Total]));
          until not Msg.Next(Number_);
          Write(Format('%6u / %6u'#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8, [i, Total]));

          { Second pass: link by subject CRC }
          Number_ := Msg.Lowest;
          i := 0;
          repeat
            Msg.ReadHeader(Number_);
            Prev := 0; Next := 0;
            Crc := Link[i].Subject;

            for m := 0 to Integer(Total) - 1 do
            begin
              if m = i then Continue;
              if Link[m].Subject = Crc then
              begin
                if m < i then
                  Prev := Link[m].Number
                else
                begin
                  Next := Link[m].Number;
                  Break;
                end;
              end;
            end;

            if (i mod 10) = 0 then
              Write(Format('%6u / %6u'#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8, [i, Total]));

            if (Msg.Original <> Prev) or (Msg.Reply <> Next) then
            begin
              Msg.Original := Prev;
              Msg.Reply := Next;
              Msg.WriteHeader(Number_);
            end;

            Inc(i);
          until not Msg.Next(Number_);
          Write(Format('%6u / %6u'#8#8#8#8#8#8#8#8#8#8#8#8#8#8#8, [i, Total]));

          SetLength(Link, 0);
          Msg.UnLock;
        end;
        WriteLn;
      finally
        Msg.Free;
      end;

      if Area <> '' then Break;
    until not Data.Next;
  finally
    Data.Free;
  end;
end;

procedure ReindexMessages;
var
  Data: TMsgData;
  Msg: TMsgBase;
begin
  WriteLn(' * Indexing Messages');

  Data := TMsgData.Create;
  try
    if Data.Open(Cfg.SystemPath) and Data.First then
    repeat
      Msg := CreateMsgBase(Data.Storage, Data.Path, Data.Board);
      if Msg <> nil then
      try
        Write(Format(' +-- %-15s %-29s ', [Data.Key, Data.Display]));
        Data.ActiveMsgs := Msg.Number;
        Data.FirstMessage := Msg.Lowest;
        Data.LastMessage := Msg.Highest;
        Data.Update;
        WriteLn(Format('Total: %5u, First: %5u', [Data.ActiveMsgs, Data.FirstMessage]));
      finally
        Msg.Free;
      end;
    until not Data.Next;
  finally
    Data.Free;
  end;
end;

procedure ImportDescriptions(const FileName: string);
var
  fp: TextFile;
  Temp, Tag, Desc: string;
  Counter, Existing: Integer;
  SpacePos: Integer;
  MsgDataObj: TMsgData;
begin
  Counter := 0;
  Existing := 0;
  WriteLn(Format(' * Import descriptions from %s', [FileName]));

  AssignFile(fp, FileName);
  {$I-}
  Reset(fp);
  {$I+}
  if IOResult <> 0 then begin WriteLn(' Error opening file'); Exit; end;

  MsgDataObj := TMsgData.Create;
  try
    if MsgDataObj.Open(Cfg.SystemPath) then
    begin
      while not EOF(fp) do
      begin
        ReadLn(fp, Temp);
        if (Length(Temp) = 0) or (Temp[1] = ';') then Continue;

        SpacePos := Pos(' ', Temp);
        if SpacePos > 0 then
        begin
          Tag := Copy(Temp, 1, SpacePos - 1);
          Desc := TrimLeft(Copy(Temp, SpacePos + 1, Length(Temp)));
          if MsgDataObj.ReadEcho(Tag) then
          begin
            MsgDataObj.Display := Desc;
            MsgDataObj.Update;
            Inc(Existing);
          end;
          Inc(Counter);
        end;
      end;
    end;
  finally
    MsgDataObj.Free;
  end;

  CloseFile(fp);
  WriteLn(Format('   %d area(s) read, %d updated', [Counter, Existing]));
end;

procedure ExportDescriptions(const FileName: string);
var
  fp: TextFile;
  Counter: Integer;
  MsgDataObj: TMsgData;
begin
  Counter := 0;
  WriteLn(Format(' * Updating %s', [FileName]));

  AssignFile(fp, FileName);
  {$I-}
  Rewrite(fp);
  {$I+}
  if IOResult <> 0 then begin WriteLn(' Error creating file'); Exit; end;

  MsgDataObj := TMsgData.Create;
  try
    if MsgDataObj.Open(Cfg.SystemPath) and MsgDataObj.First then
    repeat
      if MsgDataObj.EchoMail and (MsgDataObj.EchoTag <> '') then
      begin
        WriteLn(fp, Format('%-24s %s', [MsgDataObj.EchoTag, MsgDataObj.Display]));
        Inc(Counter);
      end;
    until not MsgDataObj.Next;
  finally
    MsgDataObj.Free;
  end;

  CloseFile(fp);
  WriteLn(Format('   %d description(s) exported', [Counter]));
end;

var
  i: Integer;
  DoPurge, DoPack, DoReindex, DoLink, DoWriteDate: Boolean;
  DoImport, DoExport: Word;
  Area, ConfigFile, DescFile: string;
begin
  DoImport := 0; DoExport := 0;
  DoPurge := False; DoPack := False;
  DoReindex := False; DoLink := False;
  DoWriteDate := False;
  Area := ''; ConfigFile := ''; DescFile := '';

  WriteLn;
  WriteLn(Format('LMSG; %s v%s - Message maintenance utility', [PROG_NAME, PROG_VERSION]));
  WriteLn('      Based on LoraBBS by Marco Maccaferri. GPL v2 Licensed.');
  WriteLn;

  if ParamCount = 0 then
  begin
    WriteLn(' * Command-line parameters:');
    WriteLn;
    WriteLn('        -A<key>     Process the area <key> only');
    WriteLn('        -I          Recreate index files');
    WriteLn('        -P[K]       Pack (compress) message base');
    WriteLn('                    K=Purge');
    WriteLn('        -K[W]       Purge messages from info in MSG.DAT');
    WriteLn('                    W=Use write date');
    WriteLn('        -L          Link messages by subject');
    WriteLn('        -E[D]<file> Export data from MSG.DAT');
    WriteLn('                    D=Echomail descriptions');
    WriteLn('        -R[D]<file> Import data to MSG.DAT');
    WriteLn('                    D=Echomail descriptions');
    WriteLn;
    WriteLn(' * Please refer to the documentation for a more complete command summary');
    WriteLn;
  end
  else
  begin
    for i := 1 to ParamCount do
    begin
      if (Length(ParamStr(i)) >= 2) and ((ParamStr(i)[1] = '-') or (ParamStr(i)[1] = '/')) then
      begin
        case UpCase(ParamStr(i)[2]) of
          'A': Area := Copy(ParamStr(i), 3, Length(ParamStr(i)));
          'K': begin DoPurge := True; if (Length(ParamStr(i)) >= 3) and (UpCase(ParamStr(i)[3]) = 'W') then DoWriteDate := True; end;
          'P': begin DoPack := True; if (Length(ParamStr(i)) >= 3) and (UpCase(ParamStr(i)[3]) = 'K') then DoPurge := True; end;
          'I': DoReindex := True;
          'L': DoLink := True;
          'R': if (Length(ParamStr(i)) >= 3) and (UpCase(ParamStr(i)[3]) = 'D') then
               begin DoImport := 1; DescFile := Copy(ParamStr(i), 4, Length(ParamStr(i))); end;
          'E': if (Length(ParamStr(i)) >= 3) and (UpCase(ParamStr(i)[3]) = 'D') then
               begin DoExport := 1; DescFile := Copy(ParamStr(i), 4, Length(ParamStr(i))); end;
        end;
      end
      else if ConfigFile = '' then
        ConfigFile := ParamStr(i);
    end;

    Cfg := TConfig.Create;
    try
      if not Cfg.Load(ConfigFile) then
        Cfg.Default;

      if DoExport = 1 then ExportDescriptions(DescFile);
      if DoImport = 1 then ImportDescriptions(DescFile);
      if DoReindex then ReindexMessages;
      if DoPurge then PurgeMessages(Area, DoWriteDate);
      if DoPack then PackMessages(Area);
      if DoLink then LinkMessages(Area);

      if DoPurge or DoPack or DoReindex or DoLink or (DoImport <> 0) or (DoExport <> 0) then
        WriteLn(' * Done')
      else
        WriteLn(' * Nothing to do');
      WriteLn;
    finally
      Cfg.Free;
    end;
  end;
end.
