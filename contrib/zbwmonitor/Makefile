FLAGS=-Wall -fpermissive
LIBS=-lpcap -lconfig
CC=g++

all: bwmonitor.cpp bwstats dumpers
	$(CC) $(FLAGS) bwstats.o console.o bwmonitor.cpp $(LIBS) -o zbwmonitor

bwstats: bwstats.h bwstats.cpp
	$(CC) $(FLAGS) -c bwstats.cpp

dumpers: bwstats.h consoledumper

consoledumper: dumpers/console.h dumpers/console.cpp
	$(CC) $(FLAGS) -c dumpers/console.cpp

install: all
	install -m755 zbwmonitor $(DESTDIR)/usr/sbin
	install -m644 CONF.EXAMPLE $(DESTDIR)/usr/share/doc/zbwmonitor

clean:
	rm -f *.o zbwmonitor

