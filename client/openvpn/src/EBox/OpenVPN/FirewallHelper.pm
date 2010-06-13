# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::OpenVPN::FirewallHelper;
use base 'EBox::FirewallHelper';

# Description:
use strict;
use warnings;

sub new
{
    my ($class, %opts) = @_;

    exists $opts{portsByProto}
      and throw EBox::Exceptions::Internal('deprecated argumnt');

    my $self = $class->SUPER::new(%opts);
    $self->{service}          =  delete $opts{service};
    $self->{ifaces}           =  delete $opts{ifaces};
    $self->{networksToMasquerade} = delete $opts{networksToMasquerade};
    $self->{ports}            =  delete $opts{ports};
    $self->{serversToConnect} =  delete $opts{serversToConnect};

    bless($self, $class);
    return $self;
}

sub isEnabled
{
    my ($self) = @_;
    return $self->{service};
}

sub ifaces
{
    my ($self) = @_;
    return $self->{ifaces};
}

sub networksToMasquerade
{
    my ($self) = @_;
    return $self->{networksToMasquerade};
}

sub ports
{
    my ($self) = @_;
    return $self->{ports};
}

sub serversToConnect
{
    my ($self) = @_;
    return $self->{serversToConnect};
}

sub externalInput
{
    my ($self) = @_;
    return $self->_inputRules(1);
}

sub input
{
    my ($self) = @_;
    return $self->_inputRules(0);
}

sub _inputRules
{
    my ($self, $external) = @_;

    $self->isEnabled() or return [];

    my @rules;

    # allow rip traffic in openvpn virtual ifaces
    foreach my $iface (@{ $self->ifaces() }) {
        push @rules, "-i $iface -p udp --destination-port 520 -j ACCEPT";
    }

    my @ports = grep {$_->{external} == $external} @{ $self->ports };

    foreach my $port_r (@ports) {
        my $port    =   $port_r->{port};
        my $proto  = $port_r->{proto};
        my $listen = $port_r->{listen};

        my $inputIface = defined $listen ? "-i $listen" : "";

        my $rule =
          "--protocol $proto --destination-port $port $inputIface -j ACCEPT";
        push @rules, $rule;
    }

    return \@rules;
}

sub output
{
    my ($self) = @_;
    my @rules;

    if ($self->isEnabled()) {

        # allow rip traffic in openvpn virtual ifaces
        foreach my $iface (@{ $self->ifaces() }) {
            push @rules, "-o $iface -p udp --destination-port 520 -j ACCEPT";
        }

        foreach my $server_r (@{ $self->serversToConnect() }) {
            my ($serverProto, $server, $serverPort) = @{$server_r};
            my $connectRule =
"--protocol $serverProto --destination $server --destination-port $serverPort -j ACCEPT";
            push @rules, $connectRule;
        }
    }

# we need HTTP access for client bundle generation (need to resolve external address)
    my $httpRule = "--protocol tcp  --destination-port 80 -j ACCEPT";
    push @rules, $httpRule;

    return \@rules;
}

sub postrouting
{
    my ($self) = @_;

    my $network = EBox::Global->modInstance('network');
    my @internalIfaces = @{ $network->InternalIfaces()  };

    my @networksToMasquerade = @{  $self->networksToMasquerade() };

    my @rules;
    foreach my $network (@networksToMasquerade) {
        foreach my $iface (@internalIfaces) {
            push @rules, "-o $iface --source $network -j MASQUERADE";
        }
    }

    return \@rules;
}

1;
