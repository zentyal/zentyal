# Copyright (C) 2013 eBox Technologies S.L.
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

package EBox::IPS::FirewallHelper;

use strict;
use warnings;

use base 'EBox::FirewallHelper';

sub preInput
{
    my ($self) = @_;

    my @rules;

    my $ips = EBox::Global->modInstance('ips');

    foreach my $iface (@{$ips->enabledIfaces()}) {
        push (@rules, "-i $iface -m mark ! --mark 0x10000/0x10000 -j NFQUEUE");
    }

    return \@rules;
}

1;
