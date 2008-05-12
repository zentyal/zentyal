# change to yes when building the package with md quota support
MD_QUOTA=no

DEB_CONFIGURE_SCRIPT_ENV += LOGPATH="/var/log/ebox"
DEB_CONFIGURE_SCRIPT_ENV += CONFPATH="/var/lib/ebox/conf"
DEB_CONFIGURE_SCRIPT_ENV += STUBSPATH="/usr/share/ebox/stubs"
DEB_CONFIGURE_SCRIPT_ENV += CGIPATH="/usr/share/ebox/cgi/"
DEB_CONFIGURE_SCRIPT_ENV += TEMPLATESPATH="/usr/share/ebox/templates"
DEB_CONFIGURE_SCRIPT_ENV += SCHEMASPATH="/usr/share/ebox/schemas"
DEB_CONFIGURE_SCRIPT_ENV += WWWPATH="/usr/share/ebox/www/"
DEB_CONFIGURE_SCRIPT_ENV += CSSPATH="/usr/share/ebox/www/css"
DEB_CONFIGURE_SCRIPT_ENV += IMAGESPATH="/usr/share/ebox/www/images"
DEB_CONFIGURE_SCRIPT_ENV += VARPATH="/var"
DEB_CONFIGURE_SCRIPT_ENV += ETCPATH="/etc/ebox"
DEB_CONFIGURE_SCRIPT_ENV += MD_QUOTA="no"


DEB_CONFIGURE_EXTRA_FLAGS := --disable-runtime-tests 
DEB_MAKE_FLAGS += schemadir=usr/share/gconf/schemas
DEB_MAKE_INVOKE = $(MAKE) $(DEB_MAKE_FLAGS) -C $(DEB_BUILDDIR)

$(patsubst %,binary-install/%,$(DEB_PACKAGES)) :: binary-install/%:
	for event in debian/*.upstart ; do \
		[ -f $$event ] || continue; \
		install -d -m 755 debian/$(cdbs_curpkg)/etc/event.d; \
		DESTFILE=$$(basename $$(echo $$event | sed 's/\.upstart//g')); \
		install -m 644 "$$event" debian/$(cdbs_curpkg)/etc/event.d/$$DESTFILE; \
	done;


postfix_deps=
ifeq ($(MD_QUOTA), yes)
	postfix_deps=postfix \(>= 2.4.5-3ubuntu1.ebox1\), postfix-ldap \(>= 2.4.5-3ubuntu1.ebox1\)
  DEB_CONFIGURE_EXTRA_FLAGS += MD_QUOTA=yes
else
	postfix_deps=postfix, postfix-ldap
endif




binary-predeb/ebox-mail::
	sed  "s/@POSTFIX_DEPS@/$(postfix_deps)/"   debian/control.in > debian/control 

