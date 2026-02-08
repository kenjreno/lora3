{
  LoraBBS Version 2.99 Free Edition
  Copyright (C) 1987-98 Marco Maccaferri

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

  FreePascal conversion of jam.h and jamsys.h

  JAM(mbp) - The Joaquim-Andrew-Mats Message Base Proposal
  Copyright 1993 Joaquim Homrighausen, Andrew Milner, Mats Birch, and
  Mats Wallin. ALL RIGHTS RESERVED.
}

unit LoraJam;

{$MODE OBJFPC}
{$H+}
{$PACKRECORDS 1}

interface

uses
  LoraDefs;

{ -------------------------------------------------------------------------- }
{ File extensions                                                            }
{ -------------------------------------------------------------------------- }
const
  EXT_HDRFILE     = '.jhr';
  EXT_TXTFILE     = '.jdt';
  EXT_IDXFILE     = '.jdx';
  EXT_LRDFILE     = '.jlr';

{ -------------------------------------------------------------------------- }
{ Revision level and header signature                                        }
{ -------------------------------------------------------------------------- }
  CURRENTREVLEV   = 1;
  HEADERSIGNATURE = 'JAM';

{ -------------------------------------------------------------------------- }
{ Message status bits                                                        }
{ -------------------------------------------------------------------------- }
  MSG_LOCAL       = $00000001;    { Msg created locally }
  MSG_INTRANSIT   = $00000002;    { Msg is in-transit }
  MSG_PRIVATE     = $00000004;    { Private }
  MSG_READ        = $00000008;    { Read by addressee }
  MSG_SENT        = $00000010;    { Sent to remote }
  MSG_KILLSENT    = $00000020;    { Kill when sent }
  MSG_ARCHIVESENT = $00000040;    { Archive when sent }
  MSG_HOLD        = $00000080;    { Hold for pick-up }
  MSG_CRASH       = $00000100;    { Crash }
  MSG_IMMEDIATE   = $00000200;    { Send Msg now, ignore restrictions }
  MSG_DIRECT      = $00000400;    { Send directly to destination }
  MSG_GATE        = $00000800;    { Send via gateway }
  MSG_FILEREQUEST = $00001000;    { File request }
  MSG_FILEATTACH  = $00002000;    { File(s) attached to Msg }
  MSG_TRUNCFILE   = $00004000;    { Truncate file(s) when sent }
  MSG_KILLFILE    = $00008000;    { Delete file(s) when sent }
  MSG_RECEIPTREQ  = $00010000;    { Return receipt requested }
  MSG_CONFIRMREQ  = $00020000;    { Confirmation receipt requested }
  MSG_ORPHAN      = $00040000;    { Unknown destination }
  MSG_ENCRYPT     = $00080000;    { Msg text is encrypted }
  MSG_COMPRESS    = $00100000;    { Msg text is compressed }
  MSG_ESCAPED     = $00200000;    { Msg text is seven bit ASCII }
  MSG_FPU         = $00400000;    { Force pickup }
  MSG_TYPELOCAL   = $00800000;    { Msg is for local use only (not for export) }
  MSG_TYPEECHO    = $01000000;    { Msg is for conference distribution }
  MSG_TYPENET     = $02000000;    { Msg is direct network mail }
  MSG_NODISP      = $20000000;    { Msg may not be displayed to user }
  MSG_LOCKED      = $40000000;    { Msg is locked, no editing possible }
  MSG_DELETED     = LongWord($80000000);  { Msg is deleted }

{ -------------------------------------------------------------------------- }
{ Message header subfield types                                              }
{ -------------------------------------------------------------------------- }
  JAMSFLD_OADDRESS    = 0;
  JAMSFLD_DADDRESS    = 1;
  JAMSFLD_SENDERNAME  = 2;
  JAMSFLD_RECVRNAME   = 3;
  JAMSFLD_MSGID       = 4;
  JAMSFLD_REPLYID     = 5;
  JAMSFLD_SUBJECT     = 6;
  JAMSFLD_PID         = 7;
  JAMSFLD_TRACE       = 8;
  JAMSFLD_ENCLFILE    = 9;
  JAMSFLD_ENCLFWALIAS = 10;
  JAMSFLD_ENCLFREQ    = 11;
  JAMSFLD_ENCLFILEWC  = 12;
  JAMSFLD_ENCLINDFILE = 13;
  JAMSFLD_EMBINDAT    = 1000;
  JAMSFLD_FTSKLUDGE   = 2000;
  JAMSFLD_SEENBY2D    = 2001;
  JAMSFLD_PATH2D      = 2002;
  JAMSFLD_FLAGS       = 2003;
  JAMSFLD_TZUTCINFO   = 2004;
  JAMSFLD_UNKNOWN     = $FFFF;

type
{ -------------------------------------------------------------------------- }
{ Structure to contain date/time information (from jamsys.h)                 }
{ -------------------------------------------------------------------------- }
  PJAMTM = ^JAMTM;
  JAMTM = packed record
    tm_sec:    LongInt;            { Seconds 0..59 }
    tm_min:    LongInt;            { Minutes 0..59 }
    tm_hour:   LongInt;            { Hour of day 0..23 }
    tm_mday:   LongInt;            { Day of month 1..31 }
    tm_mon:    LongInt;            { Month 0..11 }
    tm_year:   LongInt;            { Years since 1900 }
    tm_wday:   LongInt;            { Day of week 0..6 (Sun..Sat) }
    tm_yday:   LongInt;            { Day of year 0..365 }
    tm_isdst:  LongInt;            { Daylight savings time (not used) }
  end;

{ -------------------------------------------------------------------------- }
{ Header file information block, stored first in all .JHR files              }
{ -------------------------------------------------------------------------- }
  PJAMHDRINFO = ^JAMHDRINFO;
  JAMHDRINFO = packed record
    Signature:   array[0..3] of Char;   { <J><A><M> followed by <NUL> }
    DateCreated: LongWord;              { Creation date }
    ModCounter:  LongWord;              { Last processed counter }
    ActiveMsgs:  LongWord;              { Number of active (not deleted) msgs }
    PasswordCRC: LongWord;              { CRC-32 of password to access }
    BaseMsgNum:  LongWord;              { Lowest message number in index file }
    RSRVD:       array[0..999] of Char; { Reserved space }
  end;

{ -------------------------------------------------------------------------- }
{ Message header                                                             }
{ -------------------------------------------------------------------------- }
  PJAMHDR = ^JAMHDR;
  JAMHDR = packed record
    Signature:     array[0..3] of Char; { <J><A><M> followed by <NUL> }
    Revision:      Word;                { CURRENTREVLEV }
    ReservedWord:  Word;                { Reserved }
    SubfieldLen:   LongWord;            { Length of subfields }
    TimesRead:     LongWord;            { Number of times message read }
    MsgIdCRC:      LongWord;            { CRC-32 of MSGID line }
    ReplyCRC:      LongWord;            { CRC-32 of REPLY line }
    ReplyTo:       LongWord;            { This msg is a reply to.. }
    Reply1st:      LongWord;            { First reply to this msg }
    ReplyNext:     LongWord;            { Next msg in reply chain }
    DateWritten:   LongWord;            { When msg was written }
    DateReceived:  LongWord;            { When msg was received/read }
    DateProcessed: LongWord;            { When msg was processed by packer }
    MsgNum:        LongWord;            { Message number (1-based) }
    Attribute:     LongWord;            { Msg attribute, see "Status bits" }
    Attribute2:    LongWord;            { Reserved for future use }
    TxtOffset:     LongWord;            { Offset of text in text file }
    TxtLen:        LongWord;            { Length of message text }
    PasswordCRC:   LongWord;            { CRC-32 of password to access msg }
    Cost:          LongWord;            { Cost of message }
  end;

{ -------------------------------------------------------------------------- }
{ Message header subfield                                                    }
{ -------------------------------------------------------------------------- }
  PJAMSUBFIELD = ^JAMSUBFIELD;
  JAMSUBFIELD = packed record
    LoID:   Word;                       { Field ID, 0 - $FFFF }
    HiID:   Word;                       { Reserved for future use }
    DatLen: LongWord;                   { Length of buffer that follows }
    Buffer: array[0..0] of Char;        { DatLen bytes of data }
  end;

  PJAMBINSUBFIELD = ^JAMBINSUBFIELD;
  JAMBINSUBFIELD = packed record
    LoID:   Word;                       { Field ID, 0 - $FFFF }
    HiID:   Word;                       { Reserved for future use }
    DatLen: LongWord;                   { Length of buffer that follows }
  end;

{ -------------------------------------------------------------------------- }
{ Message index record                                                       }
{ -------------------------------------------------------------------------- }
  PJAMIDXREC = ^JAMIDXREC;
  JAMIDXREC = packed record
    UserCRC:   LongWord;                { CRC-32 of destination username }
    HdrOffset: LongWord;                { Offset of header in .JHR file }
  end;

{ -------------------------------------------------------------------------- }
{ Lastread structure, one per user                                           }
{ -------------------------------------------------------------------------- }
  PJAMLREAD = ^JAMLREAD;
  JAMLREAD = packed record
    UserCRC:     LongWord;              { CRC-32 of user name (lowercase) }
    UserID:      LongWord;              { Unique UserID }
    LastReadMsg: LongWord;              { Last read message number }
    HighReadMsg: LongWord;              { Highest read message number }
  end;

implementation

end.
