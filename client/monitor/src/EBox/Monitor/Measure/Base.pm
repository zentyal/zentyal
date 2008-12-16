# Copyright 2008 (C) eBox Technologies S.L.
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

# Class: EBox::Monitor::Measure::Base
#
#     This is a base class to measure different values of stuff
#

package EBox::Monitor::Measure::Base;

use strict;
use warnings;

use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Monitor;
use EBox::Sudo;

# Constants
use constant TYPES => qw(int percentage byte grade);

# Constructor: new
#
sub new
{
    my ($class, @params) = @_;

    my $self = { @params };
    bless($self, $class);

    $self->_setDescription($self->_description());

    return $self;
}

# Method: fetchData
#
#      Get data for a certain time period from a measure
#
# Named parameters:
#
#      realm - String the realm to get data from *(Optional)* Default
#      value: the first realm defined in <_description>
#
#      start - Int Start of the time series. A time in seconds since
#      epoch (1970-01-01) is required. Negative numbers are relative
#      to the current time. *(Optional)* Default value: one day from
#      current time
#
#      end - Int the end of the time series in seconds since
#      epoch. *(Optional)* Default value: now
#
# Returns:
#
#      hash ref - containing the data defined in this
#      example
#
#        { id   => 'measure.realm',
#          title => 'printableRealm'
#          type => 'int',
#          series => [
#              { data  => [[x1, y1], [x2, y2], ... , [xn, yn ]],
#                label => 'label_for_data_1' },
#              { data  => [[x1, z1], [x2, z2], ... , [xn, zn ]],
#                label => 'label_for_data_2' },
#              ...
#          ]
#        }
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the realm is not
#      one of the defined ones in the <_description> method
#
#      <EBox::Exceptions::Command> - thrown if the rrdtool fetch
#      utility failed to work nicely
#
sub fetchData
{
    my ($self, %params) = @_;

    my ($realm, $start, $end) = ($params{realm}, $params{start}, $params{end});
    if ( defined($realm) ) {
        unless ( scalar(grep { $_ eq $realm } @{$self->{realms}}) == 1 ) {
            throw EBox::Exceptions::InvalidData(data   => 'realm',
                                                value  => $realm,
                                                advice => 'The realm value must be one of the following: '
                                                  . join(', ', @{$self->{realms}}));
        }
    } else {
        $realm = $self->{realms}->[0];
    }
    if ( defined($start) ) {
        $start = "-s $start";
    } else {
        $start = '';
    }
    if ( defined($end) ) {
        $end = "-e $end";
    } else {
        $end = '';
    }

    my @returnData = map { [] } 1 .. (scalar(@{$self->{rrds}}) * scalar(@{$self->{datasets}}) );
    my $rrdIdx = 0;
    foreach my $rrdFile (@{$self->{rrds}}) {
        # FIXME: use RRDs when it is fixed in Hardy
        my $fullPath = EBox::Monitor->RRDBaseDirPath() . $realm . '/' . $rrdFile;
        my $cmd = "rrdtool fetch $fullPath AVERAGE $start $end";
        my $output = EBox::Sudo::command($cmd);
        # Treat output
        my $previousTime = 0;
        my $interval = EBox::Monitor->QueryInterval();
        foreach my $line (@{$output}) {
            my ($time, $remainder) = $line =~ m/([0-9]+):\s(.*)$/g;
            if ( defined($time) ) {
                my @values = split(/\s/, $remainder, scalar(@{$self->{datasets}}));
                # Check no gaps between values
                if ( ($previousTime != 0) and ($time - $previousTime != $interval)) {
                    # Fill gaps with NaN numbers
                    my $gapTime = $previousTime;
                    while ($gapTime != $time) {
                        $gapTime += $interval;
                        for (my $valIdx = 0; $valIdx < scalar(@values); $valIdx++) {
                            push( @{$returnData[$valIdx + $rrdIdx]},
                                  [ $gapTime, "NaN" ]);
                        }
                    }
                } else {
                    for (my $valIdx = 0; $valIdx < scalar(@values); $valIdx++) {
                        push( @{$returnData[$valIdx + $rrdIdx]},
                              [ $time, $values[$valIdx] + 0]);
                    }
                }
            }
        }
        $rrdIdx++;
    }
    # Truncating for testing purposes
    foreach my $data (@returnData) {
        @{$data} = @{$data}[-361 .. -1];
    }
    my @series =
	map { { label => $self->{printableLabels}->[$_], data => $returnData[$_] }} 0 .. $#returnData;
    return {
        id     => $self->{name} . '.' . $realm,
        title  => $self->printableRealm($realm),
        type   => $self->{type},
        series => \@series,
       };

}

# Method: realms
#
#      Get the realms for that measure, ie the total graphs to be
#      displayed by this measure
#
# Returns:
#
#      array ref - the realms for this measure
#
sub realms
{
    my ($self) = @_;
    return $self->{realms};
}

# Method: printableRealm
#
#      Get the printable realm for this measure given the realm itself
#
# Parameters:
#
#      realm - String the realm to get printable name from
#              *(Optional)* Default value: the first defined realm
#
# Returns:
#
#      String - the i18ned name for the realm
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given realm is
#      not defined in this measure
#
sub printableRealm
{
    my ($self, $realm) = @_;

    unless(defined($realm)) {
        $realm = $self->{realms}->[0];
    }
    if ( exists($self->{printableRealms}->{$realm})) {
        return $self->{printableRealms}->{$realm};
    } elsif ( scalar(grep { $_ eq $realm } @{$self->{realms}}) == 1) {
        return $realm;
    } else {
        throw EBox::Exceptions::DataNotFound(data  => 'realm',
                                             value => $realm);
    }
}

# Group: Class methods

# Method: Types
#
#      Get the types of measures available
#
# Return:
#
#      Array ref - the types
#
sub Types
{
    my @types = TYPES;
    return \@types;
}

# Group: Protected methods

# Method: _description
#
#      Give the description for the measure
#
# Returns:
#
#      hash ref - the measure description containing the following
#      elements:
#
#         name - String the measure's name *(Optional)* Default value:
#         class name
#
#         printableName - String the measure's localisated name
#         +(Optional)* Default value: empty string
#
#         help - String the localisated help which may give an
#         explanation about the measure and measurement
#         *(Optional)*
#
#         datasets - array ref the data name for each CDP (consolidated
#         data point) *(Optional)* Default value: [ 'value' ]
#
#         printableLabels - array ref the printable labels for every dataset
#                           to show *(Optional)* Defaule value: i18ned 'value'
#
#         realms - array ref the realms (subdirectories) where the
#         common name's RRD files are stored
#
#         printableRealms - hash ref the printable realm names indexed
#         by realm name, they are optional, if not present the realm
#         name will be used.
#
#         rrds - array ref the RRD files' basename where it is
#         stored this measure
#
#         type - String the measure's gauge type. Possible values:
#         int, grade, percentage and byte
#         *(Optional)* Default value: 'int'
#
#
sub _description
{
    return {};
}

# Group: Private methods

# Method: _setDescription
#
#      Check the measure description and stores the attributes in the
#      measure base instance
#
# Parameters:
#
#      description - hash ref the description to check and set
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidType> - thrown if any attribute has
#      not correct type
#
#      <EBox::Exceptions::InvalidData> - thrown if any attribute has
#      not correct data
#
sub _setDescription
{
    my ($self, $description) = @_;

    $self->{name} = ref( $self );
    $self->{help} = exists($description->{help}) ? $description->{help} : '';
    $self->{printableName} =
      exists($description->{printableName}) ? $description->{printableName} : '';

    $self->{datasets} = [ 'value' ];
    if ( exists($description->{datasets}) ) {
        unless ( ref($description->{datasets}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{datasets}, 'array ref');
        }
        $self->{datasets} = $description->{datasets};
    }
    $self->{printableLabels} = [ __('value') ];
    if ( exists($description->{printableLabels}) ) {
        unless ( ref($description->{printableLabels}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{printableLabels}, 'array ref');
        }
        $self->{printableLabels} = $description->{printableLabels};
    }

    my $baseDir = EBox::Monitor->RRDBaseDirPath();
    if ( exists($description->{realms}) ) {
        unless ( ref($description->{realms}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{realms}, 'array ref');
        }
        $self->{realms} = [];
        foreach my $realm (@{$description->{realms}}) {
            if ( -d "${baseDir}$realm" ) {
                push(@{$self->{realms}}, $realm);
            } else {
                throw EBox::Exceptions::Internal("Subdirectory ${baseDir}$realm "
                                                 . 'does not exist');
            }
        }
    } else {
        throw EBox::Exceptions::MissingArgument('realms');
    }

    if ( exists($description->{printableRealms})) {
        unless ( ref($description->{printableRealms}) eq 'HASH' ) {
            throw EBox::Exceptions::InvalidType($description->{printableRealms},
                                                'hash ref');
        }
        $self->{printableRealms} = {};
        foreach my $key (keys(%{$description->{printableRealms}})) {
            if ( scalar(grep { $_ eq $key } @{$self->{realms}}) == 1) {
                $self->{printableRealms}->{$key} = $description->{printableRealms}->{$key};
            } else {
                throw EBox::Exceptions::Internal("Printable realm $key is not a realm in this measure");
            }
        }
    }

    if ( exists($description->{rrds}) ) {
        unless ( ref($description->{rrds}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{rrds}, 'array ref');
        }
        $self->{rrds} = [];
        foreach my $rrdPath (@{$description->{rrds}}) {
            foreach my $realm (@{$self->{realms}}) {
                my $realmDir = "${baseDir}${realm}/";
                unless ( -f "${realmDir}${rrdPath}" ) {
                    throw EBox::Exceptions::Internal("RRD file $realmDir$rrdPath does not exist");
                }
            }
            push(@{$self->{rrds}}, $rrdPath);
        }
    } else {
        throw EBox::Exceptions::MissingArgument('rrds');
    }

    if ( scalar(@{$self->{printableLabels}}) != (scalar(@{$self->{rrds}}) * scalar(@{$self->{datasets}}))) {
        throw EBox::Exceptions::Internal(
            'The number of printableLabels must be equal to '
            . (scalar(@{$self->{rrds}}) * scalar(@{$self->{datasets}}))
           );
    }

    $self->{type} = 'int';
    if ( exists($description->{type}) ) {
        if ( scalar(grep { $_ eq $description->{type} } @{$self->Types()}) == 1 ) {
            $self->{type} = $description->{type};
        } else {
            throw EBox::Exceptions::InvalidData(
                data => 'type',
                value => $description->{type},
                advice => 'Use one of this types: ' . join(', ', @{$self->Types()})
               );
        }
    }

}

1;
