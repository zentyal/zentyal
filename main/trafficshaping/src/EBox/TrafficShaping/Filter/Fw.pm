# Copyright (C) 2007 Warp Networks S.L.
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

use strict;
use warnings;

package EBox::TrafficShaping::Filter::Fw;

use base 'EBox::TrafficShaping::Filter::Base';

use EBox::Global;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::TrafficShaping::Firewall::IptablesRule;
use EBox::TrafficShaping;

use Perl6::Junction qw( any );

use constant MARK_MASK => '0xFF00';
use constant UNKNOWN_PROTO_MARK => '0x200';
use constant PENDING_PROTO_MARK => '0x100';

# Mark shift, last 8 bits
use constant MARK_SHIFT => 8;

# The highest found is 7
use constant LOWEST_PRIORITY => 200;

# Constructor: new
#
#   Constructor for Fw Filter class.
#
# Parameters:
#
#   - Following are *tc* arguments to do filtering:
#
#   flowId - A hash containing the following entries:
#       - rootHandle - handle from root qdisc
#       - classId    - class id
#   mark - Number used in packet to do filtering afterwards
#   parent - parent where filter is attached to (it's a <EBox::TrafficShaping::QDisc>)
#   protocol - Only ip it's gonna be supported *(Optional)*
#   prio - Filter priority. If several filters are attached to the same qdisc, they're asked in priority sections.
#       Lower number, higher priority. *(Optional)*
#   identifier - the filter identifier *(Optional)* Default value: $flowId->{classId}
#
#   - Following are *iptables* arguments to do filtering:
#
#   service   - undef or <EBox::Types::Union> from <EBox::TrafficShaping::Model::RuleTable> that can contains
#       a port based service, l7 protocol service or a group of l7 protocol services. If undef, any service is assumed.
#   srcAddr   - <EBox::Types::IPAddr> or <EBox::Types::MACAddr> the packet source to match *(Optional)*
#   dstAddr   - <EBox::Types::MACAddr> the packet destination to match *(Optional)*
#   matchPrio - int (0-7) the priority which will have at the iptables matching *(Optional)*
#       Default value: lowest priority = 7
#
#   If none is provided, the default redundant mark will be applied
#       - Named parameters
#
# Returns:
#
#      A recently created <EBox::TrafficShaping::Filter::Fw> object
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not passed
#      <EBox::Exceptions::InvalidType> - throw if parameter is not with the correct type
#      <EBox::Exceptions::InvalidData> - throw if parameter protocol is not ip one
#
sub new
{
    my $class = shift;
    my %args = @_;
    $args{filter} = 'fw';

    my $self = $class->SUPER::new(%args);

    # Treat arguments
    throw EBox::Exceptions::MissingArgument('mark') unless defined $args{mark};

    # Check addresses
    if ($args{srcAddr}) {
        if ((not $args{srcAddr}->isa('EBox::Types::IPAddr')) and
            (not $args{srcAddr}->isa('EBox::Types::MACAddr')) and
            (not $args{srcAddr}->isa('EBox::Types::IPRange'))) {
            throw EBox::Exceptions::InvalidType(
                'srcAddr', 'EBox::Types::IPAddr or EBox::Types::MACAddr or EBox::Types::IPRange');
        }
    }
    if ($args{dstAddr}) {
        if ((not $args{dstAddr}->isa('EBox::Types::IPAddr')) and
            (not $args{dstAddr}->isa('EBox::Types::IPRange'))) {
            throw EBox::Exceptions::InvalidType('srcAddr', 'EBox::Types::IPAddr or EBox::Types::IPRange');
        }
    }
    $self->{mark} = $args{mark};

    if (defined $args{service}) {
        $self->{service} = $args{service};
    }

    if ($args{srcAddr}) {
        $self->{srcAddr} = $args{srcAddr};
        if ($args{srcAddr}->isa('EBox::Types::IPAddr')) {
            $self->{srcIP} = $args{srcAddr}->ip();
            $self->{srcNetMask} = $args{srcAddr}->mask();
        } elsif ($args{srcAddr}->isa('EBox::Types::MACAddr')) {
            $self->{srcMAC} = $args{srcAddr}->value();
        } elsif ($args{srcAddr}->isa('EBox::Types::IPRange')) {
            $self->{srcRange} = $args{srcAddr};
        }
    }

    if ($args{dstAddr}) {
        $self->{dstAddr} = $args{dstAddr};
        if ($args{dstAddr}->isa('EBox::Types::IPAddr')) {
            $self->{dstIP} = $args{dstAddr}->ip();
            $self->{dstNetMask} = $args{dstAddr}->mask();
        } elsif ($args{dstAddr}->isa('EBox::Types::IPRange')) {
            $self->{dstRange} = $args{dstAddr};
        }
    }

    # Iptables priority
    $self->{matchPrio} = $args{matchPrio};
    $self->{matchPrio} = LOWEST_PRIORITY unless defined $self->{matchPrio};

    bless($self, $class);
    return $self;
}

# Method: dumpIptablesCommands
#
#       Dump iptables commands needed to run to make the filter ready
#       in iptables
#
#
# Returns:
#
#       array ref - array with all needed command arguments
#
sub dumpIptablesCommands
{
    my ($self) = @_;

    # Getting the mask number
    my $mask = hex ( MARK_MASK );

    # Applying the mask
    my $mark = $self->{mark} & $mask;
    $mark = sprintf("0x%X", $mark);
    #    my $protocol = $self->{fProtocol};

    # Set no port if protocol is all
    my $sport = undef;
    my $dport = undef;

    # unless ( defined ( $protocol ) and
    # ($protocol eq EBox::Types::Service->AnyProtocol )) {
    #      $sport = $self->{fPort};
    #      $dport = $self->{fPort};
    # }

    my $srcIP = $self->{srcIP};
    my $srcMAC = $self->{srcMAC};
    my $srcNetMask = $self->{srcNetMask};
    my $dstIP = $self->{dstIP};
    my $dstNetMask = $self->{dstNetMask};

    my $shaperChain;
    $shaperChain = 'EBOX-SHAPER-' . $self->{parent}->getInterface();
    my $l7shaperChain = 'EBOX-L7SHAPER-' . $self->{parent}->getInterface();

    my @ipTablesCommands;
    my $leadingStr;
    my $mediumStr;
    if ( defined ( $self->{service} ) or defined ( $srcIP ) or defined ( $dstIP )) {
        my $ipTablesRule = EBox::TrafficShaping::Firewall::IptablesRule->new( chain => $shaperChain );

        if (defined $self->{srcRange}) {
            $ipTablesRule->setSourceAddress(inverseMatch => 0,
                    sourceRange => $self->{srcRange});
        } elsif ( defined ( $self->{srcAddr} )) {
            $ipTablesRule->setSourceAddress(inverseMatch => 0,
                    sourceAddress => $self->{srcAddr});
        }

        if (defined ( $self->{dstRange} )) {
            $ipTablesRule->setDestinationAddress( inverseMatch => 0,
                    destinationRange => $self->{dstRange} );
        } elsif (defined ( $self->{dstAddr} )) {
            $ipTablesRule->setDestinationAddress( inverseMatch => 0,
                    destinationAddress => $self->{dstAddr} );
        }

        if (not defined ($self->{service})) {
            my $serviceMod = EBox::Global->modInstance('services');
            $ipTablesRule->setService($serviceMod->serviceId('any'));

        } else {
            my $iface = $self->{parent}->getInterface();
            my $network = EBox::Global->modInstance('network');
            if ($network->ifaceIsExternal($network->etherIface($iface))) {
                $ipTablesRule->setService($self->{service}->value());
            } else {
                $ipTablesRule->setReverseService($self->{service}->value());
            }
        }

        # Mark the packet and set the decision to MARK and the table as mangle
        $ipTablesRule->setMark($mark, MARK_MASK);
        push(@ipTablesCommands, @{$ipTablesRule->strings()});

    }
    # FIXME Comment out because it messes up with multipath marks
    #else {
    # Set redundant mark to send to default one

    # push(@ipTablesCommands,
    #   "-t mangle -A $shaperChain -m mark --mark 0/" . MARK_MASK . ' ' .
    #   "-j MARK --set-mark $mark"
    #  );
    #}

    return \@ipTablesCommands;

}

sub _extraL7Commands
{
    my ($self, $rule) = @_;

    my $network = EBox::Global->modInstance('network');
    my $iface = $self->{parent}->getInterface();
    my @ifaces;
    if ($network->ifaceIsExternal($network->etherIface($iface))) {
        @ifaces = @{$network->InternalIfaces()};
    } else {
        @ifaces = @{$network->ExternalIfaces()};
    }

    my @cmds;
    for my $interface (@ifaces) {
        my $newRule = $rule->clone();
        $rule->setChain("EBOX-SHAPER-$interface -i $iface");
        push (@cmds, @{$rule->strings()});
    }

    return @cmds;
}

1;
