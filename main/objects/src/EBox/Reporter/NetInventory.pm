# Copyright (C) 2014 Zentyal S.L.
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

use warnings;
use strict;

package EBox::Reporter::NetInventory;

use base 'EBox::Reporter::Base';

use EBox;
use EBox::Global;
use EBox::Objects::Inventory;
use EBox::NetWrappers;
use TryCatch::Lite;


# Class: EBox::Reporter::NetInventory
#
#     Perform the network inventory to send. In this case the
#     data is sent in raw format as required by this application to be
#     useful.
#

# Group: Public methods

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'objects';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'network_inventory';
}

# Method: enabled
#
#      The reporter is only enabled if the module is enabled as we
#      query to the daemon directly.
#
# Overrides:
#
#      <EBox::Reporter::Base::enabled>
#
sub enabled
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance(1);  # Get read-only section
    my $mod = $gl->modInstance('objects');
    return 0 unless (defined($mod));

    return ($mod->isEnabled());
}

# Group: Protected methods

# Read the information from p0f server directly using provided Socket
# and the wrapper is done at EBox::Objects::Inventory

sub _consolidate
{
    my ($self, $begin, $end) = @_;

    my $net = EBox::Global->getInstance(1)->modInstance('network');
    my $internalIfaces = $net->InternalIfaces();
    unless (@{$internalIfaces}) {
        EBox::warn('No internal networks to perform network inventory');
        return [];
    }

    # FIXME: This is a naive implementation. We use check new hosts
    # from a local cache which must expire in a day to send the info
    # to avoid wasting network usage

    my @retData;
    my $invQuerier = new EBox::Objects::Inventory();
    foreach my $iface (@{$internalIfaces}) {
        my $network = EBox::NetWrappers::to_network_with_mask($net->ifaceNetwork($iface), $net->ifaceNetmask($iface));
        try {
            foreach my $host (@{$invQuerier->queryNetwork($network)}) {
                push(@retData,
                     { mac        => $host->{mac},
                       ip         => $host->{address},
                       os_flavour => $host->{os_flavour},
                       os_name    => $host->{os_name} });
            }
        } catch (EBox::Exceptions::Base $e) {
            EBox::error($e); # Do not fail miserably if any problem with the network
        }
    }
    return \@retData;
}

1;
