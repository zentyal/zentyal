CFLAGS = -Wall -fPIC
LIBS =
CC = gcc

SAMBA_SOURCE = /home/samuel/Zentyal/packages/samba4/samba
INC=-I${SAMBA_SOURCE} \
    -I${SAMBA_SOURCE}/source3/include \
    -I${SAMBA_SOURCE}/lib/replace \
    -I${SAMBA_SOURCE}/lib/tdb/include \
    -I${SAMBA_SOURCE}/librpc \
    -I${SAMBA_SOURCE}/lib/popt \
    -I${SAMBA_SOURCE}/lib/talloc \
    -I${SAMBA_SOURCE}/lib/tevent \
    -I${SAMBA_SOURCE}/bin/default/include \
    -I${SAMBA_SOURCE}/source3/autoconf \
    -I${SAMBA_SOURCE}/source3


all: zavs.so

zavs.so: zavs_param.o zavs_core.o zavs_log.o zavs_module.o
	$(CC) $(CFLAGS) -shared zavs_param.o zavs_core.o zavs_log.o zavs_module.o -o zavs.so $(LIBS)

%.o: %.c
	$(CC) $(INC) $(CFLAGS) -c $<

%.c: $<.h

clean:
	rm -f *.o
	rm -f *.so

#install: all
#	mkdir -p $(DESTDIR)/usr/lib/$(DEB_HOST_MULTIARCH)/samba/ldb
#	install -m644 zentyal.so $(DESTDIR)/usr/lib/$(DEB_HOST_MULTIARCH)/samba/ldb
