## Process this file with automake to produce Makefile.in
SUBDIRS = t

perldir = @PERLPATH@/EBox/Report

packages = DiskUsage.pm  DiskUsageProvider.pm RAID.pm NetworkUsage.pm

nobase_perl_DATA = $(packages)



SOURCES = $(nobase_perl_DATA)

EXTRA_DIST = $(packages)

MAINTAINERCLEANFILES = Makefile.in
