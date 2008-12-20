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

# Method: name
#
#      Get the measure's name
#
# Returns:
#
#      String - the measure's name
#
sub name
{
    my ($self) = @_;

    return $self->{name};
}

# Method: printableName
#
#      Get the measure's printable name
#
# Returns:
#
#      String - the measure's printable name
#
sub printableName
{
    my ($self) = @_;

    return $self->{printableName};
}


# Method: fetchData
#
#      Get data for a certain time period from a measure
#
# Named parameters:
#
#      instance - String the instance to get data from *(Optional)*
#      Default value: the first instance defined in <_description> or
#      the unique instance that exists
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
#        { id   => 'measure.instance',
#          title => 'printableInstance',
#          help => 'help text',
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
#      <EBox::Exceptions::InvalidData> - thrown if the instance is not
#      one of the defined ones in the <_description> method or the
#      measure does not have instances
#
#      <EBox::Exceptions::Command> - thrown if the rrdtool fetch
#      utility failed to work nicely
#
sub fetchData
{
    my ($self, %params) = @_;

    my ($instance, $start, $end) = ($params{instance}, $params{start}, $params{end});
    if ( defined($instance) ) {
        unless ( scalar(grep { $_ eq $instance } @{$self->{instances}}) == 1 ) {
            throw EBox::Exceptions::InvalidData(data   => 'instance',
                                                value  => $instance,
                                                advice => 'The instance value must be one of the following: '
                                                  . join(', ', @{$self->{instances}}));
        }
    } else {
        $instance = $self->{instances}->[0];
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

    my @returnData = map { [] } 1 .. (scalar(@{$self->{rrds}}) * scalar(@{$self->{dataSources}}) );
    my $rrdIdx = 0;
    foreach my $rrdFile (@{$self->{rrds}}) {
        # FIXME: use RRDs when it is fixed in Hardy
        my $fullPath = $rrdFile;
        my $cmd = "rrdtool fetch $fullPath AVERAGE $start $end";
        my $output = EBox::Sudo::command($cmd);
        # Treat output
        my $previousTime = 0;
        my $interval = EBox::Monitor->QueryInterval();
        foreach my $line (@{$output}) {
            my ($time, $remainder) = $line =~ m/([0-9]+):\s(.*)$/g;
            if ( defined($time) ) {
                my @values = split(/\s/, $remainder, scalar(@{$self->{dataSources}}));
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
    my $id = $self->{name};
    $id .= '.' . $instance if ($instance);
    return {
        id     => $id,
        title  => $self->printableInstance($instance),
        help   => $self->{help},
        type   => $self->{type},
        series => \@series,
       };

}

# Method: instances
#
#      Get the instances for that measure, ie the total graphs to be
#      displayed by this measure
#
# Returns:
#
#      array ref - the instances for this measure
#
sub instances
{
    my ($self) = @_;
    return $self->{instances};
}

# Method: printableInstance
#
#      Get the printable instance for this measure given the instance itself
#
# Parameters:
#
#      instance - String the instance to get printable name from
#              *(Optional)* Default value: the first defined instance
#              if any, if not the printable name and finally if not
#              the simple name
#
# Returns:
#
#      String - the i18ned name for the instance
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given instance is
#      not defined in this measure
#
sub printableInstance
{
    my ($self, $instance) = @_;

    unless(defined($instance)) {
        $instance = $self->{instances}->[0];
        unless(defined($instance)) {
            if ( $self->{printableName}) {
                return $self->{printableName};
            } else {
                return $self->{simpleName};
            }
        }
    }
    if ( exists($self->{printableInstances}->{$instance})) {
        return $self->{printableInstances}->{$instance};
    } elsif ( scalar(grep { $_ eq $instance } @{$self->{instances}}) == 1) {
        return $instance;
    } else {
        throw EBox::Exceptions::DataNotFound(data  => 'instance',
                                             value => $instance);
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
#         dataSources - array ref the data name for each CDP (consolidated
#         data point) *(Optional)* Default value: [ 'value' ]
#
#         printableLabels - array ref the printable labels for every
#         type instance or data source to show *(Optional)* Default value:
#         i18ned 'value'
#
#         instances - array ref the instances of a measure,
#         that is, the suffix from the subdirectories where the RRD's
#         files are stored *(Optional)* Default value: empty
#         array. That is, the only applicable measure instance is the
#         static defined one.
#
#         printableInstances - hash ref the printable measure
#         instance names indexed by measure instance name, they are optional,
#         if not present the measure name will be used.
#
#         typeInstances - array ref the collection of data type stored
#         by measure instance, that is, the suffix in the RRD's files,
#         if any. *(Optional)* Default value: empty array
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
    ($self->{simpleName}) = $self->{name} =~ m/.*::(.*?)$/g;
    $self->{simpleName} = lc($self->{simpleName});
    my $prefix = $self->{simpleName};
    $self->{help} = exists($description->{help}) ? $description->{help} : '';
    $self->{printableName} =
      exists($description->{printableName}) ? $description->{printableName} : '';

    $self->{dataSources} = [ 'value' ];
    if ( exists($description->{dataSources}) ) {
        unless ( ref($description->{dataSources}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{dataSources}, 'array ref');
        }
        $self->{dataSources} = $description->{dataSources};
    }
    $self->{printableLabels} = [ __('value') ];
    if ( exists($description->{printableLabels}) ) {
        unless ( ref($description->{printableLabels}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{printableLabels}, 'array ref');
        }
        $self->{printableLabels} = $description->{printableLabels};
    }

    my $baseDir = EBox::Monitor->RRDBaseDirPath();
    $self->{instances} = [];
    if ( exists($description->{instances}) ) {
        unless ( ref($description->{instances}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{instances}, 'array ref');
        }
        foreach my $instance (@{$description->{instances}}) {
            if ( -d "${baseDir}${prefix}-$instance" ) {
                push(@{$self->{instances}}, $instance);
            } else {
                throw EBox::Exceptions::Internal("Subdirectory ${baseDir}${prefix}-$instance "
                                                   . 'does not exist');
            }
        }
    } else {
        unless ( -d "${baseDir}$prefix" ) {
            throw EBox::Exceptions::Internal(
                "Subdirectory ${baseDir}${prefix} does not exist");
        }
    }

    if ( exists($description->{printableInstances})) {
        unless ( ref($description->{printableInstances}) eq 'HASH' ) {
            throw EBox::Exceptions::InvalidType($description->{printableInstances},
                                                'hash ref');
        }
        $self->{printableInstances} = {};
        foreach my $key (keys(%{$description->{printableInstances}})) {
            if ( scalar(grep { $_ eq $key } @{$self->{instances}}) == 1) {
                $self->{printableInstances}->{$key} = $description->{printableInstances}->{$key};
            } else {
                throw EBox::Exceptions::Internal("Printable instance $key is not a instance in this measure");
            }
        }
    }

    $self->{typeInstances} = [];
    $self->{rrds} = [];
    if ( exists($description->{typeInstances}) ) {
        unless ( ref($description->{typeInstances}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{typeInstances}, 'array ref');
        }
        foreach my $typeInstance (@{$description->{typeInstances}}) {
            if (@{$self->{instances}}) {
                foreach my $instance (@{$self->{instances}}) {
                    my $instanceDir = "${baseDir}${prefix}-${instance}/";
                    my $rrdPath = "${instanceDir}${prefix}-${typeInstance}.rrd";
                    unless ( -f $rrdPath ) {
                        throw EBox::Exceptions::Internal("RRD file $rrdPath does not exist");
                    }
                    push(@{$self->{rrds}}, $rrdPath);
                }
            } else {
                # Testing against the prefix
                my $rrdPath = "$baseDir$prefix/${prefix}-${typeInstance}.rrd";
                if ( -f $rrdPath ) {
                    push(@{$self->{rrds}}, $rrdPath);
                } else {
                    throw EBox::Exceptions::Internal("RRD file $rrdPath does not exist");
                }
            }
            push(@{$self->{typeInstances}}, $typeInstance);
        }
    } else {
        if ( -f "${baseDir}${prefix}/${prefix}.rrd" ) {
            push(@{$self->{rrds}}, "${baseDir}${prefix}/${prefix}.rrd");
        } else {
            throw EBox::Exceptions::Internal("RRD file ${baseDir}${prefix}/${prefix}.rrd does not exist");
        }
    }

    if ( scalar(@{$self->{printableLabels}}) != (scalar(@{$self->{rrds}}) * scalar(@{$self->{dataSources}}))) {
        throw EBox::Exceptions::Internal(
            'The number of printableLabels must be equal to '
            . (scalar(@{$self->{rrds}}) * scalar(@{$self->{dataSources}}))
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
