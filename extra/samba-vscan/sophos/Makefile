#
# Makefile for vscan-sophos, part of samba-vscan
#
# $Id: Makefile,v 1.15 2003/01/29 23:53:08 reniar Exp $
#

# Variables

CC = gcc
LIBTOOL = libtool

SAMBA_SRC = ../../../../source
SAMBA_INCL = ../../../../source/include
UBIQX_SRC = ../../../../source/ubiqx
SMBWR_SRC = ../../../../source/smbwrapper
SMBVS_INCL = ../include
SMBVS_GLB = ../global
CFLAGS = -I$(SAMBA_SRC) -I$(SAMBA_INCL) -I$(UBIQX_SRC) -I$(SMBWR_SRC) -I$(SMBVS_INCL) -Wall -g -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -fPIC 
VFS_OBJS = vscan-sophos.so
SOURCES = $(SMBVS_GLB)/vscan-functions.c $(SMBVS_GLB)/vscan-message.c $(SMBVS_GLB)/vscan-quarantine.c $(SMBVS_GLB)/vscan-fileaccesslog.c vscan-sophos.c vscan-sophos_core.c vscan-sophos.h vscan-sophos_core.h
OBJS = vscan-functions.lo vscan-message.lo vscan-quarantine.lo vscan-fileaccesslog.lo vscan-sophos.lo vscan-sophos_core.lo
LIBS = 


# Default target

all: $(VFS_OBJS)

vscan-sophos.so: $(SOURCES)
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-functions.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-message.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-quarantine.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-fileaccesslog.c
	$(LIBTOOL) $(CC) $(CPPFLAGS) $(CFLAGS) -c vscan-sophos_core.c
	$(LIBTOOL) $(CC) $(CPPFLAGS) $(CFLAGS) -c vscan-sophos.c
	$(LIBTOOL) $(CC) -shared $(LDFLAGS) $(LIBS) $(OBJS) -o vscan-sophos.so


# Misc targets

clean:
	rm -rf .libs
	rm -f core *~ *% *.bak *.so *.lo *.o
		
