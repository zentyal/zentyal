## Process this file with automake to produce Makefile.in
SUBDIRS=Report

perldir = @PERLPATH@/EBox/Firewall/Model

nobase_perl_DATA = InternalToEBoxRuleTable.pm ToInternetRuleTable.pm \
		ExternalToEBoxRuleTable.pm  EBoxOutputRuleTable.pm \
		ExternalToInternalRuleTable.pm BaseRuleTable.pm

DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
