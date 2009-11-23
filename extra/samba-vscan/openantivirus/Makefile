#
# Makefile for vscan-oav, part of samba-vscan
#
# $Id: Makefile,v 1.8 2003/01/29 23:53:08 reniar Exp $
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
VFS_OBJS = vscan-oav.so
SOURCES = $(SMBVS_GLB)/vscan-functions.c $(SMBVS_GLB)/vscan-message.c $(SMBVS_GLB)/vscan-quarantine.c $(SMBVS_GLB)/vscan-fileaccesslog.c vscan-oav.c vscan-oav_core.c vscan-oav.h vscan-oav_core.h
OBJS = vscan-functions.lo vscan-message.lo vscan-quarantine.lo vscan-fileaccesslog.lo vscan-oav.lo vscan-oav_core.lo
LIBS = 

# Default target

all: $(VFS_OBJS)

vscan-oav.so: $(SOURCES)
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-functions.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-message.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-quarantine.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-fileaccesslog.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c vscan-oav_core.c
	$(LIBTOOL) $(CC) $(CPPFLAGS) $(CFLAGS) -c vscan-oav.c
	$(LIBTOOL) $(CC) -shared $(LDFLAGS) $(LIBS) $(OBJS) -o vscan-oav.so


# Misc targets

clean:
	rm -rf .libs
	rm -f core *~ *% *.bak *.so *.lo *.o
		
