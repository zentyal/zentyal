## Process this file with automake to produce Makefile.in
perldir = @PERLPATH@/EBox/Mail

SUBDIRS = Model

regular_packages = FilterProvider.pm ImportFromLdif.pm

test_packages = Test.pm

nobase_perl_DATA=  $(regular_packages)

DISTCLEANFILES = 

EXTRA_DIST = $(regular_packages) $(test_packages)

MAINTAINERCLEANFILES = Makefile.in
