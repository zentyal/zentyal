## Process this file with automake to produce Makefile.in
SUBDIRS = Server t

perldir = @PERLPATH@/EBox/OpenVPN

nobase_perl_DATA = Server.pm

test_classes = Test.pm

DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA) $(test_classes)

MAINTAINERCLEANFILES = Makefile.in
