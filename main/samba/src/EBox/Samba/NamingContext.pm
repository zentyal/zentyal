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

# Class: EBox::Samba::NamingContext
#
#   Naming context, represents the root of an LDAP tree
#

package EBox::Samba::NamingContext;
use base 'EBox::Samba::LdapObject';

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

    (defined $params{ldif}) and
        throw EBox::Exceptions::Internal("A naming context cannot be instanciated from an ldif string");

    my $self = return $class->SUPER::new(%params);
    bless ($self, $class);
    return $self;
}

# Method: isContainer
#
#   Return that this NamingContext can hold other objects.
#
#   Override <EBox::Samba::LdapObject::isContainer>
#
sub isContainer
{
    return 1;
}

# Method: baseName
#
#   Return a string representing the base name of this Naming Context. A naming Object doesn't follow the
#   usual naming rules.
#
#   Override <EBox::Samba::LdapObject::baseName>
#
sub baseName
{
    my ($self) = @_;

    my $parent = $self->parent();
    if ($parent) {
        throw EBox::Exceptions::Internal("A Naming Context cannot have a parent: " . $parent->dn());
    }


    my $dn = $self->dn();
    my $baseName = '';
    for my $section (split (',', $dn)) {
        if ($baseName) {
            $baseName .= '.';
        }
        my ($trash, $value) = split ('=', $section, 2);
        $baseName .= $value;
    }
    return $baseName;
}

1;
