## Process this file with automake to produce Makefile.in

scriptsdir = @DATADIR@/ebox

scripts_SCRIPTS = dhcp-nameservers.pl dhcp-address.pl \
	dhcp-clear.pl dhcp-gateway.pl dhcp-clear-gateway.pl \
	ebox-traffic-monitor ebox-traffic-monitor-logger

dhcpenterdir = /etc/dhcp3/dhclient-enter-hooks.d
dhcpenter_DATA = ebox-enter

dhcpexitdir = /etc/dhcp3/dhclient-exit-hooks.d
dhcpexit_DATA = ebox-exit


MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(scripts_SCRIPTS) $(dhcpenter_DATA) $(dhcpexit_DATA)

DISTCLEANFILES = ebox
