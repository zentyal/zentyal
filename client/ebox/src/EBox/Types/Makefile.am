## Process this file with automake to produce Makefile.in

SUBDIRS = Union

perldir = @PERLPATH@/EBox/Types

nobase_perl_DATA = Abstract.pm  Basic.pm  Boolean.pm  Int.pm  Text.pm \
		   Select.pm IPAddr.pm Union.pm MACAddr.pm Service.pm \
		   HasMany.pm PortRange.pm InverseMatchSelect.pm \
		   InverseMatchUnion.pm Password.pm Link.pm

SOURCES = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
