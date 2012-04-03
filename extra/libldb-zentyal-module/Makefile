CC = gcc

INC = -I/home/zen/samba/bin/default/include/public
LIB = -L/home/zen/samba/bin/default/lib/ldb

default: all

all: zentyal.so

zentyal.so: perlxsi.o zentyal.o
	$(CC) -shared zentyal.o perlxsi.o -o zentyal.so $(LIB) `perl -MExtUtils::Embed -e ldopts` -lldb

perlxsi.o:
	rm -f perlxsi.c
	perl -MExtUtils::Embed -e xsinit
	$(CC) -c perlxsi.c -fPIC `perl -MExtUtils::Embed -e ccopts`

zentyal.o: zentyal.c
	$(CC) $(INC) -c zentyal.c -fPIC `perl -MExtUtils::Embed -e ccopts`

zentyal.c:

clean:
	rm -f *.o
	rm -f *.so
	rm -f perlxsi.c

install:
	cp zentyal.so /usr/local/samba/lib/ldb/zentyal.so
