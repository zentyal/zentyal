# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::DNS::FirewallHelper;

use base 'EBox::FirewallHelper';

use EBox::Global;

use constant DNS_PORT => 53;

sub new
{
    my $class = shift;
    my %params = @_;
    my $net = $params{network};
    my $dns = $params{dns};
    my $self = $class->SUPER::new(%params);
    $self->{net} = $net;
    $self->{dns} = $dns;
    bless($self, $class);
    return $self;
}

# Method: prerouting
#
#   To set transparent DNS cache if it is enabled
#
# Overrides:
#
#   <EBox::FirewallHelper::prerouting>
#
sub prerouting
{
    my ($self) = @_;

    my $dns    = $self->{dns};
    my @rules  = ();
    unless ($dns->temporaryStopped()) {
        if ( $dns->model('Settings')->row()->valueByName('transparent') ) {
            # The transparent cache DNS setting is enabled
            my $net = $self->{'net'};
            foreach my $iface (@{$net->InternalIfaces()}) {
                my $addrs = $net->ifaceAddresses($iface);
                my $input = $self->_inputIface($iface);
                foreach my $addr ( map { $_->{address} } @{$addrs} ) {
                    next unless ( defined($addr) and ($addr ne ""));
                    my $rule = "$input ! -d $addr -p tcp --dport " . DNS_PORT
                               . ' -j REDIRECT --to-ports ' . DNS_PORT;
                    push(@rules, $rule);
                    $rule = "$input ! -d $addr -p udp --dport " . DNS_PORT
                            . ' -j REDIRECT --to-ports ' . DNS_PORT;
                    push(@rules, $rule);
                }
            }
        }
    }
    return \@rules;
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

sub output
{
    my ($self) = @_;
    my @rules;

    push (@rules, '--protocol udp --dport ' . DNS_PORT . ' -j oaccept');
    push (@rules, '--protocol tcp --dport ' . DNS_PORT . ' -j oaccept');

    return \@rules;
}

1;
