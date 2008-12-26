# Copyright (C) 2008 eBox technologies S.L.
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

# Class: EBox::Firewall::IptablesRedirectRule
#
#   This class extends <EBox::Firewall::IptablesRule> to add
#   some stuff which is needed by redirects:
#
#   - Setting the interface name
#
#   - Setting a custom service (port and protocol)
#
#   - Setting destination (address and port)
#
package EBox::Firewall::IptablesRedirectRule;

use warnings;
use strict;

use EBox::Global;
use EBox::Model::ModelManager;
use EBox::Exceptions::MissingArgument;

use Perl6::Junction qw( any );

use base 'EBox::Firewall::IptablesRule';

sub new 
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_); 
    $self->{service} = [];
    bless($self, $class);
    return $self;

}

# Method: strings
#
#   Return the iptables rules built as a string
#   
# Returns:
#
#   Array ref of strings containing a iptables rule
sub strings
{
    my ($self) = @_;

    my @rules;
    my $state = $self->state();
    my $modulesConf = $self->modulesConf();
    my $iface = $self->interface();
    my $netModule = EBox::Global->modInstance('network');

    my $extaddr;
    my $method = $netModule->ifaceMethod($iface);
    if ($method eq 'dhcp') {
        $extaddr = $netModule->DHCPAddress($iface);
    } elsif ($method eq 'static'){
        $extaddr =  $netModule->ifaceAddress($iface);
    }

    unless (defined($extaddr) and length($extaddr) > 0) {
        return [];
    }


    foreach my $src (@{$self->{'source'}}) {
        my ($dst, $toDst) = @{$self->{'destination'}};
        foreach my $service (@{$self->{'service'}}) {
            my ($natSvc, $filterSvc) = @{$service};
            my $natRule = "-t nat -A PREROUTING $modulesConf " .
                "-i $iface $src $natSvc -d $extaddr -j DNAT $toDst";

            my $filterRule = "-A fredirects $state $modulesConf " .
                "-i $iface $src $filterSvc $dst -j ACCEPT";

            push (@rules, $natRule, $filterRule);
        }
    }

    return \@rules;
}

# Method: setInterface
#
#   Set interface for rules 
#   
# Parameters:
#   
#   (POSITIONAL)
#
#   interface - interface name
#   
sub setInterface
{
    my ($self, $interface) = @_;

    $self->{'interface'} = $interface;
}

# Method: interface
#
#   Return interface for rules 
#   
# Returns:
#   
#   interface - it can be any valid chain or interface like accept, drop, reject
#   
sub interface
{
    my ($self) = @_;

    if (exists $self->{'interface'}) {
        return $self->{'interface'};
    } else {
        return undef;
    }
}

# Method: setDestination
#
#   Set destination for rules 
#   
# Parameters:
#   
#   (POSITIONAL)
#
#   addr - destination address
#   port - destination port (optional: can be undef)
#   
sub setDestination
{
    my ($self, $addr, $port) = @_;

    my $destination = "-d $addr";
    my $toDestination = "--to-destination $addr";

    if (defined ($port)) {
        $toDestination .= ":$port";
    }
    $self->{'destination'} = [$destination, $toDestination];
}

# Method: setCustomService
#
#   Set a custom service for the rule
#
# Parameters:
#
#   (POSITIONAL)
#
#   extPort - external port
#   dstPort - destination port
#   protocol - protocol (tcp, udp, ...)
#   dstPortFilter - destination port to be used in filter table
sub setCustomService
{
    my ($self, $extPort, $dstPort, $protocol, $dstPortFilter) = @_;

    unless (defined($extPort)) {
        throw EBox::Exceptions::MissingArgument("extPort");
    }
    unless (defined($dstPort)) {
        throw EBox::Exceptions::MissingArgument("dstPort");
    }
    unless (defined($protocol)) {
        throw EBox::Exceptions::MissingArgument("protocol");
    }
    unless (defined($dstPortFilter)) {
        throw EBox::Exceptions::MissingArgument("$dstPortFilter");
    }

    my $nat = "";
    my $filter = "";
    if ($protocol eq any ('tcp', 'udp', 'tcp/udp')) {
        if ($extPort ne 'any') {
            $nat .= " --dport $extPort";
        }
        if ($dstPort ne 'any') {
            $filter .= " --dport $dstPortFilter";
        }

        if ($protocol eq 'tcp/udp') {
            push (@{$self->{'service'}}, ["-p udp $nat", "-p udp $filter"]);
            push (@{$self->{'service'}}, ["-p tcp $nat", "-p tcp $filter"]);
        } else {
            push (@{$self->{'service'}}, [" -p $protocol $nat", 
                                          " -p $protocol $filter"]); 
        }
    } elsif ($protocol eq any ('gre', 'icmp', 'esp')) {
        my $iptables = " -p $protocol";
        push (@{$self->{'service'}}, [$iptables, $iptables]);
    }
}


1;
