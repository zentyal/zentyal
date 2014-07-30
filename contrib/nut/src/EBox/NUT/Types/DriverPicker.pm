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

use strict;
use warnings;

package EBox::NUT::Types::DriverPicker;

use base 'EBox::Types::Abstract';

use EBox::Validate qw(:all);
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use Data::Dumper;
use File::Slurp;
use Text::CSV_XS;

use constant DRIVER_LIST_FILE => '/usr/share/nut/driver.list';

my $driverTable = undef;

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    # Load and cache the driver table
    unless (defined ($driverTable)) {
        $driverTable = _loadDriverTable();
    }

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/nut/ajax/setter/driverPickerSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    $opts{'type'} = 'driverPicker' unless defined ($opts{'type'});
    my $self = $class->SUPER::new(%opts);

    bless ($self, $class);
    return $self;
}

# Method: printableValue
#
# Overrides:
#
#       <EBox::Types::Abstract::printableValue>
#
sub printableValue
{
    my ($self) = @_;

    return $self->{'manufacturer'} . ' ' . $self->{'upsmodel'};
}

# Method: value
#
# Overrides:
#
#       <EBox::Types::Abstract::value>
#
# Returns:
#
#   Hash ref containing the values (manufacturer, upsmodel, $driver)
#
sub value
{
    my ($self) = @_;

    my $manufacturer = $self->manufacturer();
    my $upsmodel     = $self->upsmodel();
    my $driver       = $self->driver();

    my $value = {};
    $value->{manufacturer} = $manufacturer;
    $value->{upsmodel}     = $upsmodel;
    $value->{driver}       = $driver;
    $value->{options}      = undef;

    # Get the model options
    my $modelList = $driverTable->{$manufacturer};
    foreach my $entry (@{$modelList}) {
        if ($entry->{model} eq $upsmodel) {
            $value->{options} = $entry->{driverOptions};
            last;
        }
    }

    return $value;
}

# Method: cmp
#
# Overrides:
#
#       <EBox::Types::Abstract::cmp>
#
# Returns:
#
#      -1 - if self is lower than compareType
#
#       0 - if both are equal
#
#       1 - if self is higher than compareType
#
#       undef - otherwise (not equal types)
#
sub cmp
{
    my ($self, $compareType) = @_;

    unless ( (ref $self) eq (ref $compareType) ) {
        return undef;
    }

    unless ( defined ($self->{'manufacturer'}) and
             defined ($self->{'upsmodel'}) and
             defined ($self->{'driver'})) {
        return undef;
    }

    if (($self->{'manufacturer'} eq $compareType->{'manufacturer'}) and
        ($self->{'upsmodel'}   eq $compareType->{'upsmodel'}) and
        ($self->{'driver'} eq $compareType->{'driver'})) {
        return 0;
    } else {
        return 1;
    }
}

# Method: compareToHash
#
# Overrides:
#
#   <EBox::Types::Abstract::compareToHash>
#
# Returns:
#
#   True (1) if equal, false (0) if not equal
#
sub compareToHash
{
    my ($self, $hash) = @_;

    my $oldManufacturer = $self->{'manufacturer'};
    my $oldModel        = $self->{'upsmodel'};
    my $oldDriver       = $self->{'driver'};

    my $manufacturer = $self->fieldName() . '_manufacturer';
    my $upsmodel     = $self->fieldName() . '_upsmodel';
    my $driver       = $self->fieldName() . '_driver';

    if (($oldManufacturer ne $hash->{$manufacturer}  ) or
        ($oldModel        ne $hash->{$upsmodel}) or
        ($oldDriver       ne $hash->{$driver})) {
        return 0;
    }

    return 1;
}

sub _attrs
{
    return [ 'manufacturer', 'upsmodel', 'driver' ];
}

sub manufacturer
{
    my ($self) = @_;

    unless ($self->{'manufacturer'}) {
        my @keys = keys %{$driverTable};
        return $keys[0];
    }

    return $self->{'manufacturer'};
}

sub upsmodel
{
    my ($self) = @_;

    unless ($self->{'upsmodel'}) {
        my $manufacturer = $self->manufacturer();
        return $driverTable->{$manufacturer}[0]->{model};
    }

    return $self->{'upsmodel'};
}

sub driver
{
    my ($self) = @_;

    unless ($self->{'driver'}) {
        my $manufacturer = $self->manufacturer();
        my $upsmodel = $self->upsmodel();
        return $driverTable->{$manufacturer}[0]->{driver}[0];
    }

    return $self->{'driver'};
}

sub driverTable
{
    my ($self) = @_;

    unless (defined ($driverTable)) {
        $driverTable = _loadDriverTable();
    }

    return $driverTable;
}

# Group: Protected methods

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $manufacturer = $self->fieldName() . '_manufacturer';
    my $upsmodel     = $self->fieldName() . '_upsmodel';
    my $driver       = $self->fieldName() . '_driver';

    my $manufacturerValue = $params->{$manufacturer};
    my $upsmodelValue        = $params->{$upsmodel};
    my $driverValue       = $params->{$driver};

    unless (defined ($driverTable)) {
        $driverTable = $self->_loadDriverTable();
    }

    my $manufacturerExists = 0;
    my $upsmodelExists = 0;
    my $driverExists = 0;

    if (exists $driverTable->{$manufacturerValue}) {
        $manufacturerExists = 1;
        foreach my $entry (@{$driverTable->{$manufacturerValue}}) {
            if ($entry->{model} eq $upsmodelValue) {
                $upsmodelExists = 1;
                foreach my $driver (@{$entry->{driver}}) {
                    if ($driver eq $driverValue) {
                        $driverExists = 1;
                    }
                }
            }
        }
    }
    unless ($manufacturerExists) {
        throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $manufacturerValue,
            'advice' => __('This manufacturer does not exist.'));
    }
    unless ($upsmodelExists) {
        throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $upsmodelValue,
            'advice' => __('This model does not exist.'));
    }
    unless ($driverExists) {
        throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $driverValue,
            'advice' => __('This driver does not exist.'));
    }

    return 1;
}

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
{
    return 1;
}

# Method: _setValue
#
#     Set the value defined as a string: manufacturer/model
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String manufacturer/model
#
sub _setValue
{
    my ($self, $value) = @_;

    # There are countries America/Indiana/Indianapolis
    my ($manufacturer, $upsmodel, $driver) = split(/\|\|\|/, $value);

    my $params = {
        $self->fieldName() . '_manufacturer' => $manufacturer,
        $self->fieldName() . '_upsmodel'     => $upsmodel,
        $self->fieldName() . '_driver'       => $driver
    };

    $self->setMemValue($params);
}

# private methods

sub _loadDriverTable
{
    my ($self) = @_;

    return $driverTable if (defined $driverTable);

    my $table = {};
    my $csv = Text::CSV_XS->new({sep_char => "\t"});

    my @lines = read_file(DRIVER_LIST_FILE);
    foreach my $line (@lines) {
        next if ($line =~ m/^\s*#.*/ or $line =~ m/^\s*$/);
        my $status = $csv->parse($line);
        next unless $status;
        my @fields = $csv->fields();

        my $manufacturer = $fields[0];
        my $deviceType   = $fields[1];
        my $supportLevel = $fields[2];
        my $upsmodel     = $fields[3];
        my $modelExtra   = $fields[4];
        my $driver       = $fields[5];

        unless ($upsmodel ne '') {
            $upsmodel = "(all)";
        }

        unless (exists $table->{$manufacturer}) {
            $table->{$manufacturer} = [];
        }
        my $entry = { deviceType => $deviceType,
                      supportLevel => $supportLevel,
                      model => $upsmodel,
                      modelExtra => $modelExtra,
                      driver => [],
                      driverOptions => [],
                      driverComments => '' };
        push (@{$table->{$manufacturer}}, $entry);

        # Parse the driver field
        my @driverComments = ($driver =~ m/(\(.*\))/g);
        $entry->{driverComments} = join (',', @driverComments);
        $driver =~ s/(\(.*\))//g;

        my @driverOptions = ($driver =~ m/(\w+=[^\s]+)/g);
        @{$entry->{driverOptions}} = @driverOptions;
        $driver =~ s/(\w+=[^\s]+)//g;

        my @driverList = ($driver =~ m/([^\s]+)\s+or\s+([^\s]+)/g);
        push (@driverList, $driver) unless scalar @driverList;

        map (s/\s+//, @driverList);
        my %hash = map { $_ => 1 } @driverList;
        @{$entry->{driver}} = keys %hash;
    }
    return $table;
}

1;
