## Process this file with automake to produce Makefile.in
SUBDIRS = CGI

perldir = @PERLPATH@/EBox

nobase_perl_DATA = FirewallHelper.pm Firewall.pm Iptables.pm \
	FirewallObserver.pm

DISTCLEANFILES = 

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in
