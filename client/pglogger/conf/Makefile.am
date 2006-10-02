## Process this file with automake to produce Makefile.in

Etcdir = $(sysconfdir)/ebox
Etc_DATA = 90eboxpglogger.conf

Pgpassdir   = $(localstatedir)/lib/ebox
Pgpass_DATA = .pgpass

eboxuser = ebox
eboxgroup = ebox
PgpassInstalledFile = $(localstatedir)/lib/ebox/.pgpass

install-data-hook:
	chmod 0666 $(sysconfdir)/ebox/90eboxpglogger.conf
	chmod 0600 $(PgpassInstalledFile)
	chown $(eboxuser).$(eboxgroup) $(PgpassInstalledFile)

EXTRA_DIST = $(Etc_DATA) $(Pgpass_DATA)

MAINTAINERCLEANFILES = Makefile.in
