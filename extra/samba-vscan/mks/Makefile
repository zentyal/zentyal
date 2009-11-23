#
# Makefile for vscan-mksd, part of samba-vscan
#

# Variables

#if set to "1", the included libmksd library will be used
#USE_INCLMKSDLIB=1

CC = gcc
LIBTOOL = libtool

SAMBA_SRC = ../../../../source
SAMBA_INCL = ../../../../source/include
UBIQX_SRC = ../../../../source/ubiqx
SMBWR_SRC = ../../../../source/smbwrapper
SMBVS_INCL = ../include
SMBVS_GLB = ../global
CFLAGS = -I$(SAMBA_SRC) -I$(SAMBA_INCL) -I$(UBIQX_SRC) -I$(SMBWR_SRC) -I$(SMBVS_INCL) -Wall -g -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -fPIC 

ifdef USE_INCLMKSDLIB
CFLAGS=-I$(SAMBA_SRC) -I$(SAMBA_INCL) -I$(UBIQX_SRC) -I$(SMBWR_SRC) -I$(SMBVS_INCL) -Wall -g -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D_USE_INCL_MKSD_LIB=1 -fPIC
endif

VFS_OBJS = vscan-mksd.so
SOURCES = $(SMBVS_GLB)/vscan-functions.c $(SMBVS_GLB)/vscan-message.c $(SMBVS_GLB)/vscan-quarantine.c $(SMBVS_GLB)/vscan-fileaccesslog.c vscan-mksd.c vscan-mksd_core.c vscan-mksd.h vscan-mksd_core.h
OBJS = vscan-functions.lo vscan-message.lo vscan-quarantine.lo vscan-fileaccesslog.lo vscan-mksd.lo vscan-mksd_core.lo

ifndef USE_INCLMKSDLIB
LIBS = -lmksd 
else
LIBS = -L./libmksd -lmksd
endif

# Default target

all: $(VFS_OBJS)

vscan-mksd.so: $(SOURCES)
ifdef USE_INCLMKSDLIB
	$(CC) -Wall -O2 -c libmksd/libmksd.c -o libmksd/libmksd.o
	strip -x libmksd/libmksd.o
	ar -rc libmksd/libmksd.a libmksd/libmksd.o
	ranlib libmksd/libmksd.a
endif
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-functions.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-message.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-quarantine.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c $(SMBVS_GLB)/vscan-fileaccesslog.c
	$(LIBTOOL) $(CC) $(CFLAGS) -c vscan-mksd_core.c
	$(LIBTOOL) $(CC) $(CPPFLAGS) $(CFLAGS) -c vscan-mksd.c
	$(LIBTOOL) $(CC) -shared $(LDFLAGS) $(LIBS) $(OBJS) -o vscan-mksd.so


# Misc targets

clean:
	rm -rf .libs
	rm -f core *~ *% *.bak *.so *.lo *.o *.a
ifdef USE_INCLMKSDLIB
	rm -f libmksd/*.a libmksd/*.o
endif		
		

