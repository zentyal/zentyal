# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::NUT::Types::DriverPicker;

use strict;
use warnings;

use base 'EBox::Types::Abstract';

use EBox::Validate qw(:all);
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;

use Data::Dumper;
use File::Slurp;
use Text::CSV;

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
    EBox::debug('On printableValue');
    my ($self) = @_;

    my $ret = "";

    if ( defined ($self->{'manufacturer'}) and
         defined ($self->{'upsmodel'}) and
         defined ($self->{'driver'})) {
        $ret = "$self->{'manufacturer'}|||$self->{'upsmodel'}|||$self->{'driver'}";
    }

    return $ret;
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
    EBox::debug('On cmp');
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
    EBox::debug("On compareToHash");
    my ($self, $hash) = @_;

    my $oldManufacturer = $self->{'manufacturer'};
    my $oldModel        = $self->{'upsmodel'};
    my $oldDriver       = $self->{'driver'};

    my $manufacturer = $self->fieldName() . '_manufacturer';
    my $model        = $self->fieldName() . '_model';
    my $driver       = $self->fieldName() . '_driver';

    if (($oldManufacturer ne $hash->{$manufacturer}  ) or
        ($oldModel        ne $hash->{$model}) or
        ($oldDriver       ne $hash->{$driver})) {
        return 0;
    }

    return 1;
}

# Method: fields
#
# Overrides:
#
#       <EBox::Types::Abstract::fields>
#
# Returns:
#
#   Array containing the fields
#
sub fields
{
    EBox::debug("On fields");
    my ($self) = @_;

    my $manufacturer = $self->fieldName() . '_manufacturer';
    my $model        = $self->fieldName() . '_model';
    my $driver       = $self->fieldName() . '_driver';

    return ($manufacturer, $model, $driver);
}

# Method: value
#
# Overrides:
#
#       <EBox::Types::Abstract::value>
#
# Returns:
#
#   Hash ref containing the values (manufacturer, model, $driver)
#
sub value
{
    EBox::debug("On value");
    my ($self) = @_;

    my $value = {};
    $value->{manufacturer} = $self->{manufacturer};
    $value->{upsmodel}     = $self->{upsmodel};
    $value->{driver}       = $self->{driver};

    return $value;
}

sub manufacturer
{
    EBox::debug("On manufacturer");
    my ($self) = @_;

    return $self->{'manufacturer'};
}

sub upsmodel
{
    my ($self) = @_;

    my $model = $self->{'upsmodel'};
    EBox::debug("On upsmodel, return $model");

    return $self->{'upsmodel'};
}

sub driver
{
    EBox::debug("On driver");
    my ($self) = @_;

    return $self->{'driver'};
}

sub driverTable
{
    EBox::debug("On driverTable");
    my ($self) = @_;

    unless (defined ($driverTable)) {
        $driverTable = _loadDriverTable();
    }

    return $driverTable;
}

# Group: Protected methods

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setMemValue>
#
sub _setMemValue
{
    my ($self, $params) = @_;

    EBox::debug("On _setMemValue:");
    EBox::debug(Dumper($params));

    my $manufacturer = $self->fieldName() . '_manufacturer';
    my $model        = $self->fieldName() . '_model';
    my $driver       = $self->fieldName() . '_driver';

    $self->{'manufacturer'} = $params->{$manufacturer};
    $self->{'upsmodel'}     = $params->{$model};
    $self->{'driver'}       = $params->{$driver};
    EBox::debug("$self->{manufacturer}, $self->{upsmodel}, $self->{driver}");
}

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInGConf>
#
sub _storeInGConf
{
    EBox::debug("On _storeInGConf");
    my ($self, $gconfmod, $key) = @_;

    my $manufacturerKey = "$key/" . $self->fieldName() . '_manufacturer';
    my $modelKey        = "$key/" . $self->fieldName() . '_model';
    my $driverKey       = "$key/" . $self->fieldName() . '_driver';

    if ($self->{'manufacturer'} and $self->{'upsmodel'} and $self->{'driver'}) {
        $gconfmod->set_string($manufacturerKey, $self->{'manufacturer'}  );
        $gconfmod->set_string($modelKey, $self->{'upsmodel'});
        $gconfmod->set_string($driverKey, $self->{'driver'});
    } else {
        $gconfmod->unset($manufacturerKey);
        $gconfmod->unset($modelKey);
        $gconfmod->unset($driverKey);
    }
}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
{
    EBox::debug("On _restoreFromHash");
    my ($self) = @_;

    return unless ($self->row());
    my $manufacturer = $self->fieldName() . '_manufacturer';
    my $model        = $self->fieldName() . '_model';
    my $driver       = $self->fieldName() . '_driver';

    my $value = {};
    unless ($value = $self->_fetchFromCache()) {
        my $gconf = $self->row()->GConfModule();
        my $path = $self->_path();
        $value->{'manufacturer'} = $gconf->get_string($path . '/' . $manufacturer);
        $value->{'upsmodel'}     = $gconf->get_string($path . '/' . $model);
        $value->{'driver'}       = $gconf->get_string($path . '/' . $driver);
        $self->_addToCache($value);
    }

    $self->{'manufacturer'} = $value->{'manufacturer'};
    $self->{'upsmodel'}     = $value->{'upsmodel'};
    $self->{'driver'}       = $value->{'driver'};
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    EBox::debug("On _paramIsValid");
    my ($self, $params) = @_;

    EBox::debug(Dumper($params));

    my $manufacturer = $self->fieldName() . '_manufacturer';
    my $model        = $self->fieldName() . '_model';
    my $driver       = $self->fieldName() . '_driver';

    my $manufacturerValue = $params->{$manufacturer};
    my $modelValue        = $params->{$model};
    my $driverValue       = $params->{$driver};

    EBox::debug("$manufacturerValue, $modelValue, $driverValue");

    unless (defined ($driverTable)) {
        $driverTable = $self->_loadDriverTable();
    }

    my $manufacturerExists = 0;
    my $modelExists = 0;
    my $driverExists = 0;

    if (exists $driverTable->{$manufacturerValue}) {
        $manufacturerExists = 1;
        foreach my $entry (@{$driverTable->{$manufacturerValue}}) {
            if ($entry->{model} eq $modelValue) {
                $modelExists = 1;
                foreach my $driver (@{$entry->{driver}}) {
                    if ($driver eq $driverValue) {
                        $driverExists = 1;
                    }
                }
            }
        }
    }
    EBox::debug("$manufacturerValue, $modelValue, $driverValue");
    EBox::debug("$manufacturerExists, $modelExists, $driverExists");
    unless ($manufacturerExists) {
        throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $manufacturerValue,
            'advice' => __('This manufacturer does not exists.'));
    }
    unless ($modelExists) {
        throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $modelValue,
            'advice' => __('This model does not exists.'));
    }
    unless ($driverExists) {
        throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $driverValue,
            'advice' => __('This driver does not exists.'));
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
    EBox::debug("On _paramIsSet");
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
    EBox::debug("On _setValue");
    my ($self, $value) = @_;

    # There are countries America/Indiana/Indianapolis
    my ($manufacturer, $model, $driver) = split(/\|\|\|/, $value);

    my $params = {
        $self->fieldName() . '_manufacturer' => $manufacturer,
        $self->fieldName() . '_model'        => $model,
        $self->fieldName() . '_driver'       => $driver
    };
    EBox::debug(Dumper($params));

    $self->setMemValue($params);
}

# private methods

sub _loadDriverTable
{
    EBox::debug("On _loadDriverTable");
    my ($self) = @_;

    return $driverTable if (defined $driverTable);

    my $table = {};
    my $csv = Text::CSV->new({sep_char => "\t"});

    my @lines = read_file(DRIVER_LIST_FILE);
    foreach my $line (@lines) {
        next if ($line =~ m/^\s*#.*/ or $line =~ m/^\s*$/);
        my $status = $csv->parse($line);
        next unless $status;
        my @fields = $csv->fields();

        my $manufacturer = $fields[0];
        my $deviceType   = $fields[1];
        my $supportLevel = $fields[2];
        my $model        = $fields[3];
        my $modelExtra   = $fields[4];
        my $driver       = $fields[5];

        unless ($model ne '') {
            $model = "(all)";
        }

        unless (exists $table->{$manufacturer}) {
            $table->{$manufacturer} = [];
        }
        my $entry = { deviceType => $deviceType,
                      supportLevel => $supportLevel,
                      model => $model,
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
    EBox::debug(Dumper($table));
    return $table;
}

1;
