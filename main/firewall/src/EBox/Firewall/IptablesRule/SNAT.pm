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
use warnings;
use strict;

package EBox::Firewall::IptablesRule::SNAT;

use base 'EBox::Firewall::IptablesRule';

use EBox::Gettext;
use EBox::Global;
use EBox::Model::Manager;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::NetWrappers;

use Perl6::Junction qw( any );

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    $self->{readOnly} = $opts{readOnly};
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
    my $netModule = EBox::Global->getInstance($self->{readOnly})->modInstance('network');
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

    my $snat = $self->{snat};
    foreach my $src (@{$self->{'source'}}) {
        foreach my $dst (@{$self->{'destination'}}) {
            foreach my $service (@{$self->{'service'}}) {

                my $snatRule = "-t nat -A POSTROUTING $modulesConf " .
                               "-o $iface " .
                               " $src $dst $service " .
                               " -j SNAT --to-source $snat";
                push (@rules, $snatRule);
                # Add log rule if it's activated
                if ( $self->{'log'} ) {
                    my $logRule = "-A fredirects $state $modulesConf " .
                        "-o $iface --src $snat $service $dst -j LOG -m limit ".
                        "--limit $limit/min ".
                        "--limit-burst $burst " .
                        '--log-level ' . $self->{'log_level'} . ' ' .
                        '--log-prefix "zentyal-firewall snat "';

                    unshift (@rules, $logRule);
                }
            }
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
    } elsif ($protocol eq any ('gre', 'icmp', 'esp', 'ah', 'all')) {
        my $iptables = " -p $protocol";
        push (@{$self->{'service'}}, [$iptables, $iptables]);
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
