## Process this file with automake to produce Makefile.in
SUBDIRS = ClamAV SpamAssassin  FileFilter  t

perldir = @PERLPATH@/EBox/MailFilter

nobase_perl_DATA = ClamAV.pm SpamAssassin.pm  VDomainsLdap.pm FirewallHelper.pm  FileFilter.pm  Test.pm  

DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
