{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  FreePascal conversion of uulib.cpp - TUULib class
  UUEncode/UUDecode and Base64 encoding/decoding for file attachments.
  Uses FPC Base64 unit for MIME base64 operations.
}

unit UULib;

{$MODE OBJFPC}
{$H+}

interface

uses
  SysUtils, Classes, Collect;

type
  TUULib = class
  public
    MaxLines: Word;
    Size:     Word;
    Buffer:   array[0..127] of Byte;

    constructor Create; virtual;
    destructor Destroy; override;

    function  Decode(pszBuffer: PChar): Word;
    function  Decode64(pszBuffer: PChar): Word;
    function  DecodeCollection(Text: TCollection): Word;
    function  DecodeFile(pszSource: PChar; pszDestination: PChar = nil): Word;
    procedure Encode(lpBuffer: PByte; usSize: Word);
    function  EncodeFile(pszSource, pszDestination: PChar;
                         pszRemote: PChar = nil): Word;
  end;

implementation

const
  Table64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function UUEnc(c: Byte): Byte; inline;
begin
  if c <> 0 then
    Result := (c and $3F) + Ord(' ')
  else
    Result := Ord('`');
end;

function UUDec(c: Byte): Byte; inline;
begin
  Result := (c - Ord(' ')) and $3F;
end;

function Dec64(c: Char): Byte; inline;
begin
  if c = '=' then
    Result := 0
  else
    Result := Pos(c, Table64) - 1;
end;

constructor TUULib.Create;
begin
  inherited Create;
  MaxLines := 0;
end;

destructor TUULib.Destroy;
begin
  inherited Destroy;
end;

function TUULib.Decode(pszBuffer: PChar): Word;
var
  c1, c2, c3: Word;
  src: PChar;
  destIdx: Integer;
begin
  Size := 0;
  FillChar(Buffer, SizeOf(Buffer), 0);
  src := pszBuffer + 1;  { skip length byte }
  destIdx := 0;

  while (src^ <> #0) and ((src + 1)^ <> #0) and ((src + 2)^ <> #0) do
  begin
    c1 := (UUDec(Ord(src^)) shl 2) or (UUDec(Ord((src + 1)^)) shr 4);
    c2 := (UUDec(Ord((src + 1)^)) shl 4) or (UUDec(Ord((src + 2)^)) shr 2);
    c3 := (UUDec(Ord((src + 2)^)) shl 6) or UUDec(Ord((src + 3)^));
    Buffer[destIdx] := Byte(c1);
    Buffer[destIdx + 1] := Byte(c2);
    Buffer[destIdx + 2] := Byte(c3);
    Inc(destIdx, 3);
    Inc(src, 4);
    Inc(Size, 3);
  end;

  Result := Size;
end;

function TUULib.Decode64(pszBuffer: PChar): Word;
var
  c1, c2, c3: Word;
  src: PChar;
  destIdx: Integer;
begin
  Size := 0;
  FillChar(Buffer, SizeOf(Buffer), 0);
  src := pszBuffer;
  destIdx := 0;

  while (src^ <> #0) and ((src + 1)^ <> #0) and ((src + 2)^ <> #0) do
  begin
    c1 := (Dec64(src^) shl 2) or (Dec64((src + 1)^) shr 4);
    c2 := (Dec64((src + 1)^) shl 4) or (Dec64((src + 2)^) shr 2);
    c3 := (Dec64((src + 2)^) shl 6) or Dec64((src + 3)^);
    Buffer[destIdx] := Byte(c1);
    Buffer[destIdx + 1] := Byte(c2);
    Buffer[destIdx + 2] := Byte(c3);
    Inc(destIdx, 3);
    Inc(src, 4);
    Inc(Size, 3);
  end;

  Result := Size;
end;

function TUULib.DecodeCollection(Text: TCollection): Word;
var
  fpd: TFileStream;
  Temp, p, a: PChar;
  Destination: array[0..63] of Char;
  Began, IsMIME, MayBe64: Boolean;
  i: Integer;
begin
  Result := 0;
  fpd := nil;
  Began := False;
  IsMIME := False;
  MayBe64 := False;

  try
    Temp := PChar(Text.First);
    while Temp <> nil do
    begin
      { Check for end markers }
      if (StrLComp(Temp, 'end', 3) = 0) or (StrLComp(Temp, '--', 2) = 0) then
      begin
        if Began then
          Began := False;
      end;

      { Decode current line }
      if Began then
      begin
        if MayBe64 then
        begin
          Decode64(Temp);
          if fpd <> nil then
            fpd.Write(Buffer, Size);
        end
        else
        begin
          Decode(Temp);
          if fpd <> nil then
            fpd.Write(Buffer, Size);
        end;
      end;

      { Empty line after MIME header starts content }
      if (Temp[0] = #0) and IsMIME then
        Began := True;

      { Check for begin line (UUEncode) }
      if StrLComp(Temp, 'begin ', 6) = 0 then
      begin
        MayBe64 := False;
        StrCopy(Destination, Temp + 10);
        FreeAndNil(fpd);
        try
          fpd := TFileStream.Create(StrPas(Destination), fmCreate);
          Result := 1;
        except
        end;
        Began := True;
      end
      else if StrComp(Temp, 'Content-Transfer-Encoding: base64') = 0 then
        MayBe64 := True
      else if (StrLComp(Temp, 'Content-Disposition:', 20) = 0) or
              (StrLComp(Temp, 'Content-Type:', 13) = 0) then
      begin
        p := StrPos(Temp, 'filename=');
        if p = nil then
          p := StrPos(Temp, 'name=');
        if p <> nil then
        begin
          { Skip past key= and opening quote }
          while (p^ <> #0) and (p^ <> '=') do Inc(p);
          if p^ = '=' then Inc(p);
          if p^ = '"' then Inc(p);
          { Copy until closing quote or end }
          i := 0;
          while (p^ <> #0) and (p^ <> '"') and (i < 63) do
          begin
            Destination[i] := p^;
            Inc(i);
            Inc(p);
          end;
          Destination[i] := #0;
          FreeAndNil(fpd);
          try
            fpd := TFileStream.Create(StrPas(Destination), fmCreate);
            Result := 1;
          except
          end;
          IsMIME := True;
        end;
      end;

      Temp := PChar(Text.Next);
    end;
  finally
    FreeAndNil(fpd);
  end;
end;

function TUULib.DecodeFile(pszSource: PChar; pszDestination: PChar): Word;
var
  fps: TextFile;
  fpd: TFileStream;
  Temp: String;
  Began: Boolean;
begin
  Result := 0;
  fpd := nil;
  Began := False;

  try
    AssignFile(fps, StrPas(pszSource));
    {$I-}
    Reset(fps);
    {$I+}
    if IOResult <> 0 then
      Exit;

    try
      if pszDestination <> nil then
      begin
        fpd := TFileStream.Create(StrPas(pszDestination), fmCreate);
        Result := 1;
      end;

      { Skip first line }
      if not EOF(fps) then
        ReadLn(fps, Temp);

      while not EOF(fps) do
      begin
        ReadLn(fps, Temp);

        if Copy(Temp, 1, 3) = 'end' then
          Began := False;

        if Began then
        begin
          Decode(PChar(Temp));
          if fpd <> nil then
            fpd.Write(Buffer, Size);
        end;

        if Copy(Temp, 1, 6) = 'begin ' then
          Began := True;
      end;
    finally
      FreeAndNil(fpd);
      CloseFile(fps);
    end;
  except
  end;
end;

procedure TUULib.Encode(lpBuffer: PByte; usSize: Word);
var
  c1, c2, c3, c4: Word;
  src: PByte;
  destIdx: Integer;
begin
  src := lpBuffer;
  Buffer[0] := UUEnc(usSize);
  Size := 1;
  destIdx := 1;

  while usSize > 0 do
  begin
    c1 := src^ shr 2;
    if usSize >= 2 then
      c2 := ((src^ shl 4) and $30) or (((src + 1)^ shr 4) and $0F)
    else
      c2 := 0;
    if usSize >= 3 then
    begin
      c3 := (((src + 1)^ shl 2) and $3C) or (((src + 2)^ shr 6) and $03);
      c4 := (src + 2)^ and $3F;
    end
    else
    begin
      c3 := 0;
      c4 := 0;
    end;

    Buffer[destIdx] := UUEnc(c1);
    Buffer[destIdx + 1] := UUEnc(c2);
    Buffer[destIdx + 2] := UUEnc(c3);
    Buffer[destIdx + 3] := UUEnc(c4);
    Inc(destIdx, 4);
    Inc(Size, 4);

    if usSize >= 3 then
    begin
      Inc(src, 3);
      Dec(usSize, 3);
    end
    else
    begin
      Inc(src, usSize);
      usSize := 0;
    end;
  end;
end;

function TUULib.EncodeFile(pszSource, pszDestination: PChar;
                           pszRemote: PChar): Word;
var
  fps, fpd: TFileStream;
  Temp: array[0..127] of Byte;
  TempFile: String;
  Header, NL: String;
  Readed: Integer;
  Count: Word;
  p: Integer;
begin
  Result := 0;
  TempFile := StrPas(pszDestination);

  try
    fps := TFileStream.Create(StrPas(pszSource), fmOpenRead or fmShareDenyNone);
    try
      fpd := TFileStream.Create(TempFile, fmCreate);
      try
        Result := 1;
        Count := 0;
        NL := LineEnding;

        if pszRemote <> nil then
          Header := Format('begin 644 %s', [StrPas(pszRemote)])
        else
          Header := Format('begin 644 %s', [StrPas(pszSource)]);
        Header := Header + NL;
        fpd.Write(Header[1], Length(Header));

        repeat
          Readed := fps.Read(Temp, 45);
          if Readed > 0 then
          begin
            Encode(@Temp[0], Word(Readed));
            fpd.Write(Buffer, Size);
            fpd.Write(NL[1], Length(NL));

            if (MaxLines <> 0) then
            begin
              Inc(Count);
              if Count >= MaxLines then
              begin
                FreeAndNil(fpd);
                { Increment last character of filename for split }
                p := Length(TempFile);
                if (p > 0) and (TempFile[p] >= '0') and (TempFile[p] <= '9') then
                begin
                  if TempFile[p] = '9' then
                  begin
                    TempFile[p] := '0';
                    if (p > 1) and (TempFile[p-1] >= '0') and (TempFile[p-1] <= '8') then
                      Inc(TempFile[p-1])
                    else if (p > 1) then
                      TempFile[p-1] := '1';
                  end
                  else
                    Inc(TempFile[p]);
                end
                else if p > 0 then
                  TempFile[p] := '0';
                fpd := TFileStream.Create(TempFile, fmCreate);
                Count := 0;
              end;
            end;
          end;
        until Readed < 45;

        Header := '''' + NL + 'end' + NL;
        fpd.Write(Header[1], Length(Header));
      finally
        FreeAndNil(fpd);
      end;
    finally
      fps.Free;
    end;
  except
    Result := 0;
  end;
end;

end.
