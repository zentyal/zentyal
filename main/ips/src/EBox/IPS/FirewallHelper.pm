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

use strict;
use warnings;

package EBox::IPS::FirewallHelper;

use base 'EBox::FirewallHelper';

use EBox::Global;

sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);

    $self->{ips} = EBox::Global->modInstance('ips');

    bless($self, $class);
    return $self;
}

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

    my $rules = [];
    if ($self->_where() eq 'front') {
        $rules = $self->_ifaceRules();
    }
    return $rules;
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

    my $rules = [];
    if ($self->_where() eq 'front') {
        $rules = $self->_ifaceRules();
    }
    return $rules;
}

# Method: inputAccept
#
#   To set the inline IPS to scan the accepted input traffic
#
# Overrides:
#
#   <EBox::FirewallHelper::inputAccept>
#
sub inputAccept
{
    my ($self) = @_;

    my $rules = [];
    if ($self->_where() eq 'behind') {
        $rules = $self->_ifaceRules();
    }
    return $rules;
}

# Method: forwardAccept
#
#   To set the inline IPS to scan the accepted forwarded traffic.
#
# Overrides:
#
#   <EBox::FirewallHelper::forwardAccept>
#
sub forwardAccept
{
    my ($self) = @_;

    my $rules = [];
    if ($self->_where() eq 'behind') {
        $rules = $self->_ifaceRules();
    }
    return $rules;
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

# Private methods

sub _ifaceRules
{
    my ($self) = @_;

    my @rules;
    my $ips   = $self->{ips};
    my $place = $self->_where();

    unless ($ips->temporaryStopped()) {
        my $qNum = $ips->nfQueueNum();

        foreach my $iface (@{$ips->enabledIfaces()}) {
            my $rule = "-i $iface";
            if ($place eq 'front') {
                $rule .= " -m mark ! --mark 0x10000/0x10000";
            }
            $rule .= " -j NFQUEUE --queue-num $qNum";
            push (@rules, $rule);
        }
    }
    return \@rules;
}

sub _where
{
    my ($self) = @_;

    return $self->{ips}->fwPosition();
}

1;
