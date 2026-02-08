{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  FreePascal conversion of lfile.cpp
  File maintenance utility
}

program LFile;

{$MODE OBJFPC}
{$H+}

uses
  SysUtils, Classes, DateUtils, Collect, Defs, Struc299,
  Config, FileData, FileBase, Packer;

const
  PROG_NAME    = 'FastWay BBS';
  PROG_VERSION = '1.0.0';

var
  Symbol: Char = '>';
  Column: Word = 1;
  Cfg: TConfig;

procedure ExportFilesBBS;
var
  fp: TextFile;
  i: Word;
  Path: string;
  Total: LongWord;
  p: PChar;
  Data: TFileData;
  F: TFileBase;
begin
  WriteLn(' * Export to FILES.BBS');

  Data := TFileData.Create;
  try
    if Data.Open(Cfg.SystemPath) and Data.First then
    repeat
      Total := 0;
      Write(Format(' +-- %-15s %-45s ', [Data.Key, Data.Display]));
      F := TFileBase.Create;
      try
        if F.Open(Cfg.SystemPath, Data.Key) then
        begin
          Path := Data.Download + 'files.bbs';
          AssignFile(fp, Path);
          try
            Rewrite(fp);
            F.SortByName;
            if F.First then
            repeat
              Inc(Total);
              p := PChar(F.Description.First);
              if p = nil then
                WriteLn(fp, Format('%-12s (%3u) ', [F.Name, F.DlTimes]))
              else
                WriteLn(fp, Format('%-12s (%3u) %s', [F.Name, F.DlTimes, StrPas(p)]));
              p := PChar(F.Description.Next);
              while p <> nil do
              begin
                for i := 1 to Column do
                  Write(fp, ' ');
                WriteLn(fp, Symbol, StrPas(p));
                p := PChar(F.Description.Next);
              end;
            until not F.Next;
            CloseFile(fp);
          except
          end;
        end;
      finally
        F.Free;
      end;
      WriteLn(Format('Total: %5u', [Total]));
    until not Data.Next;
  finally
    Data.Free;
  end;
end;

procedure ImportFilesBBS;
var
  fp: TextFile;
  PendingWrite: Boolean;
  Total: LongWord;
  Path, Temp, NameStr: string;
  p: PChar;
  SR: TSearchRec;
  FileAge_: TDateTime;
  yr, mo, dy, hr, mn, sc, ms: Word;
  Data: TFileData;
  F: TFileBase;
begin
  WriteLn(' * Import from FILES.BBS');

  SysUtils.DeleteFile('filebase.dat');
  SysUtils.DeleteFile('filebase.idx');

  Data := TFileData.Create;
  try
    if Data.Open(Cfg.SystemPath) and Data.First then
    repeat
      PendingWrite := False;
      Total := 0;
      Write(Format(' +-- %-15s %-45s ', [Data.Key, Data.Display]));
      F := TFileBase.Create;
      try
        if F.Open(Cfg.SystemPath, Data.Key) then
        begin
          Path := Data.Download + 'files.bbs';
          AssignFile(fp, Path);
          {$I-}
          Reset(fp);
          {$I+}
          if IOResult = 0 then
          begin
            while not EOF(fp) do
            begin
              ReadLn(fp, Temp);
              if (Length(Temp) > 0) and (Temp[1] <> ' ') and (Temp[1] <> #9) then
              begin
                if PendingWrite then
                begin
                  F.Add;
                  Inc(Total);
                  F.Clear;
                  PendingWrite := False;
                end;
                { Parse filename and description }
                NameStr := '';
                p := PChar(Temp);
                while (p^ <> #0) and (p^ <> ' ') do
                begin
                  NameStr := NameStr + p^;
                  Inc(p);
                end;
                while p^ = ' ' do Inc(p);
                if p^ <> #0 then
                begin
                  { Check for download count in parens/brackets }
                  if (p^ = '(') or (p^ = '[') then
                  begin
                    Inc(p);
                    while (p^ <> ')') and (p^ <> ']') and (p^ <> #0) do
                    begin
                      if p^ in ['0'..'9'] then
                        F.DlTimes := F.DlTimes * 10 + (Ord(p^) - Ord('0'));
                      Inc(p);
                    end;
                    if (p^ = ')') or (p^ = ']') then
                    begin
                      Inc(p);
                      while p^ = ' ' do Inc(p);
                    end;
                  end;
                  if p^ <> #0 then
                    F.Description.Add(p);
                end;
                Path := Data.Download + NameStr;
                {$IFDEF UNIX}
                Path := LowerCase(Path);
                {$ENDIF}
                if FindFirst(Path, faAnyFile, SR) = 0 then
                begin
                  F.Area := Data.Key;
                  F.Name := NameStr;
                  F.Complete := Data.Download + NameStr;
                  F.Size_ := SR.Size;
                  FileAge_ := FileDateToDateTime(SR.Time);
                  DecodeDate(FileAge_, yr, mo, dy);
                  DecodeTime(FileAge_, hr, mn, sc, ms);
                  F.UplDate.Day := dy; F.Date_.Day := dy;
                  F.UplDate.Month := mo; F.Date_.Month := mo;
                  F.UplDate.Year := yr; F.Date_.Year := yr;
                  F.UplDate.Hour := hr; F.Date_.Hour := hr;
                  F.UplDate.Minute := mn; F.Date_.Minute := mn;
                  F.Uploader := 'Sysop';
                  F.CdRom := Data.CdRom;
                  PendingWrite := True;
                  FindClose(SR);
                end
                else
                  F.Clear;
              end
              else if PendingWrite then
              begin
                { Continuation line }
                Temp := TrimLeft(Temp);
                if (Length(Temp) > 0) and ((Temp[1] = '>') or (Temp[1] = '|') or (Temp[1] = '+')) then
                  F.Description.Add(PChar(Copy(Temp, 2, Length(Temp))));
              end;
            end;
            CloseFile(fp);

            if PendingWrite then
            begin
              F.Add;
              F.Clear;
              Inc(Total);
            end;
          end
          else
            WriteLn('Error');

          F.Close;
          Data.ActiveFiles := Total;
          Data.Update;
        end;
      finally
        F.Free;
      end;
      WriteLn(Format('Total: %5u', [Total]));
    until not Data.Next;
  finally
    Data.Free;
  end;
end;

procedure PurgeFiles(DaysOld: Word);
var
  Total, Deleted: LongWord;
  Today, FileDate: LongInt;
  Data: TFileData;
  F: TFileBase;
begin
  WriteLn(' * Purging Files');
  Today := DateTimeToUnix(Now) div 86400;

  Data := TFileData.Create;
  try
    if Data.Open(Cfg.SystemPath) and Data.First then
    repeat
      Deleted := 0;
      Total := 0;
      Write(Format(' +-- %-15s %-29s ', [Data.Key, Data.Display]));
      F := TFileBase.Create;
      try
        if F.Open(Cfg.SystemPath, Data.Key) then
        begin
          if F.First then
          repeat
            Inc(Total);
            try
              FileDate := DateTimeToUnix(EncodeDate(F.UplDate.Year, F.UplDate.Month, F.UplDate.Day)) div 86400;
              if (Today - FileDate) > DaysOld then
              begin
                SysUtils.DeleteFile(F.Complete);
                F.Delete;
                Inc(Deleted);
              end;
            except
            end;
          until not F.Next;
        end;
      finally
        F.Free;
      end;
      WriteLn(Format('Total: %5u, Deleted: %5u', [Total, Deleted]));
    until not Data.Next;
  finally
    Data.Free;
  end;
end;

procedure PackFilebase;
var
  F: TFileBase;
begin
  WriteLn(' * Packing (Compressing) Filebase');

  F := TFileBase.Create;
  try
    if F.Open(Cfg.SystemPath, '') then
    begin
      F.Pack;
      F.Close;
    end;
  finally
    F.Free;
  end;
end;

procedure CreateFilesList;
var
  fp: TextFile;
  p: PChar;
  Data: TFileData;
  F: TFileBase;
begin
  WriteLn(' * Creating List of Files (bbslist.txt)');

  AssignFile(fp, 'bbslist.txt');
  {$I-}
  Rewrite(fp);
  {$I+}
  if IOResult <> 0 then Exit;

  Data := TFileData.Create;
  try
    if Data.Open(Cfg.SystemPath) and Data.First then
    repeat
      Write(Format(' +-- %-15s %-29s ', [Data.Key, Data.Display]));
      F := TFileBase.Create;
      try
        if F.Open(Cfg.SystemPath, Data.Key) then
        begin
          F.SortByName;
          if F.First then
          begin
            WriteLn(fp);
            WriteLn(fp, Format('Library: %s', [Data.Key]));
            WriteLn(fp, Format('Description: %s', [Data.Display]));
            WriteLn(fp, Format('There are %u files available for download', [Data.ActiveFiles]));
            WriteLn(fp);
            WriteLn(fp, 'File Name    Size  Date  Description');
            WriteLn(fp, '============ ===== ===== =====================================================');
            repeat
              p := PChar(F.Description.First);
              if p = nil then
                WriteLn(fp, Format('%-12s %4uK %02d/%02d',
                  [F.Name, (F.Size_ + 1023) div 1024, F.UplDate.Month, F.UplDate.Year mod 100]))
              else
                WriteLn(fp, Format('%-12s %4uK %02d/%02d %.53s',
                  [F.Name, (F.Size_ + 1023) div 1024, F.UplDate.Month, F.UplDate.Year mod 100, StrPas(p)]));
              p := PChar(F.Description.Next);
              while p <> nil do
              begin
                WriteLn(fp, Format('                         %.53s', [StrPas(p)]));
                p := PChar(F.Description.Next);
              end;
            until not F.Next;
            WriteLn(fp);
          end;
        end;
      finally
        F.Free;
      end;
    until not Data.Next;
  finally
    Data.Free;
  end;

  CloseFile(fp);
end;

var
  i: Integer;
  DoPurge, DoPack, DoImport, DoExport, DoList, DoUpdate: Boolean;
  DoKeepDate: Boolean;
  DaysOld: Word;
  ConfigFile: string;
begin
  DoUpdate := False; DoPurge := False; DoPack := False;
  DoList := False; DoImport := False; DoExport := False;
  DoKeepDate := False;
  DaysOld := 65535;
  ConfigFile := '';

  WriteLn;
  WriteLn(Format('LFILE; %s v%s - File maintenance utility', [PROG_NAME, PROG_VERSION]));
  WriteLn('       Based on LoraBBS by Marco Maccaferri. GPL v2 Licensed.');
  WriteLn;

  if ParamCount = 0 then
  begin
    WriteLn(' * Command-line parameters:');
    WriteLn;
    WriteLn('        -U[K]     Update FILEBASE');
    WriteLn('                  K=Keep file date');
    WriteLn('        -I        Import from FILES.BBS');
    WriteLn('        -E        Export to FILES.BBS');
    WriteLn('        -P[K]     Pack (compress) file base');
    WriteLn('                  K=Purge');
    WriteLn('        -K<d>     Purge files that are <d> days old');
    WriteLn('        -L        Create a list of available files');
    WriteLn('        -C<n>     Multiline descriptions begin at column <n>');
    WriteLn('        -S<c>     Use <c> as the identifier of a multiline description');
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
          'C': Column := StrToIntDef(Copy(ParamStr(i), 3, Length(ParamStr(i))), 1);
          'I': DoImport := True;
          'E': DoExport := True;
          'K': begin DoPurge := True; DaysOld := StrToIntDef(Copy(ParamStr(i), 3, Length(ParamStr(i))), 65535); end;
          'L': DoList := True;
          'P': begin DoPack := True; if (Length(ParamStr(i)) >= 3) and (UpCase(ParamStr(i)[3]) = 'K') then DoPurge := True; end;
          'S': if Length(ParamStr(i)) >= 3 then Symbol := ParamStr(i)[3];
          'U': begin DoUpdate := True; if (Length(ParamStr(i)) >= 3) and (UpCase(ParamStr(i)[3]) = 'K') then DoKeepDate := True; end;
        end;
      end
      else if ConfigFile = '' then
        ConfigFile := ParamStr(i);
    end;

    Cfg := TConfig.Create;
    try
      if not Cfg.Load(ConfigFile) then
        Cfg.Default;

      if DoImport then ImportFilesBBS;
      if DoPurge then PurgeFiles(DaysOld);
      if DoPack then PackFilebase;
      if DoExport then ExportFilesBBS;
      if DoList then CreateFilesList;

      if DoImport or DoExport or DoPurge or DoPack or DoList or DoUpdate then
        WriteLn(' * Done')
      else
        WriteLn(' * Nothing to do');
      WriteLn;
    finally
      Cfg.Free;
    end;
  end;
end.
