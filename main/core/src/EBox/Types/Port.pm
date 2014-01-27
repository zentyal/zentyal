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

package EBox::Types::Port;

use base 'EBox::Types::Int';

use EBox::Validate;

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    $self->{type} = 'port';

    bless($self, $class);
    return $self;
}

# Method: size
#
# Overrides:
#
#     <EBox::Types::Int::size>
#
sub size
{
    return 6;
}

# Method: _paramIsValid
#
#     Check if the params has a correct port
#
# Overrides:
#
#     <EBox::Types::Int::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct pot
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       port
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if (defined ( $value )) {
        EBox::Validate::checkPort($value, $self->printableName());
    }

    return 1;
}

1;
