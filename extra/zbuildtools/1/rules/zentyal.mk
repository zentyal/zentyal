include /usr/share/cdbs/1/rules/debhelper.mk

$(patsubst %,binary-install/%,$(DEB_PACKAGES)) :: binary-install/%:
	for event in debian/*.upstart ; do \
		[ -f $$event ] || continue; \
		install -d -m 755 debian/$(cdbs_curpkg)/etc/init; \
		DESTFILE=$$(basename $$(echo $$event | sed 's/\.upstart/.conf/g')); \
		install -m 644 "$$event" debian/$(cdbs_curpkg)/etc/init/$$DESTFILE; \
	done;

common-install-indep::
	zentyal-install-module $(DEB_DESTDIR)
