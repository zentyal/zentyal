#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
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

use strict;
use warnings;

use EBox;
use EBox::Global;
use Error qw(:try);

EBox::init();

my $network = EBox::Global->modInstance('network');

my ($iface, $ppp_iface, $ppp_addr) = @ARGV;

EBox::debug('Called ppp-set-iface.pl with the following values:');
EBox::debug("iface: $iface") if $iface;
EBox::debug("ppp_iface: $ppp_iface") if $ppp_iface;
EBox::debug("ppp_addr: $ppp_addr") if $ppp_addr;

try {
    $network->setRealPPPIface($iface, $ppp_iface, $ppp_addr);
    $network->regenGateways();
} otherwise {
    EBox::error("Call to setRealPPPIface for $iface failed");
} finally {
    exit;
};
