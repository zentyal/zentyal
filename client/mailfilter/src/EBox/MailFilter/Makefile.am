## Process this file with automake to produce Makefile.in
SUBDIRS = ClamAV  Model Composite Types t LogHelper

perldir = @PERLPATH@/EBox/MailFilter

nobase_perl_DATA = ClamAV.pm SpamAssassin.pm  VDomainsLdap.pm FirewallHelper.pm   Test.pm  ImportFromLdif.pm LogHelper.pm

test_classes = Test.pm ConsolidationTest.pm


DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA) $(test_classes)

MAINTAINERCLEANFILES = Makefile.in
