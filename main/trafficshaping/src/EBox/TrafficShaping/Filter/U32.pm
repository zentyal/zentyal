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

no warnings 'experimental::smartmatch';
use feature 'switch';
use Scalar::Util qw(looks_like_number);

my @MATCHTYPES = qw(u32 u16 u8 ip);

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
#   matchList - The list of u32 match rules.
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

    throw EBox::Exceptions::MissingArgument('matchList') unless defined $args{matchList};

    my @matchList = @{$args{matchList}};
    throw EBox::Exceptions::InvalidData('matchList') unless $#matchList > 0;

    for my $match (@matchList) {
        throw EBox::Exceptions::InvalidData('matchType') unless defined $match->{matchType};
        throw EBox::Exceptions::InvalidData('matchPattern') unless (
            defined $match->{matchPattern} and looks_like_number($match->{matchPattern}));
        throw EBox::Exceptions::InvalidData('matchMask') unless (
            defined $match->{matchMask} and looks_like_number($match->{matchMask}));
        if (not grep { $_ eq $match->{matchType} } @MATCHTYPES) {
            throw EBox::Exceptions::InvalidData(data => 'matchType');
        }
        if ($match->{matchType} ne 'ip') {
            throw EBox::Exceptions::InvalidData('matchOffset') unless defined $match->{matchOffset};
            throw EBox::Exceptions::InvalidData(data => 'matchOffset') unless looks_like_number($match->{matchOffset});
        }
    }

    $self->{matchList} = $args{matchList};

    bless($self, $class);
    return $self;
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

    my $tcCommand = $self->SUPER::dumpTcCommand();

    for my $match (@{$self->{matchList}}) {

        given ($match->{matchType}) {
            when ('u32') {
                $tcCommand .= sprintf("match u32 0x%08X 0x%08X ", $match->{matchPattern}, $match->{matchMask});
            }
            when ('u16') {
                $tcCommand .= sprintf("match u16 0x%04X 0x%04X ", $match->{matchPattern}, $match->{matchMask});
            }
            when ('u8') {
                $tcCommand .= sprintf("match u8 0x%02X 0x%02X ", $match->{matchPattern}, $match->{matchMask});
            }
            when ('ip') {
                $tcCommand .= sprintf("match ip protocol %d 0x%02X ", $match->{matchPattern}, $match->{matchMask});
            }
        }

        if ($match->{matchType} ne 'ip') {
            if ($match->{matchNextHdrOffset}) {
                $tcCommand .= "at nexthdr+" . $match->{matchOffset} . " ";
            } else {
                $tcCommand .= "at " . $match->{matchOffset} . " ";
            }
        }
    }
    return $tcCommand;
}

1;
