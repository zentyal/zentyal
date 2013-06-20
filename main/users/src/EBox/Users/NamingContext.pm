# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::Users::NamingContext
#
#   Naming context, represents the root of an LDAP tree
#

package EBox::Users::NamingContext;
use base 'EBox::Users::LdapObject';

use EBox::Exceptions::Internal;

# Method: new
#
#   Instances a NamingContext from LDAP.
#
# Parameters:
#   dn    - Full dn for the naming context.
# or
#   entry - Net::LDAP::Entry for the Naming Context
#
sub new
{
    my ($class, %params) = @_;

    throw EBox::Exceptions::Internal(
        "A naming context cannot be instanciated from an ldif string") if (defined $params{ldif});

    my $self = return $class->SUPER::new(%params);        my $class = shift;
    bless ($self, $class);
    return $self;
}

# Method: isContainer
#
#   Return that this NamingContext can hold other objects.
#
#   Overrides >EBox::Users::LdapObject::isContainer>
#
sub isContainer
{
    return 1;
}

1;
