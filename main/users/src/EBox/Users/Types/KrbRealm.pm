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

# Class: EBox::Types::KrbRealm
#
#   A specialised text type to represent a kerberos realm
#
use strict;
use warnings;

package EBox::Types::KrbRealm;

use base 'EBox::Types::DomainName';

use EBox::Validate;
use EBox::Gettext;
use EBox::Exceptions::InvalidData;

# Group: Public methods

# Constructor: new
#
#   The constructor for the <EBox::Types::KrbRealm>
#
# Returns:
#
#   The created <EBox::Types::KrbRealm> object
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{'type'} = 'krbrealm';
    bless ($self, $class);
    return $self;
}

# Group: Protected methods

# Method: _paramIsValid
#
#   Check if the params has a correct kerberos realm
#
# Overrides:
#
#   <EBox::Types::DomainName::_paramIsValid>
#
# Parameters:
#
#     params - The HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct kerberos realm
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       kerberos realm
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if (defined ($value)) {
        EBox::Validate::checkDomainName($value, $self->printableName());

        my $seemsIp = EBox::Validate::checkIP($value);
        if ($seemsIp) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->printableName(),
                value  => $value,
                advice => __('IP addresses are not allowed'));
        }

        unless ($value =~ /^[A-Z0-9]+([\.][A-Z0-9]+)+$/) {
            throw EBox::Exceptions::InvalidData(
                data   => $self->printableName(),
                value  => $value,
                advice => __('Invalid realm name. Often, the realm is the uppercase version of the local DNS domain.'));
        }
    }

    return 1;
}

1;
