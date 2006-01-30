esofttool: esofttool.cc
	g++ -Wall -lapt-pkg -o esofttool esofttool.cc

clean:
	rm -f esofttool

install: esofttool
	install esofttool $(DESTDIR)/usr/bin 
