{
  FastWay BBS - Message Base Library
  Based on LoraBBS by Marco Maccaferri. GPL v2 Licensed.

  Builds as shared library (DLL/SO) on Windows, OS/2, Linux.
  On DOS, units are linked statically into executables.

  Note: Named msgbase_lib to avoid conflict with MsgBase.pas unit.
}

library msgbase_lib;

{$MODE OBJFPC}
{$H+}

uses
  MsgBase, Passthr, Dupes, FidoSdm, Adept, JamMsg, Hudson,
  Packet, Squish, InetMail, Usenet;

end.
