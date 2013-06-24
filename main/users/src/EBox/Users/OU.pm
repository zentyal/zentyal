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

# Class: EBox::Users::OU
#
#   Organizational Unit, stored in LDAP
#

package EBox::Users::OU;
use base 'EBox::Users::LdapObject';

use EBox::Global;
use EBox::Users;

use EBox::Exceptions::InvalidData;

# Method: isContainer
#
#   Return that this Organizational Unit can hold other objects.
#
#   Override <EBox::Users::LdapObject::isContainer>
#
sub isContainer
{
    return 1;
}

# Method: name
#
#   Return the name of this OU.
#
#   Override <EBox::Users::LdapObject::name>
sub name
{
    my ($self) = @_;

    return $self->get('ou');
}

# Method: create
#
#   Add and return a new Organizational Unit.
#
#   Throw EBox::Exceptions::InvalidData if a non valid character is detected on $name.
#   Throw EBox::Exceptions::InvalidType if $parent is not a valid container.
#
# Parameters:
#
#   name   - Organizational Unit name
#   parent - Parent container that will hold this new OU.
#
sub create
{
    my ($self, $name, $parent) = @_;

    my $usersMod = EBox::Global->modInstance('users');

    throw EBox::Exceptions::InvalidData(data => 'name', value => $name) unless ($usersMod->checkCnLimitations($name));
    throw EBox::Exceptions::InvalidData(data => 'parent', value => $parent->dn()) unless ($parent->isContainer());

    my $args = {
        attr => [
            'objectclass' => ['organizationalUnit'],
            'ou' => $name,
        ]
    };

    my $dn = "ou=$name," . $parent->dn();
    my $result = $self->_ldap->add($dn, $args);
    my $res = new EBox::Users::OU(dn => $dn);
    return $res;
}

1;
