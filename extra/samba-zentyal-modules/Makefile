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
	install -m644 zentyal.so $(DESTDIR)/usr/lib/i386-linux-gnu/samba/ldb
