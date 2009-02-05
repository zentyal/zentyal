## Process this file with automake to produce Makefile.
SUBDIRS=Report

perldir = @PERLPATH@/EBox/Squid/Composite

nobase_perl_DATA =  General.pm \
	 FilterTabs.pm FilterSettings.pm  \
         Extensions.pm MIME.pm Domains.pm \
         FilterGroupSettings.pm FilterGroupTabs.pm \
	 FilterGroupExtensions.pm FilterGroupMIME.pm  FilterGroupDomains.pm


DISTCLEANFILES =

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

