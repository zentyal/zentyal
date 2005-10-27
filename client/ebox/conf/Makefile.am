## Process this file with automake to produce Makefile.in

Etcdir = $(sysconfdir)/ebox
Etc_DATA = 80eboxclient.conf

SSLCertdir = $(sysconfdir)/ebox/ssl.crt
SSLCert_DATA = ebox.cert

SSLKeydir = $(sysconfdir)/ebox/ssl.key
SSLKey_DATA = ebox.key

Passwddir = $(localstatedir)/lib/ebox/conf
Passwd_DATA = ebox.passwd

EXTRA_DIST = $(Passwd_DATA) $(Etc_DATA) $(SSLCert_DATA) $(SSLKey_DATA)

MAINTAINERCLEANFILES = Makefile.in

DISTCLEANFILES = .gconf.path
