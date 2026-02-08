{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of menu.cpp - TMenu class
  Manages BBS menu system - loading/saving .MNU files with menu items.
}

unit Menu;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Defs, Struc299, Collect;

type
  TMenu = class
  public
    Path:           array[0..63] of Char;
    Name:           array[0..31] of Char;
    AltPath:        array[0..63] of Char;

    Prompt:         array[0..127] of Char;
    PromptColor:    Byte;
    PromptHilight:  Byte;

    Command:        Word;
    Level:          Word;
    Display:        array[0..127] of Char;
    Key:            array[0..15] of Char;
    Argument:       array[0..127] of Char;
    Color:          Byte;
    Hilight:        Byte;
    AccessFlags:    LongWord;
    DenyFlags:      LongWord;
    Automatic:      Byte;
    FirstTime:      Byte;

    constructor Create; virtual;
    destructor Destroy; override;

    procedure Add;
    function  Check(pszKey: PChar): Word;
    procedure Delete;
    function  First: Word;
    procedure Insert;
    function  Load(pszName: PChar; fAppend: Word = 0): Word;
    procedure New_(usNewPrompt: Word = 0);
    function  Next: Word;
    function  Previous: Word;
    function  Save(pszName: PChar): Word;
    procedure Update;

  private
    Hdr:   MENUHEADER;
    Item:  MENUITEM;
    Items: TCollection;

    procedure Struct2Class(Current: PMENUITEM);
    procedure Class2Struct(var Dest: MENUITEM);
  end;

implementation

constructor TMenu.Create;
begin
  inherited Create;
  Items := TCollection.Create;
  Path[0] := #0;
  AltPath[0] := #0;
end;

destructor TMenu.Destroy;
begin
  Items.Clear;
  Items.Free;
  inherited Destroy;
end;

procedure TMenu.Struct2Class(Current: PMENUITEM);
begin
  StrCopy(Display, Current^.Display);
  Color := Current^.Color;
  Hilight := Current^.Hilight;
  StrCopy(Key, Current^.Key);
  Command := Current^.Command;
  StrCopy(Argument, Current^.Argument);
  Level := Current^.Level;
  AccessFlags := Current^.AccessFlags;
  DenyFlags := Current^.DenyFlags;
  Automatic := Current^.Automatic;
  FirstTime := Current^.FirstTime;
end;

procedure TMenu.Class2Struct(var Dest: MENUITEM);
begin
  FillChar(Dest, SizeOf(MENUITEM), 0);
  StrCopy(Dest.Display, Display);
  Dest.Color := Color;
  Dest.Hilight := Hilight;
  StrCopy(Dest.Key, Key);
  Dest.Command := Command;
  StrCopy(Dest.Argument, Argument);
  Dest.Level := Level;
  Dest.AccessFlags := AccessFlags;
  Dest.DenyFlags := DenyFlags;
  Dest.Automatic := Automatic;
  Dest.FirstTime := FirstTime;
end;

procedure TMenu.Add;
begin
  Class2Struct(Item);
  Items.Add(@Item, SizeOf(MENUITEM));
end;

function TMenu.Check(pszKey: PChar): Word;
var
  Current: PMENUITEM;
begin
  Result := 0;

  Current := PMENUITEM(Items.First);
  while Current <> nil do
  begin
    if stricmp(Current^.Key, pszKey) = 0 then
    begin
      Struct2Class(Current);
      Result := 1;
      Exit;
    end;
    Current := PMENUITEM(Items.Next);
  end;
end;

procedure TMenu.Delete;
var
  Current: PMENUITEM;
begin
  Items.Remove;
  if Items.Value = nil then
    New_
  else
  begin
    Current := PMENUITEM(Items.Value);
    if Current <> nil then
      Struct2Class(Current);
  end;
end;

function TMenu.First: Word;
var
  Current: PMENUITEM;
begin
  Result := 0;

  Current := PMENUITEM(Items.First);
  if Current <> nil then
  begin
    Struct2Class(Current);
    Result := 1;
  end;
end;

procedure TMenu.Insert;
begin
  Class2Struct(Item);
  Items.Insert(@Item, SizeOf(MENUITEM));
end;

function TMenu.Load(pszName: PChar; fAppend: Word): Word;
var
  fs: TFileStream;
  Temp: String;
  Current: PMENUITEM;
  SavedValue: Pointer;
begin
  Result := 0;

  if fAppend <> 0 then
    SavedValue := Items.Value
  else
    SavedValue := nil;

  { Try AltPath first, then Path }
  if AltPath[0] <> #0 then
  begin
    Temp := IncludeTrailingPathDelimiter(StrPas(AltPath)) + StrPas(pszName);
    if not SameText(ExtractFileExt(Temp), '.MNU') then
      Temp := Temp + '.MNU';

    if FileExists(Temp) then
    begin
      try
        fs := TFileStream.Create(Temp, fmOpenRead or fmShareDenyNone);
        try
          if fs.Read(Hdr, SizeOf(MENUHEADER)) = SizeOf(MENUHEADER) then
          begin
            if fAppend = 0 then
            begin
              Items.Clear;
              New_;
              StrCopy(Name, Hdr.MenuName);
              StrCopy(Prompt, Hdr.Prompt);
              PromptColor := Hdr.Color;
              PromptHilight := Hdr.Hilight;
            end;
            while fs.Read(Item, SizeOf(MENUITEM)) = SizeOf(MENUITEM) do
            begin
              if fAppend <> 0 then
                Items.Insert(@Item, SizeOf(MENUITEM))
              else
                Items.Add(@Item, SizeOf(MENUITEM));
            end;
            Result := 1;
          end;
        finally
          fs.Free;
        end;
      except
      end;
    end;
  end;

  { Fall back to Path if not found }
  if Result = 0 then
  begin
    Temp := IncludeTrailingPathDelimiter(StrPas(Path)) + StrPas(pszName);
    if not SameText(ExtractFileExt(Temp), '.MNU') then
      Temp := Temp + '.MNU';

    if FileExists(Temp) then
    begin
      try
        fs := TFileStream.Create(Temp, fmOpenRead or fmShareDenyNone);
        try
          if fs.Read(Hdr, SizeOf(MENUHEADER)) = SizeOf(MENUHEADER) then
          begin
            if fAppend = 0 then
            begin
              Items.Clear;
              New_;
              StrCopy(Name, Hdr.MenuName);
              StrCopy(Prompt, Hdr.Prompt);
              PromptColor := Hdr.Color;
              PromptHilight := Hdr.Hilight;
            end;
            while fs.Read(Item, SizeOf(MENUITEM)) = SizeOf(MENUITEM) do
            begin
              if fAppend <> 0 then
                Items.Insert(@Item, SizeOf(MENUITEM))
              else
                Items.Add(@Item, SizeOf(MENUITEM));
            end;
            Result := 1;
          end;
        finally
          fs.Free;
        end;
      except
      end;
    end;
  end;

  { Position to appropriate item }
  if Result = 1 then
  begin
    if fAppend <> 0 then
    begin
      { Restore position to saved item }
      if Items.First <> nil then
      begin
        repeat
          if Items.Value = SavedValue then
            Break;
        until Items.Next = nil;
      end;
    end
    else
    begin
      Current := PMENUITEM(Items.First);
      SavedValue := Pointer(Current);
    end;

    Current := PMENUITEM(SavedValue);
    if Current <> nil then
      Struct2Class(Current);
  end;
end;

procedure TMenu.New_(usNewPrompt: Word);
begin
  FillChar(Display, SizeOf(Display), 0);
  Color := 7;
  Hilight := 14;
  FillChar(Key, SizeOf(Key), 0);
  Command := 0;
  FillChar(Argument, SizeOf(Argument), 0);
  Level := 0;
  AccessFlags := 0;
  DenyFlags := 0;
  FirstTime := 0;
  Automatic := 0;

  if usNewPrompt <> 0 then
  begin
    FillChar(Name, SizeOf(Name), 0);
    FillChar(Prompt, SizeOf(Prompt), 0);
    PromptColor := 14;
    PromptHilight := 14;
  end;
end;

function TMenu.Next: Word;
var
  Current: PMENUITEM;
begin
  Result := 0;

  Current := PMENUITEM(Items.Next);
  if Current <> nil then
  begin
    Struct2Class(Current);
    Result := 1;
  end;
end;

function TMenu.Previous: Word;
var
  Current: PMENUITEM;
begin
  Result := 0;

  Current := PMENUITEM(Items.Previous);
  if Current <> nil then
  begin
    Struct2Class(Current);
    Result := 1;
  end;
end;

function TMenu.Save(pszName: PChar): Word;
var
  fs: TFileStream;
  Temp: String;
  Current, Saved: Pointer;
begin
  Result := 0;

  if AltPath[0] <> #0 then
    Temp := IncludeTrailingPathDelimiter(StrPas(AltPath)) + StrPas(pszName)
  else
    Temp := IncludeTrailingPathDelimiter(StrPas(Path)) + StrPas(pszName);

  if not SameText(ExtractFileExt(Temp), '.MNU') then
    Temp := Temp + '.MNU';

  try
    fs := TFileStream.Create(Temp, fmCreate);
    try
      FillChar(Hdr, SizeOf(MENUHEADER), 0);
      StrCopy(Hdr.MenuName, Name);
      StrCopy(Hdr.Prompt, Prompt);
      Hdr.Color := PromptColor;
      Hdr.Hilight := PromptHilight;
      fs.Write(Hdr, SizeOf(MENUHEADER));

      Saved := Items.Value;

      Current := Items.First;
      while Current <> nil do
      begin
        fs.Write(Current^, SizeOf(MENUITEM));
        Current := Items.Next;
      end;

      { Restore position }
      if Items.First <> nil then
      begin
        repeat
          if Items.Value = Saved then
            Break;
        until Items.Next = nil;
      end;

      Result := 1;
    finally
      fs.Free;
    end;
  except
  end;
end;

procedure TMenu.Update;
var
  Current: PMENUITEM;
begin
  Current := PMENUITEM(Items.Value);
  if Current <> nil then
  begin
    StrCopy(Current^.Display, Display);
    Current^.Color := Color;
    Current^.Hilight := Hilight;
    StrCopy(Current^.Key, Key);
    Current^.Command := Command;
    StrCopy(Current^.Argument, Argument);
    Current^.Level := Level;
    Current^.AccessFlags := AccessFlags;
    Current^.DenyFlags := DenyFlags;
    Current^.Automatic := Automatic;
    Current^.FirstTime := FirstTime;
  end;
end;

end.
