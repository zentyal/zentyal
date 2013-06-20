# Copyright (C) 2013 Zentyal S.L.
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

# Method: preInput
#
#   To set the inline IPS to scan the incoming traffic
#
# Overrides:
#
#   <EBox::FirewallHelper::preInput>
#
sub preInput
{
    my ($self) = @_;

    return $self->_ifaceRules();
}

# Method: preForward
#
#   To set the inline IPS to scan the forwarded traffic
#
# Overrides:
#
#   <EBox::FirewallHelper::preForward>
#
sub preForward
{
    my ($self) = @_;

    return $self->_ifaceRules();
}

# Method: restartOnTemporaryStop
#
# Overrides:
#
#   <EBox::FirewallHelper::restartOnTemporaryStop>
#
sub restartOnTemporaryStop
{
    return 1;
}

sub _ifaceRules
{
    my ($self) = @_;

    my @rules;

    my $ips = EBox::Global->modInstance('ips');

    unless ($ips->temporaryStopped()) {
        my $qNum = $ips->nfQueueNum();

        foreach my $iface (@{$ips->enabledIfaces()}) {
            push (@rules, "-i $iface -m mark ! --mark 0x10000/0x10000 -j NFQUEUE --queue-num $qNum");
        }
    }
    return \@rules;
}

1;
