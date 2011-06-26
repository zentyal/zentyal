
all : bwmonitor.cpp bwstats
	g++ -lpcap bwmonitor.cpp -o bwmonitor

bwstats : bwstats.h bwstats.cpp
	g++ -c bwstats.cpp

clean :
	rm *.o bwmonitor

