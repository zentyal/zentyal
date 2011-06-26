
all : bwmonitor.cpp bwstats
	g++ -Wall -lpcap bwmonitor.cpp bwstats.o -o bwmonitor

bwstats : bwstats.h bwstats.cpp
	g++ -Wall -c bwstats.cpp

clean :
	rm *.o bwmonitor

