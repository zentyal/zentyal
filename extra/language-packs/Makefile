all:
	./generate-mos po zentyal
	./generate-mos po/zentyal-subscription zentyal-subscription

install: all
	mkdir -p $(DESTDIR)/usr/share/locale
	cp -a dist/* $(DESTDIR)/usr/share/locale/

clean:
	rm -rf dist

