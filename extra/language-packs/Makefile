all:
	./generate-mos po zentyal
	./generate-mos po/zentyal-subscription zentyal-subscription

install: all
	cp -a dist/* /usr/share/locale/

clean:
	rm -rf dist

