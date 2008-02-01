VERSION := $(shell dpkg-parsechangelog | sed -n 's/^Version: //p')

ifeq (,$(INSTALL_PROGRAM))
    INSTALL_PROGRAM := "install"
endif

compile all: unblock-signals.so

install: unblock-signals.so
	install -d $(DESTDIR)/usr/lib/unblock-signals/
	$(INSTALL_PROGRAM) -o root -g root -m 644 unblock-signals.so $(DESTDIR)/usr/lib/unblock-signals/unblock-signals.so

unblock-signals.so: unblock-signals.o
	$(CC) -o $@ -shared $< -ldl -lc

unblock-signals.o: unblock-signals.c
	$(CC) -D_REENTRANT $(CFLAGS) -fpic -c -o $@ $<

clean:
	rm -f unblock-signals.o unblock-signals.so

