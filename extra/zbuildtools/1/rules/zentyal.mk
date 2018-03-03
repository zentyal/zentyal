include /usr/share/cdbs/1/rules/debhelper.mk

$(patsubst %,binary-install/%,$(DEB_PACKAGES)) :: binary-install/%:
	for event in debian/*.service ; do \
		[ -f $$event ] || continue; \
		install -d -m 755 debian/$(DEB_SOURCE_PACKAGE)/lib/systemd/system; \
		DESTFILE=$$(basename $$event); \
		install -m 644 "$$event" debian/$(DEB_SOURCE_PACKAGE)/lib/systemd/system/$$DESTFILE; \
	done;

common-install-indep::
	zentyal-install-module $(CURDIR)/debian/$(DEB_SOURCE_PACKAGE)/
