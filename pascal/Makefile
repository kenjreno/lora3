# FastWay BBS - Master Build Makefile
# Based on LoraBBS by Marco Maccaferri. GPL v2 Licensed.
#
# Usage:
#   make all        - Build everything (libraries + tools)
#   make libs       - Build libraries only
#   make tools      - Build tools only
#   make clean      - Remove build output
#   make DOS=1      - Build for DOS (static linking, no shared libs)
#
# Requirements:
#   - Free Pascal Compiler (fpc) 3.2.0 or later
#   - Synapse library (synaser, blcksock) for serial/TCP
#
# Platform detection:
#   Automatically detects Windows, Linux, OS/2.
#   Pass DOS=1 for cross-compiling to DOS (uses MSDOS define).

# Compiler
FPC ?= fpc

# Base directories
BASEDIR := $(CURDIR)
COMMONDIR := $(BASEDIR)/common
COMMDIR := $(BASEDIR)/comm
APIDIR := $(BASEDIR)/lora_api
MSGBASEDIR := $(BASEDIR)/msgbase
TOOLSDIR := $(BASEDIR)/tools
OUTDIR := $(BASEDIR)/output

# Common compiler flags
FPCFLAGS := -MObjFPC -Sh -CX -O2

# Unit search paths - all libraries need common, comm needs nothing extra,
# lora_api needs common+comm, msgbase needs common+comm+lora_api
COMMON_PATH := -Fu$(COMMONDIR)
COMM_PATH := $(COMMON_PATH) -Fu$(COMMDIR)
API_PATH := $(COMM_PATH) -Fu$(APIDIR)
MSGBASE_PATH := $(API_PATH) -Fu$(MSGBASEDIR)
ALL_PATHS := $(MSGBASE_PATH)

# Output directory for compiled units and binaries
UNITOUT := -FU$(OUTDIR)
BINOUT := -FE$(OUTDIR)

# Platform-specific settings
ifdef DOS
  # DOS cross-compilation: static linking only, no shared libraries
  FPCFLAGS += -dMSDOS -TWatcom
  LIBEXT :=
  EXEEXT := .exe
else
  ifeq ($(OS),Windows_NT)
    FPCFLAGS += -dWINDOWS -Twin64
    LIBEXT := .dll
    EXEEXT := .exe
  else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
      FPCFLAGS += -dUNIX -Tlinux
      LIBEXT := .so
      EXEEXT :=
    else
      # OS/2
      FPCFLAGS += -dOS2 -Tos2
      LIBEXT := .dll
      EXEEXT := .exe
    endif
  endif
endif

# Library targets (not built for DOS - units linked statically)
LIBS :=
ifndef DOS
  LIBS := $(OUTDIR)/comm$(LIBEXT) $(OUTDIR)/lora_api$(LIBEXT) $(OUTDIR)/msgbase_lib$(LIBEXT)
endif

# Tool targets
TOOLS := $(OUTDIR)/luser$(EXEEXT) \
         $(OUTDIR)/lfile$(EXEEXT) \
         $(OUTDIR)/lmsg$(EXEEXT) \
         $(OUTDIR)/snoop$(EXEEXT)

# Default target
.PHONY: all libs tools clean prepare

all: prepare libs tools

prepare:
	@mkdir -p $(OUTDIR)

libs: prepare $(LIBS)

tools: prepare $(TOOLS)

# Library builds
$(OUTDIR)/comm$(LIBEXT): $(wildcard $(COMMDIR)/*.pas) $(wildcard $(COMMONDIR)/*.pas)
	$(FPC) $(FPCFLAGS) $(COMM_PATH) $(UNITOUT) $(BINOUT) $(COMMDIR)/comm.lpr

$(OUTDIR)/lora_api$(LIBEXT): $(wildcard $(APIDIR)/*.pas) $(wildcard $(COMMONDIR)/*.pas)
	$(FPC) $(FPCFLAGS) $(API_PATH) $(UNITOUT) $(BINOUT) $(APIDIR)/lora_api.lpr

$(OUTDIR)/msgbase_lib$(LIBEXT): $(wildcard $(MSGBASEDIR)/*.pas) $(wildcard $(COMMONDIR)/*.pas)
	$(FPC) $(FPCFLAGS) $(MSGBASE_PATH) $(UNITOUT) $(BINOUT) $(MSGBASEDIR)/msgbase_lib.lpr

# Tool builds - all tools get full search paths for static linking
$(OUTDIR)/luser$(EXEEXT): $(TOOLSDIR)/luser.lpr
	$(FPC) $(FPCFLAGS) $(ALL_PATHS) $(UNITOUT) $(BINOUT) $(TOOLSDIR)/luser.lpr

$(OUTDIR)/lfile$(EXEEXT): $(TOOLSDIR)/lfile.lpr
	$(FPC) $(FPCFLAGS) $(ALL_PATHS) $(UNITOUT) $(BINOUT) $(TOOLSDIR)/lfile.lpr

$(OUTDIR)/lmsg$(EXEEXT): $(TOOLSDIR)/lmsg.lpr
	$(FPC) $(FPCFLAGS) $(ALL_PATHS) $(UNITOUT) $(BINOUT) $(TOOLSDIR)/lmsg.lpr

$(OUTDIR)/snoop$(EXEEXT): $(TOOLSDIR)/snoop.lpr
	$(FPC) $(FPCFLAGS) $(ALL_PATHS) $(UNITOUT) $(BINOUT) $(TOOLSDIR)/snoop.lpr

clean:
	rm -rf $(OUTDIR)
