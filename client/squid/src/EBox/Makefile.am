## Process this file with automake to produce Makefile.in
SUBDIRS = CGI

perldir = @PERLPATH@/EBox

nobase_perl_DATA = Squid.pm SquidFirewall.pm SquidOnlyFirewall.pm \
			SquidLogHelper.pm

SOURCES = $(nobase_perl_DATA)

DISTCLEANFILES = Squid.pm 

EXTRA_DIST = SquidFirewall.pm SquidOnlyFirewall.pm

MAINTAINERCLEANFILES = Makefile.in
