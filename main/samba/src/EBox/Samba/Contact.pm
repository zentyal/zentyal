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

# Class: EBox::Samba::Contact
#
#   Samba contact, stored in samba LDAP
#
package EBox::Samba::Contact;

use base 'EBox::Samba::OrganizationalPerson';


# Method: create
#
#   Adds a new contact
#
# Parameters:
#
#   name - string with the contact full name
#   params hash ref (all optional):
#       givenName
#       initials
#       sn
#       displayName
#       description
#
# Returns:
#
#   Returns the new create contact object
#
sub create
{
    my ($self, $name, $params) = @_;

    $createdContact = $self->SUPER::create($name, $params);

    my $anyObjectClass = any($createdContact->get('objectClass'));
    my @contactExtraObjectClasses = ('contact');

    foreach my $extraObjectClass (@contactExtraObjectClasses) {
        if ($extraObjectClass ne $anyObjectClass) {
            $createdContact->add('objectClass', $extraObjectClass, 1);
        }
    }
    # Contact specific attributes.
    # TODO

    # Return the new created contact
    return $createdContact;
}

1;
