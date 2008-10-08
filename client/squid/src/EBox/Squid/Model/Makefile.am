## Process this file with automake to produce Makefile.
SUBDIRS = Report

perldir = @PERLPATH@/EBox/Squid/Model

nobase_perl_DATA = GeneralSettings.pm ContentFilterThreshold.pm\
  ExtensionFilter.pm MIMEFilter.pm ObjectPolicy.pm \
  DomainFilter.pm  DomainFilterSettings.pm  \
  ApplyAllowToAllBase.pm ApplyAllowToAllExtensions.pm ApplyAllowToAllMIME.pm

DISTCLEANFILES =

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

