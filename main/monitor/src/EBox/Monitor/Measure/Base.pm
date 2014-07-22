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
# Class: EBox::Monitor::Measure::Base
#
#     This is a base class to measure different values of stuff
#
package EBox::Monitor::Measure::Base;

no warnings 'experimental::smartmatch';
use feature ":5.10";

use EBox::Global;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::Monitor::Configuration;
use EBox::Sudo;
use RRDs;

# Constants
use constant TYPES => qw(int percentage byte degree millisecond bps);

# Constructor: new
#
sub new
{
    my ($class, @params) = @_;

    my $self = { @params };
    bless($self, $class);

    if ( $self->enabled() ) {
        $self->_setDescription($self->_description());
    }

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

# Method: plugin
#
#      Get the measure's plugin, that is, the one used by collectd to
#      get the measure data from
#
# Returns:
#
#      String - the measure's plugin name
#
sub plugin
{
    my ($self) = @_;

    return $self->{plugin};

}

sub baseDir
{
   # using readonly global to not fail with hostname changes not commited
    my $sysinfo = EBox::Global->getInstance(1)->modInstance('sysinfo');
    my $fqdn = $sysinfo->fqdn();
    return EBox::Monitor::Configuration::RRDBaseDirForFqdn($fqdn);
}

# Method: fetchData
#
#      Get data for a certain time period from a measure
#
#      Check man page for *rrdtool fetch* tool to get more information
#      about different ways to set the period
#
# Named parameters:
#
#      instance - String the instance to get data from *(Optional)*
#      Default value: the first instance defined in <_description> or
#      the unique instance that exists
#
#      typeInstance - String the type instance to get data from. This
#      can be set only if <graphPerTypeInstance> attribute is true
#      *(Optional)*
#
#      start - Int Start of the time series. A time in seconds since
#      epoch (1970-01-01) is required. Negative numbers are relative
#      to the current time. *(Optional)* Default value: one day from
#      current time
#
#      end - Int the end of the time series in seconds since
#      epoch. *(Optional)* Default value: now
#
#      resolution - Int the resolution in seconds *(Optional)+ Default
#      value: highest resolution (10 s)
#
# Returns:
#
#      hash ref - containing the data defined in this
#      example
#
#        { id   => 'measure[.instance][__typeInstance]',
#          title => 'printableInstance|printableTypeInstance',
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
#      <EBox::Exceptions::Internal> - thrown if the fetching does not
#      work nicely
#
sub fetchData
{
    my ($self, %params) = @_;

    my ($instance, $typeInstance, $start, $end, $resolution) =
      ($params{instance}, $params{typeInstance}, $params{start}, $params{end},
       $params{resolution});
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
    my $resStr;
    if ( defined($resolution) ) {
        $resStr = "-r $resolution";
    } else {
        $resolution = EBox::Monitor::Configuration::QueryInterval();
        $resStr = '';
    }
    if ( defined($start) ) {
        $start = "-s $start";
    } else {
        $start = '';
    }
    if ( defined($end) ) {
        $end = "-e $end";
    } elsif ( defined($resolution) ) {
        my $ctime = time();
        $end = "-e " . int($ctime/$resolution)*$resolution;
    } else {
        $end = '';
    }

    my @returnData = map { [] } 1 .. $self->{nLines};
    my @rrds = ();
    foreach my $type ( @{$self->{types}} ) {
        if ( $typeInstance ) {
            @rrds = ( "${type}-${typeInstance}.rrd" );
        } elsif (@{$self->{typeInstances}} > 0) {
            @rrds = map { $type . '-' . $_ . '.rrd' } @{$self->{typeInstances}};
        } else {
            push(@rrds, $type . '.rrd');
        }
    }
    my $prefix = $self->{plugin};
    if ( defined($instance) ) {
        $prefix .= "-$instance";
    }
    @rrds = map { "$prefix/$_" } @rrds;

    my $baseDir = $self->baseDir();
    my $rrdIdx = 0;
    foreach my $rrdFile (@rrds) {
        my $fullPath = $rrdFile;
        $fullPath = $baseDir . $fullPath;
        my ($time, $step, $names, $data) = RRDs::fetch($fullPath, 'AVERAGE', $start,
                                                       $end, $resStr);
        my $err = RRDs::error;
        if ( $err ) {
            throw EBox::Exceptions::Internal("Error fetching data from $fullPath: $err");
        }

        # Treat output
        my $previousTime = 0;
        foreach my $line (@{$data}) {
            for (my $valIdx = 0; $valIdx < scalar(@{$line}); $valIdx++) {
                $line->[$valIdx] = 0 unless defined($line->[$valIdx]);
                my $scaledValue = $self->scale($line->[$valIdx]);
                push( @{$returnData[$valIdx + $rrdIdx]},
                      [ $time, $scaledValue + 0]);
            }
            $time += $step;
        }
        $rrdIdx += scalar(@{$data->[0]}); # Put new RRDs files without overwritting
    }
    my @series =
	map { { label => $self->{printableLabels}->[$_], data => $returnData[$_] }} 0 .. $#returnData;
    my $id = $self->{name};
    $id .= '.' . $instance if (defined($instance));
    $id .= '__' . $typeInstance if (defined($typeInstance));
    my $title = $self->printableInstance($instance);
    $title = $self->printableTypeInstance($typeInstance) if (defined($typeInstance));
    return {
        id     => $id,
        title  => $title,
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
                return $self->{plugin};
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

# Method: metric
#
#      Return the metric used to collect the information for this issue
#
# Returns:
#
#      String - One of the available metrics
#
sub metric
{
    my ($self) = @_;

    return $self->{type};
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

# Method: graphPerTypeInstance
#
#      Get if we want a graph per type instance
#
# Returns:
#
#      Boolean
#
sub graphPerTypeInstance
{
    my ($self) = @_;

    return $self->{graphPerTypeInstance};
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

# Method: printableLabel
#
#      Get the printable label using type instance and data source
#
# Parameters:
#
#      typeInstance - String the type instance
#
#      dataSource - String the data source
#
# Returns:
#
#      String - the printable label associated to that typeInstance
#      and dataSource
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given type
#      instance or data source is not defined in this measure
#
sub printableLabel
{
    my ($self, $typeInstance, $dataSource) = @_;

    my ($idxTI, $idxDS, $found) = (0,0,0);

    if (defined($typeInstance)) {
        for(my $idx = 0; $idx < @{$self->{typeInstances}}; $idx++) {
            if ($self->{typeInstances}->[$idx] eq $typeInstance) {
                $idxTI = $idx;
                $found = 1;
                last;
            }
        }
        unless($found) {
            throw EBox::Exceptions::DataNotFound(data  => 'typeInstance',
                                                 value => $typeInstance);
        }
    }
    if (defined($dataSource)) {
        $found = 0;
        for(my $idx = 0; $idx < @{$self->{dataSources}}; $idx++) {
            if ($self->{dataSources}->[$idx] eq $dataSource) {
                $idxDS = $idx;
                $found = 1;
                last;
            }
        }
        unless($found) {
            throw EBox::Exceptions::DataNotFound(data  => 'dataSource',
                                                 value => $dataSource);
        }
    }
    my $nDS = scalar(@{$self->{dataSources}});

    return $self->{printableLabels}->[($idxTI * $nDS) + $idxDS];

}

# Method: enabled
#
#      A measure may be enabled, it is able to collect data from the
#      host
#
#      Default returned value is true.
#
# Returns:
#
#      true - if it is possible to collect data
#
#      false - otherwise
#
sub enabled
{
    return 1;
}

# Method: scale
#
#     Given a value for the measure, this method returns the scaled
#     version for the desired value.
#
#     For instance, the measure traffic is done in KB but we need
#     Bytes to depict the graph, then the scale will multiply current
#     value for 1024 to return bytes
#
# Parameters:
#
#     value - Float the current value
#
# Return:
#
#     Float - the scaled value
#
sub scale
{
    my ($self, $value) = @_;
    return $value;
}

# Method: formattedGaugeType
#
#    Return the measure for this gauge.
#
#    If the gauge type is 'int', then it returns nothing.
#
# Parameters:
#
#    count - Int the count number to Kilo/Mega if required
#
# Returns:
#
#    String - the measure in human readable format
#
sub formattedGaugeType
{
    my ($self, $count) = @_;

    given ( $self->{type} ) {
        when ( 'int' ) { return _formatInt($count); }
        when ( 'percentage' ) { return "$count%"; }
        when ( 'bps' ) { return (_formatSize($count) . '/s'); }
        when ( 'millisecond' ) { return _formatTimeDiff($count); }
        when ( 'degree' ) { return _formatInt($count) . '°'; }
        when ( 'byte' ) { return _formatSize($count) }
        default { return "$count " . $self->{type} . 's' }
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
#         plugin - String the measure's plugin name *(Optional)*
#         Default value: lc(name)
#
#         printableName - String the measure's localisated name
#         *(Optional)* Default value: empty string
#
#         help - String the localisated help which may give an
#         explanation about the measure and measurement
#         *(Optional)*
#
#         types - array ref the measure's types as defined by collectd
#         *(Optional)* Default value: [ $self->plugin() ]
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
#         int, degree, percentage and byte
#         *(Optional)* Default value: 'int'
#
#         graphPerTypeInstance - Boolean indicating if we want a graph
#         per type instance or not *(Optional)* Default value: false
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
    if ( exists( $description->{plugin} ) ) {
        $self->{plugin} = $description->{plugin};
    } else {
        # Guess plugin using the measure's name
        ($self->{plugin}) = $self->{name} =~ m/.*::(.*?)$/g;
        $self->{plugin} = lc($self->{plugin});
    }
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

    my $prefix = $self->plugin();
    $self->{instances} = [];
    if ( exists($description->{instances}) ) {
        unless ( ref($description->{instances}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{instances}, 'array ref');
        }
        foreach my $instance (@{$description->{instances}}) {
            push(@{$self->{instances}}, $instance);
        }
    }

    $self->{types} = [ $self->plugin() ];
    if ( exists($description->{types}) ) {
        unless( ref($description->{types}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{types}, 'array ref');
        }
        $self->{types} = \@{$description->{types}};
    }

    $self->{typeInstances} = [];
    if ( exists($description->{typeInstances}) ) {
        unless ( ref($description->{typeInstances}) eq 'ARRAY' ) {
            throw EBox::Exceptions::InvalidType($description->{typeInstances}, 'array ref');
        }
        foreach my $typeInstance (@{$description->{typeInstances}}) {
            push(@{$self->{typeInstances}}, $typeInstance);
        }
    }

    $self->{graphPerTypeInstance} = 0;
    if ($description->{graphPerTypeInstance}) {
        unless ( @{$self->{typeInstances}} > 0) {
            throw EBox::Exceptions::Internal('You cannot set graphPerTypeInstance to true if there is not type instances');
        }
        $self->{graphPerTypeInstance} = 1;
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
    my $nTI = 0;
    if(@{$self->{typeInstances}} > 0 and (not $self->{graphPerTypeInstance})) {
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

# These functions may be available in libebox package

# Gauge type formatters
sub _formatTimeDiff
{
    my ($ms) = @_;

    my ($pos, $base, $timeDiff) = (0, 1000, $ms);
    while ( $timeDiff > $base ) {
        $timeDiff = $timeDiff / $base;
        $pos++;
        if ( $pos >= 1 ) {
            $base = 60;
        }
        if ( $pos > 2 ) {
            last;
        }
    }
    my $num = 10 ** 2;

    my $numStr = sprintf( '%.2f', ($timeDiff * $num / $num));
    # Remove trailing zeroes if there are any
    $numStr =~ s:0+$::;
    $numStr =~ s:\.$::;

    return ( $numStr . ' ' . _timeDiffSuffix($pos) );
}

# Start using perl 5.10
sub _timeDiffSuffix
{
    my ($pos) = @_;

    given ( $pos ) {
        when ( 0 ) { return 'ms'; }
        when ( 1 ) { return 's'; }
        when ( 2 ) { return 'min'; }
        default { return 'h'; }
    }
}

# Format byte
sub _formatSize
{
    my ($size) = @_;

    my ($pos, $base) = (0, 1024);

    while ( ($size > $base) and ($pos < 10 ) ) {
        $size = $size / $base;
        $pos++;
    }
    my $num = 10 ** 2;

    my $numStr = sprintf( '%.2f', ($size * $num / $num));
    # Remove trailing zeroes if there are any
    $numStr =~ s:0+$::;
    $numStr =~ s:\.$::;
    return ( $numStr . ' ' . _sizeSuffix($pos) );

}

sub _sizeSuffix
{
    my ($pos) = @_;

    given ( $pos ) {
        when ( 0 ) { return 'B'; }
        when ( 1 ) { return 'KB'; }
        when ( 2 ) { return 'MB'; }
        when ( 3 ) { return 'GB'; }
        when ( 4 ) { return 'TB'; }
        when ( 5 ) { return 'PB'; }
        when ( 6 ) { return 'EB'; }
        when ( 7 ) { return 'ZB'; }
        when ( 8 ) { return 'YB'; }
        default    { return 'XB'; }
    }
}

sub _formatInt
{
    my ($count) = @_;

    my $countStr = sprintf( '%.2f', $count);
    # Remove trailing zeroes if there are any
    $countStr =~ s:0+$::;
    $countStr =~ s:\.$::;

    return $countStr;
}

1;
