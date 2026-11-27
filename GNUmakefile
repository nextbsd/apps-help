#
# GNUmakefile: Help, NextBSD's help viewer (Help.app), based on HelpViewer.
#
# nextbsd-desktop installs it into /System/Library/CoreServices
# (Help_INSTALL_DIR); a plain `make install` puts it in the domain's
# Applications folder.
#
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

VERSION = 1.0
PACKAGE_NAME = Help
APP_NAME = Help
Help_APPLICATION_ICON = HelpViewer.tiff

# NextBSD Help, the system's own book, comes with Help.
Help_RESOURCE_FILES = \
Resources/HelpViewer.tiff \
Resources/Icon-hlpd.tiff \
Resources/NextBSD.help

Help_HEADER_FILES = \
HPBook.h \
HPController.h \
HPLibrary.h \
HPPage.h \
HPSidebar.h \
HPStyle.h \
HPXLP.h

Help_OBJC_FILES = \
HPBook.m \
HPController.m \
HPLibrary.m \
HPPage.m \
HPSidebar.m \
HPStyle.m \
HPXLP.m \
main.m

Help_OBJCFLAGS = -Wall -Wno-unused-parameter

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
