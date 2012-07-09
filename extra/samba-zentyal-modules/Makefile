CFLAGS = -Wall -fPIC
LIBS = -lldb -lm -ljansson
CC = gcc

all: zentyal.so

zentyal.so: zentyal.o
	$(CC) $(CFLAGS) -shared zentyal.o -o zentyal.so $(LIBS)

zentyal.o: zentyal.c
	$(CC) $(CFLAGS) -c zentyal.c

zentyal.c:

clean:
	rm -f *.o
	rm -f *.so

install: all
	mkdir -p $(DESTDIR)/usr/lib/$(DEB_HOST_MULTIARCH)/samba/ldb
	install -m644 zentyal.so $(DESTDIR)/usr/lib/$(DEB_HOST_MULTIARCH)/samba/ldb
