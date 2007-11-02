## Process this file with automake to produce Makefile.in
SUBDIRS = t

perldir = @PERLPATH@/EBox/DHCP/Model

nobase_perl_DATA = AdvancedOptions.pm FixedAddressTable.pm \
	 Options.pm RangeInfo.pm RangeTable.pm 

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
