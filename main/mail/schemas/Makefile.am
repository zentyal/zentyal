## Process this file with automake to produce Makefile.in

SUBDIRS = sql

moduledir   = @DATADIR@/zentyal/modules
module_DATA = mail.yaml

pkgdata_DATA = authldap.ldif eboxmail.ldif eboxfetchmail.ldif eboxmailrelated.ldif

EXTRA_DIST = $(module_DATA) $(pkgdata_DATA)

MAINTAINERCLEANFILES = Makefile.in
