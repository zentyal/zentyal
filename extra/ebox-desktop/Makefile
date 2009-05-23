PREFIX = /usr/local
DATADIR = $(PREFIX)/share/ebox-desktop
SBINDIR = $(PREFIX)/sbin
EXPORT = ebox-package-build

distclean:
	rm -rf $(EXPORT)
	rm -f ebox-package.tar.gz
	rm -f ebox-package_*
	rm -f *.deb

export: distclean
	svn export . $(EXPORT)

dist: export
	tar cvvzf ebox-package.tar.gz $(EXPORT)

deb: dist
	cd $(EXPORT) && dpkg-buildpackage -rfakeroot -uc -us

install:
	install -d $(DESTDIR)$(SBINDIR)
	install -m755 ebox-setup-client $(DESTDIR)$(SBINDIR)
	install -d $(DESTDIR)$(DATADIR)/skel
	cp -a templates/* $(DESTDIR)$(DATADIR)/skel
	install -m755 ebox-setup-user $(DESTDIR)$(DATADIR)
	install -m644 ldap.conf $(DESTDIR)$(DATADIR)

uninstall:
	rm -f $(DESTDIR)$(SBINDIR)/ebox-setup-client
	rm -rf $(DESTDIR)$(DATADIR)

