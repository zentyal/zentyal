CFLAGS = -Wall -fPIC
LIBS = -lpcre -lmagic -lclamav
CC = gcc

SAMBA_SOURCE = /home/samuel/Zentyal/packages/samba4/samba
INC=-I${SAMBA_SOURCE}/source3/include \
    -I${SAMBA_SOURCE}/lib/replace \
    -I${SAMBA_SOURCE}/bin/default/include \
    -I${SAMBA_SOURCE}/source3 \
    -I${SAMBA_SOURCE}/source3/autoconf \
    -I${SAMBA_SOURCE}


all: zavs.so

zavs.so: zavs_param.o zavs_core.o zavs_log.o zavs_module.o zavs_fileaccesslog.o zavs_filetype.o zavs_fileregexp.o zavs_clamav.o
	$(CC) $(CFLAGS) -shared \
    zavs_param.o \
    zavs_core.o \
    zavs_log.o \
    zavs_module.o \
    zavs_fileaccesslog.o \
    zavs_filetype.o \
    zavs_fileregexp.o \
    zavs_clamav.o \
    -o zavs.so $(LIBS)

%.o: %.c
	$(CC) $(INC) $(CFLAGS) -c $<

%.c: $<.h

clean:
	rm -f *.o
	rm -f *.so

install: all
	mkdir -p $(DESTDIR)/usr/lib/$(DEB_HOST_MULTIARCH)/samba/vfs
	install -m644 zavs.so $(DESTDIR)/usr/lib/$(DEB_HOST_MULTIARCH)/samba/vfs
