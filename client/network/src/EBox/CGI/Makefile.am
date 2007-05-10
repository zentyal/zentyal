SUBDIRS = FirstTime Controller View
## Process this file with automake to produce Makefile.in

perldir = @PERLPATH@/EBox/CGI/Network

nobase_perl_DATA = DNS.pm Diag.pm Gateway.pm Iface.pm Ifaces.pm Nameservers.pm \
	Route.pm Routes.pm VIface.pm Vlan.pm EnableBalanceTraffic.pm

MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(nobase_perl_DATA)
