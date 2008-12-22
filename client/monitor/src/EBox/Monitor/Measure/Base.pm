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

# Method: simpleName
#
#      Get the simple measure's name, that is, the one used in
#      configuration files
#
# Returns:
#
#      String - the simple measure's name
#
sub simpleName
{
    my ($self) = @_;

    return $self->{simpleName};

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
#        { id   => 'measure[.instance]',
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
    if ( defined($instance) and $instance ne '') {
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

    my @returnData = map { [] } 1 .. $self->{nLines};
    my @rrds = ();
    if (@{$self->{typeInstances}} > 0) {
        @rrds = map { $self->{simpleName} . '-' . $_ . '.rrd' }
          @{$self->{typeInstances}};
    } else {
        push(@rrds, $self->{simpleName} . '.rrd');
    }
    my $prefix = $self->{simpleName};
    if ( defined($instance) ) {
        $prefix .= "-$instance";
    }
    @rrds = map { "$prefix/$_" } @rrds;

    my $baseDir = EBox::Monitor::RRDBaseDirPath();
    my $rrdIdx = 0;
    foreach my $rrdFile (@rrds) {
        # FIXME: use RRDs when it is fixed in Hardy
        my $fullPath = $rrdFile;
        $fullPath = $baseDir . $fullPath;
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
    $id .= '.' . $instance if (defined($instance));
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

# Method: typeInstances
#
#      Get the type instances for that measure.
#
# Returns:
#
#      array ref - the type instances for this measure
#
sub typeInstances
{
    my ($self) = @_;
    return $self->{typeInstances};
}

# Method: printableTypeInstance
#
#      Get the printable type instance for this measure given the type
#      instance itself
#
#      If there are not type instances, an <Internal> exception is
#      raised.
#
# Parameters:
#
#      typeInstance - String the type instance to get printable name
#                    from  *(Optional)* Default value: the first
#                    defined type instance
#
# Returns:
#
#      String - the i18ned name for the type instance
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given type
#      instance is not defined in this measure
#
#      <EBox::Exceptions::Internal> - thrown if there is not type
#      instances for this measure
#
sub printableTypeInstance
{
    my ($self, $typeInstance) = @_;

    if ( @{$self->{typeInstances}} == 0) {
        throw EBox::Exceptions::Internal('There are not type instances for this measure');
    }

    unless(defined($typeInstance)) {
        $typeInstance = $self->{typeInstances}->[0];
    }
    if ( exists($self->{printableTypeInstances}->{$typeInstance})) {
        return $self->{printableTypeInstances}->{$typeInstance};
    } elsif ( scalar(grep { $_ eq $typeInstance } @{$self->{typeInstances}}) == 1) {
        return $typeInstance;
    } else {
        throw EBox::Exceptions::DataNotFound(data  => 'typeInstance',
                                             value => $typeInstance);
    }
}

# Method: dataSources
#
#      Get the data sources available for that measure.
#
# Returns:
#
#      array ref - the data sources for this measure
#
sub dataSources
{
    my ($self) = @_;
    return $self->{dataSources};
}

# Method: printableDataSource
#
#      Get the printable data source for this measure given the data
#      source itself
#
# Parameters:
#
#      dataSource - String the data source to get printable value
#                    from  *(Optional)* Default value: the first
#                    defined data source
#
# Returns:
#
#      String - the i18ned name for the data source
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given data
#      source is not defined in this measure
#
sub printableDataSource
{
    my ($self, $dataSource) = @_;

    unless(defined($dataSource)) {
        $dataSource = $self->{dataSources}->[0];
    }
    if ( exists($self->{printableDataSources}->{$dataSource})) {
        return $self->{printableDataSources}->{$dataSource};
    } elsif ( scalar(grep { $_ eq $dataSource } @{$self->{dataSources}}) == 1) {
        return $dataSource;
    } else {
        throw EBox::Exceptions::DataNotFound(data  => 'dataSource',
                                             value => $dataSource);
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
#         printableDataSources - hash ref the printable data sources
#         for every data source *(Optional)* Default value: the data
#         source value will be displayed if no data source is given
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
#         instance names indexed by measure instance name, they are *optional*,
#         if not present the measure name will be used.
#
#         typeInstances - array ref the collection of data type stored
#         by measure instance, that is, the suffix in the RRD's files,
#         if any. *(Optional)* Default value: empty array
#
#         printableTypeInstance - hash ref the printable type instance
#         name indexed by type instance. *(Optional)*
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

    $self->{typeInstances} = [];
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
                }
            } else {
                # Testing against the prefix
                my $rrdPath = "$baseDir$prefix/${prefix}-${typeInstance}.rrd";
                unless ( -f $rrdPath ) {
                    throw EBox::Exceptions::Internal("RRD file $rrdPath does not exist");
                }
            }
            push(@{$self->{typeInstances}}, $typeInstance);
        }
    } else {
        if (@{$self->{instances}}) {
            foreach my $instance (@{$self->{instances}}) {
                my $rrdPath = "${baseDir}${prefix}-$instance/${prefix}.rrd";
                unless (-f $rrdPath) {
                    throw EBox::Exceptions::Internal("RRD file $rrdPath does not exist");
                }
            }
        } else {
            unless ( -f "${baseDir}${prefix}/${prefix}.rrd" ) {
                throw EBox::Exceptions::Internal("RRD file ${baseDir}${prefix}/${prefix}.rrd does not exist");
            }
        }
    }

    # Check printable stuff
    foreach my $kind (qw(printableInstances printableTypeInstances printableDataSources)) {
        $self->{$kind} = {};
        # Remove printable from kind to establish value from printable one
        my $valueKey = $kind;
        $valueKey =~ s:^printable::g;
        $valueKey = lcfirst($valueKey);
        if (exists($description->{$kind})) {
            unless ( ref($description->{$kind}) eq 'HASH' ) {
                throw EBox::Exceptions::InvalidType($description->{$kind},
                                                    'hash ref');
            }
            foreach my $key (keys(%{$description->{$kind}})) {
                if ( scalar(grep { $_ eq $key } @{$self->{$valueKey}}) == 1) {
                    $self->{$kind}->{$key} = $description->{$kind}->{$key};
                } else {
                    throw EBox::Exceptions::Internal("Printable $key is not a $valueKey in this measure");
                }
            }
        }

    }

    # Calculate the lines per graph
    my $nTI = (0,0);
    if(@{$self->{typeInstances}}) {
        $nTI = scalar(@{$self->{typeInstances}});
    } else {
        $nTI = 1;
    }
    $self->{nLines} = $nTI * scalar(@{$self->{dataSources}});

    if ( scalar(@{$self->{printableLabels}}) != $self->{nLines}) {
        throw EBox::Exceptions::Internal(
            'The number of printableLabels must be equal to '
            . $self->{nLines}
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
