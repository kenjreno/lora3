{
  FastWay BBS - Communications Library
  Based on LoraBBS by Marco Maccaferri. GPL v2 Licensed.

  Builds as shared library (DLL/SO) on Windows, OS/2, Linux.
  On DOS, units are linked statically into executables.
}

library comm;

{$MODE OBJFPC}
{$H+}

uses
  ComBase, Serial, Tcpip, Stdio, Screen, Npipe;

exports
  { Library marker - actual functionality accessed via unit interfaces }
  ;

end.
