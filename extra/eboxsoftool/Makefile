eboxsofttool:
	g++ -lapt-pkg -o eboxsofttool eboxsofttool.cc

clean:
	rm -f eboxsofttool

install: eboxsofttool
	install eboxsofttool $(DESTDIR)/usr/bin 
