## Process this file with automake to produce Makefile.in

SUBDIRS = logrotate hooks

Etcdir = $(sysconfdir)/ebox
Etc_DATA = 70runitfinisher.conf 90eboxpglogger.conf 80eboxclient.conf

Presavedir = $(Etcdir)/pre-save
Presave_DATA =

Postsavedir = $(Etcdir)/post-save
Postsave_DATA =

Confdir = $(localstatedir)/lib/ebox/conf
Conf_DATA = ebox.passwd redis.first

EXTRA_DIST = $(Conf_DATA) $(Etc_DATA)

MAINTAINERCLEANFILES = Makefile.in

DISTCLEANFILES =
