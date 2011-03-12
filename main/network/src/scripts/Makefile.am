## Process this file with automake to produce Makefile.in

scriptsdir = @DATADIR@/zentyal-network

scripts_SCRIPTS = dhcp-nameservers.pl dhcp-address.pl \
	dhcp-clear.pl dhcp-gateway.pl ppp-set-iface.pl \
	traffic-monitor traffic-monitor-logger flush-fwmarks \
	setup-wireless bandwidth-test.pl


dhcpenterdir = /etc/dhcp3/dhclient-enter-hooks.d
dhcpenter_DATA = zentyal-dhcp-enter

dhcpexitdir = /etc/dhcp3/dhclient-exit-hooks.d
dhcpexit_DATA = zentyal-dhcp-exit

pppupdir = /etc/ppp/ip-up.d
pppup_SCRIPTS = zentyal-ppp-up

pppdowndir = /etc/ppp/ip-down.d
pppdown_SCRIPTS = zentyal-ppp-down


MAINTAINERCLEANFILES = Makefile.in

EXTRA_DIST = $(scripts_SCRIPTS) $(dhcpenter_DATA) $(dhcpexit_DATA) \
             $(pppup_SCRIPTS) $(pppdown_SCRIPTS)
