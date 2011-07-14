
all : bwmonitor.cpp bwstats dumpers
	g++ -Wall -lpcap -lconfig bwstats.o console.o bwmonitor.cpp -o zbwmonitor

bwstats : bwstats.h bwstats.cpp
	g++ -Wall -c bwstats.cpp

dumpers : bwstats.h consoledumper

consoledumper : dumpers/console.h dumpers/console.cpp
	g++ -Wall -c dumpers/console.cpp

install : all
	install -m755 zbwmonitor $(DESTDIR)/usr/sbin
	install -m644 CONF.EXAMPLE $(DESTDIR)/usr/share/doc/zbwmonitor

clean :
	rm *.o zbwmonitor

