## Process this file with automake to produce Makefile.in

scriptsdir = @LIBDIR@/ebox

scripts_SCRIPTS = dhcp-nameservers.pl dhcp-address.pl \
	dhcp-clear.pl dhcp-gateway.pl dhcp-clear-gateway.pl \
	ebox-traffic-monitor ebox-traffic-monitor-logger

dhcpdir = /etc/dhcp3/dhclient-exit-hooks.d
dhcp_DATA = ebox


MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(scripts_SCRIPTS) 

DISTCLEANFILES = ebox