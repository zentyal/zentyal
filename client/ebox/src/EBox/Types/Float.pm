# Copyright (C) 2008 eBox Technologies S.L.
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

# Class: EBox::Types::Float
#
#     Describe a float number which is stored as a string in our
#     backend
#

package EBox::Types::Float;

use strict;
use warnings;

use base 'EBox::Types::Int';

# eBox uses
use EBox::Exceptions::External;
use EBox::Gettext;

# Core modules
use Scalar::Util;

# Group: Public methods

#  Constructor: new
#
#  Parameters:
#
#       (in addition of base classes parameters)
#       max - maximum integer value allowed
#       min - minimum integer value allowed (default: 0.0)
#
sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);

    bless($self, $class);

    $self->{'type'} = 'float';
    return $self;

}

# Group: Protected methods

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Int::_storeInGConf>
#
sub _storeInGConf
{
    my ($self, $gconfmod, $key) = @_;

    my $fieldKey ="$key/" . $self->fieldName();

    if (defined($self->memValue()) and $self->memValue() ne '') {
        $gconfmod->set_string($fieldKey, $self->memValue());
    } else {
        $gconfmod->unset($fieldKey);
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

    my $value = $params->{$self->fieldName()};

    unless( Scalar::Util::looks_like_number($value) ) {
        throw EBox::Exceptions::InvalidData(
            data   => $self->printableName(),
            value  => $value,
            advice => __('Enter a float number'));
    }

    my $max = $self->max();
    if (defined($max) and ($value > $max)) {
        throw EBox::Exceptions::InvalidData(
            data   => $self->printableName(),
            value  => $value,
            advice => __x(q|The value shouldn't be greater than {m}|, m => $max)
           );
    }

    my $min = $self->min();
    if (defined($min) and ($value < $min)) {
        throw EBox::Exceptions::InvalidData(
            data   => $self->printableName(),
            value  => $value,
            advice => __x(q|The value shouldn't be less than {m}|, m => $min)
           );
    }

    return 1;

}

1;
