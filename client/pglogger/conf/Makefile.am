## Process this file with automake to produce Makefile.in

Etcdir = $(sysconfdir)/ebox
Etc_DATA = 90eboxpglogger.conf

Pgpassdir   = $(localstatedir)/lib/ebox
Pgpass_DATA = .pgpass

install-data-hook:
	chmod 0660 $(sysconfdir)/ebox/90eboxpglogger.conf
	chmod 0600 $(localstatedir)/lib/ebox/.pgpass

EXTRA_DIST = $(Etc_DATA) $(Pgpass_DATA)

MAINTAINERCLEANFILES = Makefile.in
