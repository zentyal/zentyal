## Process this file with automake to produce Makefile.in

SUBDIRS = period

Sqldir = @DATADIR@/zentyal-mailfilter/sql/

nobase_Sql_DATA = mailfilter_smtp.sql mailfilter_smtp_report.sql mailfilter_pop.sql mailfilter_pop_report.sql
pkgdata_SCRIPTS = spamassassin.sql

EXTRA_DIST = $(nobase_Sql_DATA) $(pkgdata_SCRIPTS)

MAINTAINERCLEANFILES = Makefile.in
