PREFIX = /usr/local
DATADIR = $(PREFIX)/share/zentyal-desktop
SBINDIR = $(PREFIX)/sbin
ifeq ($(PREFIX),/usr/local)
    LIBPERL = $(PREFIX)/lib/site_perl
else
    LIBPERL = $(PREFIX)/share/perl5
endif
EXPORT = zentyal-desktop-build


distclean:
	rm -rf $(EXPORT)
	rm -f zentyal-desktop.tar.gz
	rm -f zentyal-desktop_*
	rm -f *.deb

export: distclean
	svn export . $(EXPORT)
	svn export ../common $(EXPORT)/common

dist: export
	tar cvvzf zentyal-desktop.tar.gz $(EXPORT)

deb: dist
	cd $(EXPORT) && dpkg-buildpackage -rfakeroot -uc -us

install:
	install -d $(DESTDIR)$(SBINDIR)
	install -m755 zentyal-setup-client $(DESTDIR)$(SBINDIR)
	install -d $(DESTDIR)$(DATADIR)/skel
	cp -a templates/* $(DESTDIR)$(DATADIR)/skel
	cp -a common/templates/* $(DESTDIR)$(DATADIR)/skel
	install -m755 zentyal-prepare-home $(DESTDIR)$(DATADIR)
	install -m755 zentyal-setup-user $(DESTDIR)$(DATADIR)
	cp -a tools/* $(DESTDIR)$(DATADIR)
	install -m644 ldap.conf $(DESTDIR)$(DATADIR)
	install -m644 zentyal.pam $(DESTDIR)$(DATADIR)
	install -d $(DESTDIR)$(LIBPERL)/ZentyalDesktop
	cp -a common/ZentyalDesktop/* $(DESTDIR)$(LIBPERL)/ZentyalDesktop
	cp -a ZentyalDesktop/* $(DESTDIR)$(LIBPERL)/ZentyalDesktop
	install -d $(DESTDIR)/etc/zentyal-desktop
	install -m644 zentyal-desktop.conf $(DESTDIR)/etc/zentyal-desktop

uninstall:
	rm -f $(DESTDIR)$(SBINDIR)/zentyal-setup-client
	rm -rf $(DESTDIR)/etc/zentyal-desktop
	rm -rf $(DESTDIR)$(DATADIR)
	rm -rf $(DESTDIR)$(LIBPERL)/ZentyalDesktop

