## Process this file with automake to produce Makefile.in
SUBDIRS = Report

perldir = @PERLPATH@/EBox/MailFilter/Composite


nobase_perl_DATA =  Amavis.pm  ExternalConnections.pm \
	             FileFilter.pm  Antispam.pm

DISTCLEANFILES =

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in