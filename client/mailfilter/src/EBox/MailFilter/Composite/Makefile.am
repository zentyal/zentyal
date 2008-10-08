## Process this file with automake to produce Makefile.in
SUBDIRS = Report

perldir = @PERLPATH@/EBox/MailFilter/Composite


nobase_perl_DATA =  Index.pm GeneralAndBadHeader.pm ExternalConnections.pm \
	             FileFilter.pm Antivirus.pm Antispam.pm

DISTCLEANFILES =

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in