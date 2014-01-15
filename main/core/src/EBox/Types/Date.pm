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

package EBox::Types::Date;

use base 'EBox::Types::Abstract';

use EBox::Validate qw(:all);
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/dateSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    $opts{'type'} = 'date' unless defined ($opts{'type'});
    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

# Method: paramExist
#
# Overrides:
#
#       <EBox::Types::Abstract::paramExist>
#
sub paramExist
{
    my ($self, $params) = @_;

    my $day   = $self->fieldName() . '_day';
    my $month = $self->fieldName() . '_month';
    my $year  = $self->fieldName() . '_year';

    return ( defined($params->{$day}  ) and
             defined($params->{$month}) and
             defined($params->{$year} ) );
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

    if ( defined($self->{'day'}  ) and
         defined($self->{'month'}) and
         defined($self->{'year'} ) ) {
        return "$self->{'day'}/$self->{'month'}/$self->{'year'}";
    } else   {
        return "";
    }
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

    unless ( defined($self->{'day'}  ) and
             defined($self->{'month'}) and
             defined($self->{'year'} ) ) {
        return undef;
    }

    # First check the year, if equal check the month and if equal check the day
    if ($self->{'year'} > $compareType->{'year'}) {
        return 1;
    } elsif ($self->{'year'} < $compareType->{'year'}) {
        return -1;
    } else {
        if ($self->{'month'} > $compareType->{'month'}) {
            return 1;
        } elsif ($self->{'month'} < $compareType->{'month'}) {
            return -1;
        } else {
            if ($self->{'day'} > $compareType->{'day'}) {
                return 1;
            } elsif ($self->{'day'} < $compareType->{'day'}) {
                return -1;
            } else {
                return 0;
            }
        }
    }
}

sub size
{
    my ($self) = @_;

    return $self->{'size'};
}

# Method: compareToHash
#
# Overrides:
#
#       <EBox::Types::Abstract::compareToHash>
#
# Returns:
#
#   True (1) if equal, false (0) if not equal
#
sub compareToHash
{
    my ($self, $hash) = @_;

    my $oldDay   = $self->{'day'};
    my $oldMonth = $self->{'month'};
    my $oldYear  = $self->{'year'};

    my $day   = $self->fieldName() . '_day';
    my $month = $self->fieldName() . '_month';
    my $year  = $self->fieldName() . '_year';

    if (($oldDay   ne $hash->{$day}  ) or
        ($oldMonth ne $hash->{$month}) or
        ($oldYear  ne $hash->{$year} )) {
        return 0;
    }

    return 1;
}

# Method: value
#
# Overrides:
#
#       <EBox::Types::Abstract::value>
#
# Returns:
#
#   Array containing the values (day, month, year)
#
sub value
{
    my ($self) = @_;
    return ($self->{'day'}, $self->{'month'}, $self->{'year'});
}

sub day
{
    my ($self) = @_;
    return $self->{'day'};
}

sub month
{
    my ($self) = @_;
    return $self->{'month'};
}

sub year
{
    my ($self) = @_;
    return $self->{'year'};
}

# Group: Protected methods

# Method: _attrs
#
# Overrides:
#
#       <EBox::Types::Abstract::_attrs>
#
sub _attrs
{
    return [ 'day', 'month', 'year' ];
}

# Method: _paramIsValid
#
#       Checks that the date formed by the parameters ($day, $month, $year)
#   is correct. If not, throws an EBox::Exceptions::InvalidData exception.
#
sub _checkDate
{
    my ($self, $day, $month, $year) = @_;

    if ( $month == 2 ) {
        if ( $day > 29 ) {
            return 0;
        } elsif ( $day == 29 ) {
            if ( ( ($year % 4) != 0) or
                 ( (($year % 100) == 0) and
                   (($year % 400) != 0) ) ) {
                throw EBox::Exceptions::InvalidData
                    ('data'   => $self->printableName(),
                     'value'  => sprintf('%02d/%02d/%04d', $day, $month, $year),
                     'advice' => __('Not a leap year.'),
                    );
            }
        }
    } else {
        if ( $day > 30 ) {
            if ( ($month == 4) or ($month == 6) or
                 ($month == 9) or ($month == 11) ) {
                throw EBox::Exceptions::InvalidData
                    ('data'   => $self->printableName(),
                     'value'  => sprintf('%02d/%02d/%04d', $day, $month, $year),
                     'advice' => __('This month does not have 31 days.'),
                    );
            }
        }
    }
}

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $day   = $self->fieldName() . '_day';
    my $month = $self->fieldName() . '_month';
    my $year  = $self->fieldName() . '_year';

    $self->_checkDate($params->{$day}, $params->{$month}, $params->{$year});

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
#     Set the value defined as a string: DD/MM/YYYY
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String DD/MM/YYYY
#
sub _setValue # (value)
{
    my ($self, $value) = @_;

    my ($day, $month, $year) = split ('/', $value);
    $day   =~ s/^0+//;
    $month =~ s/^0+//;
    $year  =~ s/^0+//;

    my $params = {
        $self->fieldName() . '_day'   => $day,
        $self->fieldName() . '_month' => $month,
        $self->fieldName() . '_year'  => $year,
    };

    $self->setMemValue($params);
}

1;
