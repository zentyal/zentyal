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

package EBox::Types::Time;

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
        $opts{'HTMLSetter'} ='/ajax/setter/timeSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }

    $opts{'type'} = 'time' unless defined ($opts{'type'});
    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

sub paramExist
{
    my ($self, $params) = @_;

    my $hour = $self->fieldName() . '_hour';
    my $min  = $self->fieldName() . '_min';
    my $sec  = $self->fieldName() . '_sec';

    return (defined($params->{$hour}) and defined($params->{$min}) and defined($params->{$sec}));
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

    if (defined($self->{'hour'}) and defined($self->{'min'}) and defined($self->{'sec'})) {
        return sprintf("%02d", $self->{hour}) . ':'  .
               sprintf("%02d", $self->{min}) . ':'  .
               sprintf("%02d", $self->{sec});
    } else   {
        return '';
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

    unless (defined($self->{'hour'}) and defined($self->{'min'}) and defined($self->{'sec'})) {
        return undef;
    }

    if ($self->{'hour'} > $compareType->{'hour'}) {
        return 1;
    } elsif ($self->{'hour'} < $compareType->{'hour'}) {
        return -1;
    } else {
        if ($self->{'min'} > $compareType->{'min'}) {
            return 1;
        } elsif ($self->{'min'} < $compareType->{'min'}) {
            return -1;
        } else {
            if ($self->{'sec'} > $compareType->{'sec'}) {
                return 1;
            } elsif ($self->{'sec'} < $compareType->{'sec'}) {
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

sub compareToHash
{
    my ($self, $hash) = @_;

    my $oldHour = $self->{'hour'};
    my $oldMin  = $self->{'min'};
    my $oldSec  = $self->{'sec'};

    my $hour = $self->fieldName() . '_hour';
    my $min  = $self->fieldName() . '_min';
    my $sec  = $self->fieldName() . '_sec';

    if (($oldHour ne $hash->{$hour}) or
        ($oldMin  ne $hash->{$min} ) or
        ($oldSec  ne $hash->{$sec} )) {
        return 0;
    }

    return 1;
}

sub value
{
    my ($self) = @_;
    return ($self->{'hour'}, $self->{'min'}, $self->{'sec'});
}

sub hour
{
    my ($self) = @_;

    return $self->{'hour'};
}

sub minute
{
    my ($self) = @_;

    return $self->{'min'};
}

sub second
{
    my ($self) = @_;

    return $self->{'sec'};
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
    return [ 'hour', 'min', 'sec' ];
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
    my $fieldName = $self->fieldName();
    my @parts = grep { defined $_  } (
        $params->{$fieldName . "_hour"},
        $params->{$fieldName . "_min"},
        $params->{$fieldName . "_sec"},
       );

    if (@parts == 0) {
        # empty type
        return 1;
    }

    if (@parts != 3) {
        throw EBox::Exceptions::InvalidData(
            data   => $self->printableName(),
            value  => join ':', @parts,
            advice => __('Must be in the form HH:MM::SS')
        );
    }

    foreach my $part (@parts) {
        if (not $part =~ m/^\d+$/) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->printableName(),
                value  => $part,
                advice => __('No digit character in time component')
               );
        }
    }

    my ($hour, $sec, $min) = @parts;
    if ($hour > 23) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->printableName(),
                value  => $hour,
                advice => __('Invalid hours value')
               );
    }
    if ($min > 59) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->printableName(),
                value  => $min,
                advice => __('Invalid minutes value')
               );
    }
    if ($sec > 59) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->printableName(),
                value  => $sec,
                advice => __('Invalid seconds value')
               );
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
#     Set the value defined as a string: HH:MM:SS
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String HH:MM:SS
#
sub _setValue # (value)
{
    my ($self, $value) = @_;

    my ($hour, $min, $sec) = split (':', $value, 3);
    $hour =~ s/^0+(\d)/$1/ if defined $hour;
    $min =~ s/^0+(\d)/$1/  if defined $min;
    $sec =~ s/^0+(\d)/$1/  if defined $sec;

    my $params = {
        $self->fieldName() . '_hour' => $hour,
        $self->fieldName() . '_min'  => $min,
        $self->fieldName() . '_sec'  => $sec,
    };

    $self->setMemValue($params);
}

sub isEqualTo
{
    my ($self, $other) = @_;
    if (not $other->isa(__PACKAGE__)) {
        return undef;
    }

    if (($self->hour() ne $other->hour()) or
        ($self->minute() ne $other->minute()) or
        ($self->second() ne $other->second())) {
        return undef;
    }

    return 1;
}

1;
