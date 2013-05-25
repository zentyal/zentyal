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

# Class: EBox::UsersAndGroups::Contact
#
#   Zentyal contact, stored in LDAP
#

package EBox::UsersAndGroups::Contact;

use base 'EBox::UsersAndGroups::InetOrgPerson';

# Method: create
#
#       Adds a new contact
#
# Parameters:
#
#   contact - hash ref containing:
#       fullname
#       givenname
#       initials
#       surname
#       displayname
#       comment
#       ou (multiple_ous enabled only)
#   params hash (all optional):
#       ignoreMods - modules that should not be notified about the contact creation
#       ignoreSlaves - slaves that should not be notified about the contact creation
#
# Returns:
#
#   Returns the new created contact object
#
sub create
{
    my ($self, $contact, %params) = @_;

    $contact->{fullname} = $self->generatedFullName($contact) unless (defined $contact->{fullname});

    unless ($contact->{fullname}) {
        throw EBox::Exceptions::InvalidData(
            data => __('given name, initials, surname'),
            value => __('empty'),
            advice => __('Either given name, initials or surname must be non empty')
        );
    }

    my $users = EBox::Global->modInstance('users');

    # Is the contact added to the default OU?
    my $isDefaultOU = 1;
    $contact->{dn} = 'cn=' . $contact->{fullname};
    if (EBox::Config::configkey('multiple_ous') and $contact->{ou}) {
        $contact->{dn} .= ',' . $contact->{ou};
        $isDefaultOU = ($contact->{ou} eq $users->usersDn());
    }
    else {
        $contact->{dn} .= ',' . $users->usersDn();
    }

    shift @_;
    $self->SUPER::create($contact, %params);
    return new EBox::UsersAndGroups::Contact(dn => $contact->{dn});
}

1;
