## Process this file with automake to produce Makefile.in

scriptsdir = @DATADIR@/ebox

scripts_SCRIPTS = dhcp-nameservers.pl dhcp-address.pl \
	dhcp-clear.pl dhcp-gateway.pl ppp-set-iface.pl \
	ebox-traffic-monitor ebox-traffic-monitor-logger

dhcpenterdir = /etc/dhcp3/dhclient-enter-hooks.d
dhcpenter_DATA = ebox-enter

dhcpexitdir = /etc/dhcp3/dhclient-exit-hooks.d
dhcpexit_DATA = ebox-exit

pppupdir = /etc/ppp/ip-up.d
pppup_SCRIPTS = ebox-ppp-up

pppdowndir = /etc/ppp/ip-down.d
pppdown_SCRIPTS = ebox-ppp-down


MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(scripts_SCRIPTS) $(dhcpenter_DATA) $(dhcpexit_DATA) \
             $(pppup_SCRIPTS) $(pppdown_SCRIPTS)

DISTCLEANFILES = ebox
