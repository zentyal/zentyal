CC = gcc
INC = -I/usr/include -I/usr/local/include -I/home/zen/samba/bin/default/include/public -I/usr/lib/perl/5.14.2/CORE
LIB = -L/home/zen/samba/bin/default/lib/ldb

default: all

all:
	$(CC) $(INC) -c zentyal.c
	$(CC) $(LIB) -shared -Wl,-soname,zentyal.so.1 -o zentyal.so.1.0.1  zentyal.o -lperl -lldb

clean:
	rm -f *.o *.so.*

install:
	cp zentyal.so.1.0.1 /usr/local/samba/lib/ldb/zentyal.so
