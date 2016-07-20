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

# Class: EBox::Firewall::IptablesRule
#
#	This is a conveninece class to manage iptables rules.
#	It is meant to be used to easily build iptables rules
#	based on data stored in data models.
#
#	Use the setters to configure the rule and eventually call
#	strings() to get the iptables rules stringfied.
#
package EBox::Firewall::IptablesRule;

use warnings;
use strict;

use Clone;

use EBox::Validate qw( checkCIDR );
use EBox::Model::Manager;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use Perl6::Junction qw( any );

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = {};
    $self->{'table'} = delete $opts{'table'};
    $self->{'chain'} = delete $opts{'chain'};
    $self->{'source'} = [''];
    $self->{'destination'} = [''];
    $self->{'objects'} = EBox::Global->modInstance('network');
    $self->{'services'} = EBox::Global->modInstance('network');
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
    my $table = ' -t ' . $self->table();
    my $decision = '';
    if ($self->decision()) {
        $decision = ' -j ' . $self->decision();
    }
    my $chain = ' -A ' .  $self->chain();
    my $state = $self->state();
    my $modulesConf = $self->modulesConf();

    foreach my $src (@{$self->{'source'}}) {
        foreach my $dst (@{$self->{'destination'}}) {
            foreach my $service (@{$self->{'service'}}) {
                my $rule = "$table $chain $modulesConf " .
                    "$src $dst $service $state $decision";
                push (@rules, $rule);
            }
        }
    }

    return \@rules;
}

# Method: setService
#
#   Set service for the rule
#
# Parameters:
#
#   (POSITIONAL)
#
#   service - a service id from <EBox::Service::Model::ServiceTable>
#   inverseMatch - inverse match
sub setService
{
    my ($self, $service, $inverseMatch) = @_;

    unless (defined($service)) {
        throw EBox::Exceptions::MissingArgument("service");
    }

    my $serviceConf = $self->{'services'}->serviceConfiguration($service);
    unless (defined($serviceConf)) {
        throw EBox::Exceptions::DataNotFound('data' => 'service',
                'value' => $service);
    }

    my $inverse = '';
    if ($inverseMatch) {
        $inverse = ' ! ';
    }

    my $iptables;
    foreach my $ser (@{$serviceConf}) {
        $iptables = "";
        my $srcPort = $ser->{'source'};
        my $dstPort = $ser->{'destination'};
        my $protocol = $ser->{'protocol'};
        my $invProto = '';
        if ($inverseMatch and $srcPort eq 'any' and  $dstPort eq 'any') {
            $invProto = ' ! ';
        }

        if ($protocol eq any ('tcp', 'udp', 'tcp/udp')) {

            if ($srcPort ne 'any') {
                $iptables .= " $inverse --source-port  $srcPort ";
            }

            if ($dstPort ne 'any') {
                $iptables .= " $inverse --destination-port $dstPort ";
            }

            if ($protocol eq 'tcp/udp') {
                push (@{$self->{'service'}}, " $invProto -p udp " . $iptables);
                push (@{$self->{'service'}}, " $invProto -p tcp " . $iptables);
            } else {
                push (@{$self->{'service'}}, " $invProto -p $protocol "
                                             . $iptables);
            }

        } elsif ($protocol eq 'icmp') {
            my @icmp_types = qw(echo-request echo-reply destination-unreachable source-quench parameter-problem);
            foreach my $type (@icmp_types) {
                $iptables = "  $invProto -p $protocol --icmp-type $type ! -f";
                push (@{$self->{'service'}}, $iptables);
            }
        } elsif ($protocol eq any ('gre', 'esp')) {
            $iptables = " -p $invProto $protocol";
            push (@{$self->{'service'}}, $iptables);
        } elsif ($protocol eq 'any') {
            push (@{$self->{'service'}}, '');
        }
    }
}

# Method: setChain
#
#   Set chain for rules
#
# Parameters:
#
#   (POSITIONAL)
#
#   chain - it can be any valid chain or chain like accept, drop, reject
#
sub setChain
{
    my ($self, $chain) = @_;

    $self->{'chain'} = $chain;
}

# Method: chain
#
#   Return chain for rules
#
# Returns:
#
#   chain - it can be any valid chain or chain like accept, drop, reject
#
sub chain
{
    my ($self) = @_;

    if (exists $self->{'chain'}) {
        return $self->{'chain'};
    } else {
        return undef;
    }
}

# Method: setState
#
#   Set state for rules
#
# Parameters:
#
#   (NAMED)
#
#   Set those states  which you wish to use. Do not set them to remove them
#
#   new
#   established
#   related
sub setState
{
    my ($self, %params) = @_;

    for my $stateKey (qw(new established related)) {
        if (exists $params{$stateKey} and $params{$stateKey}) {
            $self->{"state_$stateKey"} = 1;
        } else {
            $self->{"state_$stateKey"} = 0;
        }
    }
}

# Method: state
#
#   Return state for rules
#
# Returns:
#
#   state - it can be any valid state or state like accept, drop, reject
#
sub state
{
    my ($self) = @_;

    my $states = undef;
    for my $stateKey (qw(new established related)) {
        next unless ($self->{"state_$stateKey"});
        $states .= ', ' if ($states);
        $states .= uc($stateKey);
    }
    return '' unless ($states);
    return '-m state --state ' . $states;
}

# Method: setDecision
#
#   Set decision for rules
#
# Parameters:
#
#   (POSITIONAL)
#
#   decision - it can be any valid chain or decision like accept, drop, reject
#
sub setDecision
{
    my ($self, $decision) = @_;

    $self->{'decision'} = $decision;
}

# Method: decision
#
#   Return decision for rules
#
# Returns:
#
#   decision - it can be any valid chain or decision like accept, drop, reject
#
sub decision
{
    my ($self) = @_;

    if (exists $self->{'decision'}) {
        return $self->{'decision'};
    } else {
        return undef;
    }
}

# Method: setTable
#
#   Set table to insert rules into
#
# Parameters:
#
#   (POSITIONAL)
#
#   table - it can be one of these: filter, nat, mangle
#
#
sub setTable
{
    my ($self, $table) = @_;

    unless (defined($table)
            and ($table eq any(qw(filter nat mangle)))) {
        throw EBox::Exceptions::InvalidData('data' => 'table');
    }

    $self->{'table'} = $table;
}

# Method: decision
#
#   Return decision for rules
#
# Returns:
#
#   decision - it can be any valid chain or decision like accept, drop, reject
#
sub table
{
    my ($self) = @_;

    if (exists $self->{'table'}) {
        return $self->{'table'};
    } else {
        return undef;
    }
}

# Method: setSourceAddress
#
#   Set the source address/es to build the rule
#
# Parameters:
#
#   (NAMED)
#
#   inverseMatch - whether or not to do inverse match
#   The source it can either:
#   sourceAdddress - <EBox::Types::IPAddr>
#   sourceRange - <EBox::Types::IPRange>
#   sourceObject - object's id
#
sub setSourceAddress
{
    my ($self, %params) = @_;

    $params{'addressType'} = 'source';
    $self->_setAddress(%params);
}

# Method: sourceAddress
#
#   Return source address
#
# Returns:
#
#   Array ref containing source adddresses
#
sub sourceAddress
{
    my ($self) = @_;

    if (exists $self->{'source'}) {
        return $self->{'source'};
    } else {
        return undef;
    }
}

# Method: setDestinationAddress
#
#   Set the destination address/es to build the rule
#
# Parameters:
#
#   (NAMED)
#
#   inverseMatch - whether or not to do inverse match
#   The destination it can either:
#   destinationAdddress - <EBox::Types::IPAddr>
#   destinationRange - <EBox::Types::IPRange>
#   destinationObject - object's id
#
#
sub setDestinationAddress
{
    my ($self, %params) = @_;

    $params{'addressType'} = 'destination';
    $self->_setAddress(%params);
}

# Method: destinationAddress
#
#   Return destination address
#
# Returns:
#
#   Array ref containing destination adddresses
#
sub destinationAddress
{
    my ($self) = @_;

    if (exists $self->{'destination'}) {
        return $self->{'destination'};
    } else {
        return undef;
    }
}

# Method: setMark
#
#    Mark the packet with the mark number given. It also sets the
#    decision to MARK and the table to mangle one since it is the only
#    one possible
#
# Parameters:
#
#    markNumber - Int the mark number
#
#    markMask   - Int the mark mask in a hexadecimal string
#
sub setMark
{

  my ($self, $markNumber, $markMask) = @_;

  $self->setTable('mangle');
  $self->setDecision("MARK --set-mark $markNumber");
  $self->addModule('mark', 'mark', "0/$markMask");

}

# Method: addModule
#
#     Add a configuration parameter to an iptables module. If the
#     configuration parameter exists, it is overridden.
#
# Parameters:
#
#     moduleName - String the iptables module's name
#     confParamName - String the configuration parameter's name
#
#     confParamValue - the configuration parameter's value
#     *(Optional)*
#
sub addModule
{
  my ($self, $moduleName, $confParamName, $confParamValue) = @_;

  $confParamValue = '' unless defined ( $confParamValue );

  $self->{modules}->{$moduleName}->{$confParamName} = $confParamValue;

}

# Method: removeModule
#
#      Remove a configuration parameter from an iptables module
#
# Parameters:
#
#      moduleName - String the iptables module's name
#      confParamName - String the configuration parameter's name
#
sub removeModule
{
  my ($self, $moduleName, $confParamName) = @_;

  delete $self->{modules}->{$moduleName}->{$confParamName};

}

# Method: module
#
#     Get the string to configure an iptables' module
#
# Parameters:
#
#     moduleName - String the iptables module's name
#
# Exceptions:
#
#     <EBox::Exceptions::DataNotFound> - thrown if the module has not
#     been added
#
sub module
{
  my ($self, $moduleName) = @_;

  unless ( defined ( $self->{modules}->{$moduleName} )) {
    throw EBox::Exceptions::DataNotFound( data => q{Iptables' module},
					  value => $moduleName);
  }

  my $str = "-m $moduleName ";
  foreach my $confParam ( keys ( %{$self->{modules}->{$moduleName}})) {
    $str .= "--$confParam ";
    $str .= $self->{modules}->{$moduleName}->{$confParam} . ' ';
  }

  return $str;

}

# Method: modulesConf
#
#     Get the string to configure every module required by the
#     iptables' rule
#
sub modulesConf
{
  my ($self) = @_;

  my $str = '';
  foreach my $module ( keys(%{$self->{modules}})) {
    $str .= $self->module($module);
  }

  return $str;

}

# Private helper funcions
#

sub _setAddress
{
    my ($self, %params) = @_;

    my $addressType = delete $params{'addressType'};

    my $addr = delete $params{$addressType . 'Address'};
    my $obj = delete $params{$addressType . 'Object'};
    my $range = delete $params{$addressType . 'Range'};
    my $objMembers;
    my $inverse = '';
    if ($params{'inverseMatch'}) {
        $inverse = ' ! ';
    };

    if (defined($addr) and defined($obj)) {
        throw EBox::Exceptions::External(
                "address and object are mutual exclusive");
    }

    if (defined($addr)) {
        # Checking correct address
        unless ( $addr->isa('EBox::Types::IPAddr') or
                 $addr->isa('EBox::Types::HostIP') or
                 $addr->isa('EBox::Types::MACAddr')) {
            throw EBox::Exceptions::InvalidData('data' => 'src',
                                                'value' => $addr);
        }
        if ( $addr->isa('EBox::Types::MACAddr') and
             $addressType ne 'source') {
            print(
               'MACAddr filtering can be only ' .
               'done in source not in destination'
                                            );
        }
    }

    if (defined($obj)) {
        if (not $self->{'objects'}->objectExists($obj)) {
            throw EBox::Exceptions::DataNotFound('data' => 'object',
                                                 'value' => $obj);
        }

        $objMembers = $self->{'objects'}->objectMembers($obj);
        unless (@{$objMembers}) {
            EBox::warn("No members on obj $obj: " .
                       $self->{'objects'}->objectDescription($obj) .
                       ' make no iptables rules being created');
        }
    }

    $self->{$addressType} = [] ;
    my $flag = ' --source ';
    my $rangeFlag = ' --src-range ';
    if ($addressType eq 'destination') {
        $flag = ' --destination ';
        $rangeFlag = ' --dst-range ';
    }

    if (defined($obj)) {
        foreach my $member (@{ $objMembers }) {
            if ($member->{type} eq 'ipaddr') {
                push (@{$self->{$addressType}}, $inverse . $flag .  $member->{ipaddr});
            } elsif ($member->{type} eq 'iprange') {
                my $range = $member->{begin} . '-' . $member->{end};
                push (@{$self->{$addressType}}, ' -m iprange ' . $inverse . $rangeFlag .  $range);
            }

        }
    } elsif (defined $range) {
        my $range = $range->begin() . '-' . $range->end();
        $self->{$addressType} = [' -m iprange ' . $inverse . $rangeFlag .  $range];
    } else {
        if (defined ($addr) and $addr->isa('EBox::Types::IPAddr')
            and defined($addr->ip())) {
            $self->{$addressType} = ["$inverse $flag "
                                     . $addr->printableValue()];
        } elsif (defined ($addr) and $addr->isa('EBox::Types::MACAddr')) {
            $self->{$addressType} = ["-m mac --mac-source $inverse " .
                $addr->printableValue()] ;
        } elsif (defined ($addr) and $addr->isa('EBox::Types::HostIP')) {
            $self->{$addressType} = [$addr->printableValue()];
        } else {
            $self->{$addressType} = [''];
        }
    }
}

# Method: clone
#
#   Clone this rule
#
# Returns:
#
#     <EBox::Types::Abstract> - the cloned object
#
sub clone
{
    my ($self) = @_;

    my $clonedRule = {};
    bless($clonedRule, ref($self));

    my @skipKeys = qw/services objects/;
    foreach my $key (keys %{$self}) {
        unless ($key eq any @skipKeys) {
            $clonedRule->{$key} = Clone::clone($self->{$key});
        }
    }
    for my $key (@skipKeys) {
        $clonedRule->{$key} = $self->{$key};
    }

    return $clonedRule;
}

1;
