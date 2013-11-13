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

package EBox::Types::TimeZone;

use base 'EBox::Types::Abstract';

use File::Slurp;
use File::Basename;

use EBox::Validate qw(:all);
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use constant ZONES_DIR  => '/usr/share/zoneinfo';
use constant ZONES_FILE => ZONES_DIR . '/zone.tab';

my $zones = undef;

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    # Load and cache the zones
    unless (defined ($zones)) {
        $zones = _loadZones();
    }

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/timezoneSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    unless (exists $opts{printableName}) {
        $opts{printableName} = __('Time zone');
    }

    $opts{'type'} = 'timezone' unless defined ($opts{'type'});
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

    my $ret = "";

    if ( defined ($self->{'continent'}) and
         defined ($self->{'country'}) ) {
        $ret = "$self->{'continent'}/$self->{'country'}";
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
    my ($self, $compareType) = @_;

    unless ( (ref $self) eq (ref $compareType) ) {
        return undef;
    }

    unless ( defined ($self->{'continent'}  ) and
             defined ($self->{'country'}) ) {
        return undef;
    }

    if (($self->{'continent'} eq $compareType->{'continent'}) and
        ($self->{'country'}   eq $compareType->{'country'})) {
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

    my $oldContinent = $self->{'continent'};
    my $oldCountry   = $self->{'country'};

    my $continent = $self->fieldName() . '_continent';
    my $country   = $self->fieldName() . '_country';

    if (($oldContinent ne $hash->{$continent}  ) or
        ($oldCountry   ne $hash->{$country})) {
        return 0;
    }

    return 1;
}

sub _attrs
{
    return [ 'continent', 'country' ];
}

# Method: value
#
# Overrides:
#
#       <EBox::Types::Abstract::value>
#
# Returns:
#
#   Hash ref containing the values (continent, country)
#
sub value
{
    my ($self) = @_;

    my $value = {};
    $value->{continent} = $self->{continent};
    $value->{country} = $self->{country};

    return $value;
}

sub continent
{
    my ($self) = @_;

    return $self->{'continent'};
}

sub country
{
    my ($self) = @_;

    return $self->{'country'};
}

sub zones
{
    my ($self) = @_;

    unless (defined ($zones)) {
        $zones = _loadZones();
    }

    return $zones;
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

    my $continent = $self->fieldName() . '_continent';
    my $country   = $self->fieldName() . '_country';

    my $continentValue = $params->{$continent};
    my $countryValue   = $params->{$country};

    return 0 unless ($continentValue and $countryValue);

    unless (defined ($zones)) {
        $zones = $self->_loadZones();
    }

    if (exists $zones->{$continentValue}) {
        foreach my $country (@{$zones->{$continentValue}}) {
            if ($country eq $countryValue) {
                return 1;
            }
        }
        throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $countryValue,
            'advice' => __('This city does not exist.'));
    }

    throw EBox::Exceptions::InvalidData(
            'data'   => $self->printableName(),
            'value'  => $continentValue,
            'advice' => __('This continent does not exist.'));

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
    my ($self, $params) = @_;

    return 1;
}

# Method: _setValue
#
#     Set the value defined as a string: continent/country
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String continent/country
#
sub _setValue
{
    my ($self, $value) = @_;

    # There are countries America/Indiana/Indianapolis
    my ($continent, @countryArray) = split(/\//, $value);
    my $country = join('/', @countryArray);

    my $params = {
        $self->fieldName() . '_continent' => $continent,
        $self->fieldName() . '_country' => $country,
    };

    $self->setMemValue($params);
}

# private methods

sub _loadZones
{
    my $table = {};

    # Add zones from the filesystem to include aliases (symlinks)
    foreach my $dir (qw(Africa America Asia Atlantic Australia Etc Europe Pacific US)) {
        foreach my $file (glob (ZONES_DIR . "/$dir/*")) {
            $table->{$dir}->{basename($file)} = 1;
        }
    }

    # TODO: Add other zones from zone.tab but we should probably remove this code
    # in Zentyal 3.1 and read everything from the files
    my @lines = read_file(ZONES_FILE);
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^#/) {
            next;
        }
        my @fields = split(/^([^\s\#]+)\s([^\s]+)\s([^\s\/]+)(\/)([^\s]+)/, $line);
        my $continent = $fields[3];
        my $city = $fields[5];
        $table->{$continent}->{$city} = 1;
    }

    foreach my $continent (keys %{$table}) {
        my @cities = sort keys %{$table->{$continent}};
        $table->{$continent} = \@cities;
    }

    return $table;
}

1;
