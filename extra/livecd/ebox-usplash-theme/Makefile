CC=gcc
CFLAGS=-g -Wall -fPIC
LDFLAGS=
INCLUDES=

COMPILE = $(CC) $(INCLUDES) $(CFLAGS)
LINK = $(CC) $(CFLAGS) $(LDFLAGS)

INSTALL = /usr/bin/install -c
INSTALL_DATA = $(INSTALL) -m 644
INSTALL_PROGRAM = $(INSTALL) -m 755

ebox-theme.so: ebox_1024_576_cropped.png.c.o ebox_1024_768.png.c.o ebox_800_600.png.c.o ebox_640_480.png.c.o throbber_fore.png.c.o throbber_back.png.c.o ebox-theme.c.o helvB10.bdf.c.o
	$(COMPILE) -shared -o $@ $^
	
%.png.c: %.png
	pngtousplash $< > $@

%.bdf.c: %.bdf
	bdftousplash $< > $@

%.c.o: %.c
	$(COMPILE) -o $@ -c $<

install:
	$(INSTALL) -d $(DESTDIR)/usr/lib/usplash
	$(INSTALL_PROGRAM) ebox-theme.so $(DESTDIR)/usr/lib/usplash/ebox-theme.so
clean:
	rm -f *.png.c *.bdf.c *.c.o *.so
