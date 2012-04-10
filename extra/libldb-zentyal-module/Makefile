CC = gcc

INC = -I/home/zen/samba/bin/default/include/public
LIB = -L/home/zen/samba/bin/default/lib/ldb

default: all

all: zentyal.so

zentyal.so: zentyal.o
	$(CC) -shared zentyal.o -o zentyal.so $(LIB) -lldb -ljansson

zentyal.o: zentyal.c
	$(CC) $(INC) -c zentyal.c -fPIC

zentyal.c:

clean:
	rm -f *.o
	rm -f *.so

install:
	cp zentyal.so /usr/local/samba/lib/ldb/zentyal.so
