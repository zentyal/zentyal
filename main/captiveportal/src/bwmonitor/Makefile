
all : bwmonitor.cpp bwstats dumpers
	g++ -Wall -lpcap -lconfig bwstats.o console.o bwmonitor.cpp -o bwmonitor

bwstats : bwstats.h bwstats.cpp
	g++ -Wall -c bwstats.cpp

dumpers : bwstats.h consoledumper

consoledumper : dumpers/console.h dumpers/console.cpp
	g++ -Wall -c dumpers/console.cpp

clean :
	rm *.o bwmonitor

