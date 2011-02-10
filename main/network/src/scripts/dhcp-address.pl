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

my $global = EBox::Global->getInstance(1);
my $network = $global->modInstance("network");

my ($iface, $address, $mask) = @ARGV;

EBox::debug('Called dhcp-address.pl with the following values:');

$iface or exit;
EBox::debug("iface: $iface");

$address or exit;
EBox::debug("address: $address");

$mask or exit;
EBox::debug("mask: $mask");

try {
    $network->setDHCPAddress($iface, $address, $mask);
} otherwise {
    EBox::error("Call to setDHCPAddress for $iface failed");
} finally {
    exit;
};
