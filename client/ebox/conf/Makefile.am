## Process this file with automake to produce Makefile.in

SUBDIRS = logrotate

Etcdir = $(sysconfdir)/ebox
Etc_DATA = 70runitfinisher.conf 90eboxpglogger.conf  80eboxclient.conf


Passwddir = $(localstatedir)/lib/ebox/conf
Passwd_DATA = ebox.passwd

EXTRA_DIST = $(Passwd_DATA) $(Etc_DATA)  pgpass

MAINTAINERCLEANFILES = Makefile.in

DISTCLEANFILES = .gconf.path
