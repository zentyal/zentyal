#!/usr/bin/perl

# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

my ($iface, $router) = @ARGV;

use File::Slurp;

write_file("/var/lib/zentyal/conf/${iface}_gw", $router);

use EBox;
use EBox::Global;
use EBox::Util::Lock;
use TryCatch;

EBox::init();

my $network = EBox::Global->modInstance('network');

EBox::debug("Called dhcp-gateway.pl with the following values: iface '$iface' router '$router'");

$iface or exit;
$router or exit;

try {
    $network->setDHCPGateway($iface, $router);

    # Do not call regenGateways if we are restarting changes, they
    # are already going to be regenerated and also this way we
    # avoid nested lock problems
    my $ifupLock = EBox::Util::Lock::_lockFile('ifup');
    unless (-f $ifupLock) {
        $network->regenGateways();
    }
} catch {
}

exit;
