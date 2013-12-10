# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Types::InverseMatchSelect;

use base 'EBox::Types::Select';

# Class: EBox::Types::InverseMatchSelect
#
#	This class inherits from <EBox::Types::Select> to add
#	inverse match support
#
#   FIXME: This package shouldn't exist as we should provide inverse match
#   feature form abstract types and provide a real OO approach, not this
#   ugly repetition of code in InverseMatch* types.
#
#   We are repeating ourselves, this sucks so freaking much.
#

use EBox;
use EBox::Gettext;

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/inverseMatchSelectSetter.mas';
    }
    unless (exists $opts{'inverseMatchPrintableString'}) {
        $opts{'inverseMatchPrintableString'} = __('Not');
    }
    $opts{'type'} = 'select';
    if ( defined ( $opts{'optional'} ) and
            (not $opts{'optional'} )) {
        EBox::warn('EBox::Types::InverseMatchSelect cannot be compulsory');
    }

    $opts{'optional'} = undef;
    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

sub inverseMatchField
{
    my ($self) = @_;

    return $self->fieldName() . '_inverseMatch';
}

sub compareToHash
{
    my ($self, $hash) = @_;

    unless  ($self->inverseMatch()
            eq $hash->{$self->inverseMatchField()}) {

        return undef;
    }

    return $self->SUPER::compareToHash($hash);
}

sub isEqualTo
{
    my ($self, $newObject) = @_;

    unless  ($self->SUPER::isEqualTo($newObject)) {
        return undef;

    }

    return ($self->inverseMatch() eq $newObject->inverseMatch());
}

sub printableValue
{
    my ($self) = @_;

    my $printValue = $self->SUPER::printableValue();

    if ($self->inverseMatch()) {
        $printValue =  $self->{inverseMatchPrintableString} .   " $printValue";
    }

    return $printValue;
}

sub fields
{
    my ($self) = @_;

    return ($self->inverseMatchField(), $self->SUPER::fields());
}

sub inverseMatch
{
    my ($self) = @_;

    return 0 unless defined ($self->{'inverseMatch'});
    return $self->{'inverseMatch'};
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

    $self->SUPER::_setMemValue($params);

    $self->{'inverseMatch'} = $params->{$self->inverseMatchField()};
}

# Method: _storeInHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInHash>
#
sub _storeInHash
{
    my ($self, $hash) = @_;

    $self->SUPER::_storeInHash($hash);
    $hash->{$self->inverseMatchField()} = $self->inverseMatch();
}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
{
    my ($self, $hash) = @_;

    return unless ($self->row());

    $self->SUPER::_restoreFromHash($hash);
    my $field = $self->fieldName() . '_inverseMatch';
    $self->{'inverseMatch'} = $hash->{$field};
}

# Method: _setValue
#
#     Set the value if any. The value may follow this pattern:
#
#     { inverse => [0|1], value => selectedValue }
#
#     Or it can appear just the selected value, setting implicitily
#     the inverse value as false.
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - hash ref or a basic value to pass
#
sub _setValue # (value)
{
    my ($self, $value) = @_;

    my ($selectedValue, $invMatch);
    if ( ref ( $value ) eq 'HASH' ) {
        $selectedValue = $value->{'value'};
        $invMatch = $value->{'inverse'};
    } else {
        $selectedValue = $value;
        $invMatch = 0;
    }

    my $params = {
        $self->fieldName() => $selectedValue,
        $self->inverseMatchField => $invMatch,
    };

    $self->setMemValue($params);
}

1;
