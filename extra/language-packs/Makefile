all:
	./generate-mos po zentyal

install: all
	mkdir -p $(DESTDIR)/usr/share/locale
	cp -a dist/* $(DESTDIR)/usr/share/locale/

clean:
	rm -rf dist

