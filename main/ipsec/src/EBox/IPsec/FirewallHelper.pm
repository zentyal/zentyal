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
package EBox::IPsec::FirewallHelper;
use base 'EBox::FirewallHelper';

use strict;
use warnings;

sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);

    $self->{service} = delete $opts{service};
    $self->{networksNoToMasquerade} = delete $opts{networksNoToMasquerade};
    $self->{hasL2TP} = delete $opts{hasL2TP};

    bless($self, $class);

    return $self;
}

# Method: externalInput
#
#   Restricts the xl2tp traffic only to packages using IPSec.
#
# Returns:
#
#   array ref - containing input rules
#
# Overrides:
#
#   <EBox::FirewallHelper::externalInput>
#
sub externalInput
{
    my ($self) = @_;

    ($self->_isEnabled() and $self->{hasL2TP}) or return [];

    return ["-m policy --dir in --pol ipsec -p udp --dport 1701 -j ACCEPT"];
}

# Method: forward
#
#   Allow traffic forwarding between ppp devices used by x2lp's ppp daemon.
#
# Returns:
#
#   array ref - containing forward rules
sub forward
{
    my ($self) = @_;

    ($self->_isEnabled() and $self->{hasL2TP}) or return [];

    return ["-i ppp+ -p all -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT"];
}

sub _isEnabled
{
    my ($self) = @_;

    return $self->{service};
}

sub networksNoToMasquerade
{
    my ($self) = @_;

    return $self->{networksNoToMasquerade};
}

sub postrouting
{
    my ($self) = @_;

    $self->_isEnabled() or return [];

    my $network = EBox::Global->modInstance('network');
    my @externalIfaces = @{$network->ExternalIfaces()};

    my @networksNoToMasquerade = @{$self->networksNoToMasquerade()};

    my @rules;
    foreach my $network (@networksNoToMasquerade) {
        foreach my $iface (@externalIfaces) {
            my $output = $self->_outputIface($iface);
            # don't NAT connections going thru IPsec VPN
            push @rules, "$output --destination $network -j ACCEPT";
        }
    }

    return \@rules;
}

1;
