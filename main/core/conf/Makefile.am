## Process this file with automake to produce Makefile.in

SUBDIRS = logrotate hooks

Etcdir = $(sysconfdir)/zentyal
Etc_DATA = events.conf logs.conf core.conf

Presavedir = $(Etcdir)/pre-save
Presave_DATA =

Postsavedir = $(Etcdir)/post-save
Postsave_DATA =

Confdir = $(localstatedir)/lib/zentyal/conf
Conf_DATA = ebox.passwd redis.first

EXTRA_DIST = $(Conf_DATA) $(Etc_DATA)

MAINTAINERCLEANFILES = Makefile.in

DISTCLEANFILES =
