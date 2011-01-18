DEB_CONFIGURE_SCRIPT_ENV += LOGPATH="/var/log/zentyal"
DEB_CONFIGURE_SCRIPT_ENV += CONFPATH="/var/lib/zentyal/conf"
DEB_CONFIGURE_SCRIPT_ENV += STUBSPATH="/usr/share/zentyal/stubs"
DEB_CONFIGURE_SCRIPT_ENV += CGIPATH="/usr/share/zentyal/cgi/"
DEB_CONFIGURE_SCRIPT_ENV += TEMPLATESPATH="/usr/share/zentyal/templates"
DEB_CONFIGURE_SCRIPT_ENV += WWWPATH="/usr/share/zentyal/www/"
DEB_CONFIGURE_SCRIPT_ENV += CSSPATH="/usr/share/zentyal/www/css"
DEB_CONFIGURE_SCRIPT_ENV += IMAGESPATH="/usr/share/zentyal/www/images"
DEB_CONFIGURE_SCRIPT_ENV += VARPATH="/var"
DEB_CONFIGURE_SCRIPT_ENV += ETCPATH="/etc/zentyal"

DEB_CONFIGURE_EXTRA_FLAGS := --disable-runtime-tests 
DEB_MAKE_INVOKE = $(MAKE) $(DEB_MAKE_FLAGS) -C $(DEB_BUILDDIR)

$(patsubst %,binary-install/%,$(DEB_PACKAGES)) :: binary-install/%:

