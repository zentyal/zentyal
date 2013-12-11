# Copyright (C) 2008-2013 Zentyal S.L.
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

use EBox::Gettext;
use EBox::Global;
use EBox::Model::Manager;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::NetWrappers;

use Perl6::Junction qw( any );

use base 'EBox::Firewall::IptablesRule';

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    $self->{'log'} = 0;
    $self->{'log_level'} = 7;
    $self->{'snat'} = 0;
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
    $iface = $netModule->realIface($iface);

    # Iptables needs to use the real interface
    $iface =~ s/:.*$//;

    my $limit = EBox::Config::configkey('iptables_log_limit');
    my $burst = EBox::Config::configkey('iptables_log_burst');

    unless (defined($limit) and $limit =~ /^\d+$/) {
         throw EBox::Exceptions::External(__('You must set the ' .
             'iptables_log_limit variable in the ebox configuration file'));
    }

    unless (defined($burst) and $burst =~ /^\d+$/) {
         throw EBox::Exceptions::External(__('You must set the ' .
             'iptables_log_burst variable in the ebox configuration file'));
    }

    foreach my $src (@{$self->{'source'}}) {
        foreach my $origDst (@{$self->{'destination'}}) {
            my ($dst, $toDst) = @{$self->{'destinationNAT'}};

            foreach my $service (@{$self->{'service'}}) {
                my $natSvc = $service->{nat};
                my $postroutingSvc = $service->{postrouting};
                my $filterSvc = $service->{filter};

                my $natRule = "-t nat -A PREROUTING $modulesConf " .
                    "-i $iface $src $natSvc $origDst -j DNAT $toDst";
                my $filterRule = "-A fredirects $state $modulesConf " .
                    "-i $iface $src $filterSvc $dst -j faccept";

                push (@rules, $natRule);
                push (@rules, $filterRule);

                # Add SNAT rule if neccesary
                if ($self->{'snat'}) {
                    my $snatAddress = $self->snatAddress($netModule, $dst);
                    if ($snatAddress) {
                        my $snatRule = "-t nat -A POSTROUTING $modulesConf " .
                                " $src $dst $postroutingSvc " .
                                " -j SNAT --to-source $snatAddress";
                        push (@rules, $snatRule);
                    } else {
                        EBox::warn("Unable to find a SNAT address for redirection to $toDst. No SNAT rule will be added for this redirection.");
                    }
                }

                # Add log rule if it's activated
                if ( $self->{'log'} ) {
                    my $logRule = "-A fredirects $state $modulesConf " .
                        "-i $iface $src $filterSvc $dst -j LOG -m limit ".
                        "--limit $limit/min ".
                        "--limit-burst $burst " .
                        '--log-level ' . $self->{'log_level'} . ' ' .
                        '--log-prefix "zentyal-firewall redirect "';

                    unshift (@rules, $logRule);
                }
            }
        }
    }

    return \@rules;
}

sub snatAddress
{
    my ($self, $netModule, $destination) = @_;

    my @parts = split '\s+', $destination;
    my $dstIP = $parts[-1];

    my @internalIfaces = @{ $netModule->InternalIfaces() };
    foreach my $iface (@internalIfaces) {
        my @addresses = @{ $netModule->ifaceAddresses($iface) };
        foreach my $address (@addresses) {
            my $ip = $address->{address};
            my $netmask = $address->{netmask};
            my $localNetwork = EBox::NetWrappers::ip_network($ip, $netmask);
            if (EBox::Validate::isIPInNetwork($localNetwork,
                                              $netmask, $dstIP)) {
                return $ip;
            }
        }
    }

    return undef;
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
    $self->{'destinationNAT'} = [$destination, $toDestination];
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
    my $postrouting = '';
    if ($protocol eq any ('tcp', 'udp', 'tcp/udp')) {
        if ($extPort ne 'any') {
            $nat .= " --dport $extPort";
        }
        if ($dstPort ne 'any') {
            $filter .= " --dport $dstPortFilter";
        }
    }
    $postrouting = "$filter -m conntrack --ctstate DNAT";

    my @protocols;
    if ($protocol eq 'tcp/udp') {
        push @protocols, 'tcp', 'udp';
    } else {
        push @protocols, $protocol;
    }

    foreach my $pr (@protocols) {
        push @{$self->{'service'}},
            {
                nat => "-p $pr $nat",
                postrouting => "-p $pr $postrouting",
                filter => "-p $pr $filter",
            };
    }

}

# Method: setLog
#
#   Set log flag for rules
#
# Parameters:
#
#   (POSITIONAL)
#
#   log - 1 to activate logging
#
sub setLog
{
    my ($self, $log) = @_;

    $self->{'log'} = $log;
}

# Method: setLogLevel
#
#   Sets syslog level por log rule
#
# Parameters:
#
#   (POSITIONAL)
#
#   level - log level
#
sub setLogLevel
{
    my ($self, $level) = @_;

    $self->{'log_level'} = $level;
}

sub setSNAT
{
    my ($self, $snat) = @_;
    $self->{snat} = $snat;
}

1;
