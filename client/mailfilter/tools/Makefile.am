## Process this file with automake to produce Makefile.in
SUBDIRS= sqllog

Sqlsetupdir = @DATADIR@/ebox-mailfilter/sql

pkgdata_SCRIPTS = ebox-mailfilter-ldap ebox-mailfilter-populate-filefilter \
		 ebox-mailfilter-enable ebox-mailfilter-sql \
		 saLearn.pl

MAINTAINERCLEANFILES = Makefile.in

nobase_Sqlsetup_DATA = spamassassin.sql

EXTRA_DIST = $(pkgdata_SCRIPTS) $(nobase_Sqlsetup_DATA)
