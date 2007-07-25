
config.status: configure
	dh_testdir
	LOGPATH="/var/lib/ebox/log" \
        CONFPATH="/var/lib/ebox/conf" \
        STUBSPATH="/usr/share/ebox/stubs" \
        CGIPATH="/usr/share/ebox/cgi/" \
        TEMPLATESPATH="/usr/share/ebox/templates" \
        SCHEMASPATH="/usr/share/ebox/schemas" \
        WWWPATH="/usr/share/ebox/www/" \
        CSSPATH="/usr/share/ebox/www/css" \
        IMAGESPATH="/usr/share/ebox/www/images" \
	VARPATH="/var" \
	ETCPATH="/etc/ebox" \
	./configure --disable-runtime-tests --prefix=/usr \
               --localstatedir=/var --sysconfdir=/etc

