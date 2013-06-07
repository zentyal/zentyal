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

use strict;
use warnings;

package EBox::TrafficShaping::Filter::U32;

use base 'EBox::TrafficShaping::Filter::Base';

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::MissingArgument;

use feature 'switch';
use Scalar::Util qw(looks_like_number);
use Perl6::Junction qw(any);

# Constructor: new
#
#   Constructor for U32 Filter class.
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
#   A recently created <EBox::TrafficShaping::Filter::U32> object
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
    my %args = (@_);
    $args{filter} = 'u32';

    my $self = $class->SUPER::new(%args);

    throw EBox::Exceptions::MissingArgument('matchType') unless defined $args{matchType};
    throw EBox::Exceptions::MissingArgument('matchPattern') unless defined $args{matchPattern};
    throw EBox::Exceptions::MissingArgument('matchMask') unless defined $args{matchMask};
    throw EBox::Exceptions::MissingArgument('matchOffset') unless defined $args{matchOffset};

    if ($args{matchType} ne any(@{$value})) {
        throw EBox::Exceptions::InvalidData(data => 'matchType');
    }
    if (not looks_like_number($args{matchPattern})) {
        throw EBox::Exceptions::InvalidData(data => 'matchPattern');
    }
    if (not looks_like_number($args{matchMask})) {
        throw EBox::Exceptions::InvalidData(data => 'matchMask');
    }
    if (not looks_like_number($args{matchOffset})) {
        throw EBox::Exceptions::InvalidData(data => 'matchOffset');
    }

    self->{matchType} = $args{matchType};
    self->{matchPattern} = $args{matchPattern};
    self->{matchMask} = $args{matchMask};
    self->{matchOffset} = $args{matchOffset};
    self->{matchNextHdrOffset} = $args{matchNextHdrOffset};

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
        'object', 'EBox::TrafficShaping::Filter::U32') unless $object->isa('EBox::TrafficShaping::Filter::U32');

    return $object->getIdentifier() == $self->getIdentifier();
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

    my $tcCommand = $self->SUPER::dumpTcCommand()

    given ($self->{matchType}) {
        when ('u32') {
            $tcCommand .= sprintf("match u32 0x%08X 0x%08X ", $self->{matchPattern}, $self->{matchMask});
        }
        when ('u16') {
            $tcCommand .= sprintf("match u16 0x%04X 0x%04X ", $self->{matchPattern}, $self->{matchMask});
        }
        when ('u8') {
            $tcCommand .= sprintf("match u8 0x%02X 0x%02X ", $self->{matchPattern}, $self->{matchMask});
        }
    }
    if ($self->{matchNextHdrOffset}) {
        $tcCommand .= "at nexthdr+" . $self->{matchOffsetfilter} . " ";
    } else {
        $tcCommand .= "at " . $self->{matchOffsetfilter} . " ";
    }

    return $tcCommand;
}

1;
