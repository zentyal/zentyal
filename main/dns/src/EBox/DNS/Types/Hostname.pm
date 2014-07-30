# Copyright (C) 2011-2013 Zentyal S.L.
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

# Class:
#
#   <EBox::DNS::Types::Hostname>
#
#   This class inherits from <EBox::Types::DomainName> and represents
#   the hostname as a valid domain or the wildcard for default value
#
use strict;
use warnings;

package EBox::DNS::Types::Hostname;

use base 'EBox::Types::DomainName';

use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      The constructor for the <EBox::Types::DomainName>
#
# Returns:
#
#      the recently created <EBox::Types::DomainName> object
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{'type'} = 'hostname';
    $self->{'allowUnsafeChars'} = 1;
    $self->{'help'} = __('A valid domain name or a wildcard (*) value '
                         . 'must be provided.');
    bless($self, $class);
    return $self;
}

# Method: cmp
#
# Overrides:
#
#      <EBox::Types::Text::cmp>
#
sub cmp
{
    my ($self, $compareType) = @_;

    unless ($self->isa(ref $compareType)) {
        return undef;
    }

    return uc($self->value()) cmp uc($compareType->value());

}

# Group: Protected methods

# Method: _paramIsValid
#
#     Check if the params has a correct domain name or the wildcard
#
# Overrides:
#
#     <EBox::Types::Text::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct hostname in named domain
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       host
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if (defined ( $value )) {
        if ( $value eq '*' ) {
            return 1;
        } else {
            $self->SUPER::_paramIsValid($params);
        }
    }
    return 1;
}

1;
