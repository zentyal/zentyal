## Process this file with automake to produce Makefile.in
SUBDIRS = sqllog

Sqlsetupdir = @DATADIR@/zentyal-mailfilter/sql

pkgdata_SCRIPTS = initial-setup ebox-mailfilter-ldap \
		 enable-module ebox-mailfilter-sql saLearn.pl

MAINTAINERCLEANFILES = Makefile.in

nobase_Sqlsetup_DATA = spamassassin.sql

EXTRA_DIST = $(pkgdata_SCRIPTS) $(nobase_Sqlsetup_DATA)
