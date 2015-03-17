# Copyright (C) 2013-2014 Zentyal S.L.
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

package EBox::L2TP::FirewallHelper;

use base 'EBox::FirewallHelper';

use EBox::NetWrappers;

sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);

    $self->{enabled} = delete $opts{service};
    $self->{networksNoToMasquerade} = delete $opts{networksNoToMasquerade};
    $self->{L2TPInterfaces} = delete $opts{L2TPInterfaces};

    bless($self, $class);

    return $self;
}

# Method: inputNoSpoof
#
#   Rules returned by this method are added to the inospoofmodules chain in the filter table. We allow here to input
#   packages for L2TP/IPSec VPN clients that belong to a Zentyal local network as a valid 'spoofed' traffic.
#
# Returns:
#
#   array ref - containing input no spoof rules
#
sub inputNoSpoof
{
    my ($self) = @_;

    my @rules = ();
    foreach my $interface (@{$self->{L2TPInterfaces}}) {
        my $clientAddress = EBox::NetWrappers::iface_destination_address($interface);
        if ($clientAddress) {
            push (@rules, "-s $clientAddress/32 -i $interface -j iaccept");
        }
    }

    return \@rules;
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

    return $self->{enabled} ? [ '-m policy --dir in --pol ipsec -p udp --dport 1701 -j iaccept' ] : [];
}

# Method: forward
#
#   Allow traffic forwarding between ppp devices used by x2lpd's ppp daemon.
#
# Returns:
#
#   array ref - containing forward rules
#
sub forward
{
    my ($self) = @_;

    return $self->{enabled} ? [ '-i ppp+ -p all -m state --state NEW,ESTABLISHED,RELATED -j faccept' ] : [];
}

# Method: forwardNoSpoof
#
#   Rules returned by this method are added to the fnospoofmodules chain in the filter table. We allow here to forward
#   packages for L2TP/IPSec VPN clients that belong to a Zentyal local network as a valid 'spoofed' traffic.
#
# Returns:
#
#   array ref - containing forward no spoof rules
#
sub forwardNoSpoof
{
    my ($self) = @_;

    my @rules = ();
    my $socket = IO::Socket::INET->new(Proto => 'udp');
    foreach my $interface (@{$self->{L2TPInterfaces}}) {
        my $clientAddress = $socket->if_dstaddr($interface);
        if ($clientAddress) {
            push (@rules, "-s $clientAddress/32 -i $interface -j faccept");
        }
    }

    return \@rules;
}

sub networksNoToMasquerade
{
    my ($self) = @_;

    return $self->{networksNoToMasquerade};
}

sub postrouting
{
    my ($self) = @_;

    return [] unless $self->{enabled};

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
