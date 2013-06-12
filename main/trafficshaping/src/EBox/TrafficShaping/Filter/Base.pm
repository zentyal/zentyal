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

package EBox::TrafficShaping::Filter::Base;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;

# Constructor: new
#
#   Constructor for Base Filter class.
#
# Parameters:
#
#   - Following are *tc* arguments to do filtering:
#
#   flowId - A hash containing the following entries:
#       - rootHandle - handle from root qdisc
#       - classId    - class id
#   parent - parent where filter is attached to (it's a <EBox::TrafficShaping::QDisc>)
#   protocol - Only ip it's gonna be supported *(Optional)*
#   prio - Filter priority. If several filters are attached to the same qdisc, they're asked in priority sections.
#       Lower number, higher priority. *(Optional)*
#   identifier - the filter identifier *(Optional)* Default value: $flowId->{classId}
#
# Returns:
#
#   A recently created <EBox::TrafficShaping::Filter::Base> object
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument> - throw if parameter is not passed.
#   <EBox::Exceptions::InvalidType> - throw if parameter is not with the correct type.
#   <EBox::Exceptions::InvalidData> - throw if parameter protocol is not ip one.
#
sub new
{
    my $class = shift;
    my %args = @_;
    my $self = {};

    # Treat arguments
    throw EBox::Exceptions::MissingArgument('flowId') unless defined $args{flowId};
    throw EBox::Exceptions::MissingArgument('parent') unless defined $args{parent};
    throw EBox::Exceptions::MissingArgument('filter') unless defined $args{filter};

    # Check flowId has the correct keys
    if (not (defined $args{flowId}->{rootHandle} and defined $args{flowId}->{classId})) {
        throw EBox::Exceptions::InvalidType('flowId', 'a hash with rootHandle and classId as arguments');
    }

    # Check protocol
    if (defined $args{protocol} and not $args{protocol} eq 'ip' ) {
        throw EBox::Exceptions::InvalidData(data => 'protocol');
    }

    # Check parent
    if (not $args{parent}->isa('EBox::TrafficShaping::QDisc::Base')) {
        throw EBox::Exceptions::InvalidType('parent', 'EBox::TrafficShaping::QDisc::Base');
    }

    # We take the identifier as the flowId->classid as fallback.
    $self->{id} = $args{identifier};
    $self->{id} = $args{flowId}->{classId} unless $args{identifier};
    $self->{flowId} = $args{flowId};
    $self->{protocol} = $args{protocol};
    # If no protocol is given, use ip by default
    $self->{protocol} = "ip" unless defined($args{protocol});
    $self->{prio} = $args{prio};
    $self->{parent} = $args{parent};
    $self->{filter} = $args{filter};

    bless($self, $class);
    return $self;
}

# Method: equals
#
#   Check equality between an object and this
#
# Parameters:
#
#   object - the object to compare
#
# Returns:
#
#   true - if the object is the same
#   false - otherwise
#
# Exceptions:
#
#   <EBox::Exceptions::InvalidType> - if object is not the correct type
#
sub equals # (object)
{
    my ($self, $object) = @_;

    throw EBox::Exceptions::InvalidType(
        'object', 'EBox::TrafficShaping::Filter::Base') unless $object->isa('EBox::TrafficShaping::Filter::Base');

    return $object->getIdentifier() == $self->getIdentifier();
}

# Method: getIdentifier
#
#   Accessor to the filter identifier
#
# Returns:
#
#   Integer - the unique filter identifier
#
sub getIdentifier
{
    my ($self) = @_;

    return $self->{id};
}

# Method: attribute
#
#   Get an attribute from the filter
#
# Parameters:
#
#   name - String with the attribute's name
#
# Returns:
#
#   the attribute's value
#
sub attribute # (name)
{
    my ($self, $name) = @_;

    return undef unless defined $self->{$name};

    return $self->{$name};
}

# Method: setAttribute
#
#   Set an attribute from the filter
#
# Parameters:
#
#   name  - String with the attribute's name
#   value - String with the new attribute's value
#
sub setAttribute # (name, value)
{
    my ($self, $name, $value) = @_;

    return unless (defined $self->{$name} and defined $value);

    # Set the new value
    $self->{$name} = $value
}

# Method: dumpTcCommand
#
#       Dump tc command needed to run to make the filter ready in tc
#
#
# Returns:
#
#       String - the tc command (only the *arguments* indeed)
#
sub dumpTcCommand
{
    my ($self) = @_;

    my $iface = $self->{parent}->getInterface();
    my %parentId = %{$self->{parent}->getIdentifier()};

    my $tcCommand = "filter add dev $iface parent $parentId{major}:$parentId{minor} ";
    $tcCommand .= "prio " . $self->{prio} . " " if ( $self->{prio} );
    $tcCommand .= "protocol " . $self->{protocol} . " ";
    $tcCommand .= sprintf("handle 0x%X ",  $self->getIdentifier());
    $tcCommand .= $self->{filter} . " ";
    $tcCommand .= sprintf("flowid 0x%X:0x%X ", $self->{flowId}->{rootHandle}, $self->{flowId}->{classId});

    return $tcCommand;
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
    return [];
}

# Method: dumpProtocols
#
#       Dump l7 filter protocols and its iptables mark
#
# Returns:
#
#       hash ref - array containing l7 filter protocols as keys and marks as values
#
sub dumpProtocols
{
    return {};
}

1;
