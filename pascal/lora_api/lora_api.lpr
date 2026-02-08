{
  FastWay BBS - API Library
  Based on LoraBBS by Marco Maccaferri. GPL v2 Licensed.

  Builds as shared library (DLL/SO) on Windows, OS/2, Linux.
  On DOS, units are linked statically into executables.
}

library lora_api;

{$MODE OBJFPC}
{$H+}

uses
  Collect, Log, OkFile, Stats, Protocol, Address, Limits, UULib,
  Menu, Events, Packer, Misc, Language, Config, Nodes, FileData,
  Outbound, MsgData, User, FileBase;

exports
  { Library marker - actual functionality accessed via unit interfaces }
  ;

end.
