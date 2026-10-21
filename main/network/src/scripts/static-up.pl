#!/usr/bin/perl

# Copyright (C) 2026 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# Called by the NetworkManager dispatcher hook (zentyal-dhclient-hook) when a
# static interface is brought up. Unlike DHCP/PPP interfaces, static ones have
# no lease hook to regenerate the multi-WAN routing on link-up.
#
# When a static WAN's link goes down the kernel removes the per-gateway route
# from its policy table (e.g. table 102) and marks the multipath nexthop as
# 'dead linkdown'. On link-up the kernel revives the multipath nexthop by
# itself, but the policy-table route is not re-installed by anything, so it
# stays empty. The WAN failover checker probes a gateway by marking packets
# with its fwmark so that they leave through that gateway's policy table; with
# the table empty the probe falls back to another WAN and fails, so the gateway
# is never re-enabled (deadlock). Regenerating the gateways here mirrors what
# dhcp-gateway.pl does for DHCP and restores connectivity.

use strict;
use warnings;

my ($iface) = @ARGV;

use EBox;
use EBox::Global;
use TryCatch;

EBox::init();

my $network = EBox::Global->modInstance('network');

EBox::debug("Called static-up.pl with iface '$iface'");

$iface or exit;

try {
    # Only handle static interfaces; DHCP/PPP have their own dispatcher paths
    # (dhcp-address.pl / dhcp-gateway.pl / ppp-set-iface.pl) that regenerate
    # the routing themselves.
    my $method = $network->ifaceMethod($iface);

    # Only regenerate if the interface has a gateway configured. This mirrors
    # dhcp-gateway.pl, which is only invoked when there is a router, and avoids
    # pointless regenerations for internal static interfaces (LAN) coming up.
    # Note: all gateways are inspected, not only the enabled ones, because the
    # interesting case is precisely a gateway disabled by the failover checker
    # whose policy table must be restored so it can be tested and re-enabled.
    my $hasGateway = 0;
    if (defined $method and $method eq 'static') {
        foreach my $gw (@{$network->model('GatewayTable')->allGateways()}) {
            if ($gw->{'interface'} eq $iface) {
                $hasGateway = 1;
                last;
            }
        }
    }

    if ($hasGateway) {
        # Regenerate the routing unless there are pending changes or a save is
        # in progress.
        $network->regenGatewaysOnEvent();
    }
} catch {
};

exit;
