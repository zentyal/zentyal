PREFIX = /usr/local
DATADIR = $(PREFIX)/share/ebox-desktop
SBINDIR = $(PREFIX)/sbin
EXPORT = ebox-desktop-build

distclean:
	rm -rf $(EXPORT)
	rm -f ebox-desktop.tar.gz
	rm -f ebox-desktop_*
	rm -f *.deb

export: distclean
	svn export . $(EXPORT)

dist: export
	tar cvvzf ebox-desktop.tar.gz $(EXPORT)

deb: dist
	cd $(EXPORT) && dpkg-buildpackage -rfakeroot -uc -us

install:
	install -d $(DESTDIR)$(SBINDIR)
	install -m755 ebox-setup-client $(DESTDIR)$(SBINDIR)
	install -d $(DESTDIR)$(DATADIR)/skel
	cp -a templates/* $(DESTDIR)$(DATADIR)/skel
	install -m755 ebox-setup-user $(DESTDIR)$(DATADIR)
	install -m755 ebox-user-shares $(DESTDIR)$(DATADIR)
	install -m755 ebox-firefox-profile $(DESTDIR)$(DATADIR)
	install -m755 ebox-jabber-setup $(DESTDIR)$(DATADIR)
	install -m755 ekiga-launcher $(DESTDIR)$(DATADIR)
	install -m644 ldap.conf $(DESTDIR)$(DATADIR)
	install -d $(DESTDIR)/etc/ebox-desktop
	install -m644 ebox-desktop.conf $(DESTDIR)/etc/ebox-desktop

uninstall:
	rm -f $(DESTDIR)$(SBINDIR)/ebox-setup-client
	rm -rf $(DESTDIR)/etc/ebox-desktop
	rm -rf $(DESTDIR)$(DATADIR)

