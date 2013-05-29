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

sub addToZentyal
{
    my ($self) = @_;

    my $fullName = $self->get('name');
    my $givenName = $self->get('givenName');
    my $initials = $self->get('initials');
    my $surName = $self->get('sn');
    my $displayName = $self->get('displayName');
    my $comment = $self->get('description');
    $givenName = '-' unless defined $givenName;
    $surName = '-' unless defined $surName;

    my $params = {
        fullname => $fullName,
        givenname => $givenName,
        initials => $initials,
        surname => $surName,
        displayname => $displayName,
        comment => $comment,
    };

    my $zentyalContact = undef;
    my %optParams;
    $optParams{ignoreMods} = ['samba'];
    EBox::info("Adding samba contact '$fullName' to Zentyal");

    $zentyalContact = EBox::UsersAndGroups::Contact->create($params, 0, %optParams);
    $zentyalContact->exists() or
        throw EBox::Exceptions::Internal("Error addding samba contact '$fullName' to Zentyal");

    $zentyalContact->setIgnoredModules(['samba']);
}

sub updateZentyal
{
    my ($self) = @_;

    my $name = $self->get('name');
    EBox::info("Updating zentyal contact '$name'");

    my $zentyalUser = undef;
    my $fullName = $name;
    my $givenName = $self->get('givenName');
    my $initials = $self->get('initials');
    my $surName = $self->get('sn');
    my $displayName = $self->get('displayName');
    my $description = $self->get('description');
    my $uidNumber = $self->get('uidNumber');
    $givenName = '-' unless defined $givenName;
    $surName = '-' unless defined $surName;

    my $users = EBox::Global->modInstance('users');

    my $dn = 'cn=' . $name . ',' . $users->usersDn();

    $zentyalContact = new EBox::UsersAndGroups::Contact(dn => $dn);
    $zentyalContact->exists() or
        throw EBox::Exceptions::Internal("Zentyal contact '$name' does not exist");

    $zentyalContact->setIgnoredModules(['samba']);
    $zentyalContact->set('cn', $fullName, 1);
    $zentyalContact->set('givenName', $givenName, 1);
    $zentyalContact->set('initials', $initials, 1);
    $zentyalContact->set('sn', $surName, 1);
    $zentyalContact->set('displayName', $displayName, 1);
    $zentyalContact->set('description', $description, 1);
    $zentyalContact->save();
}

1;
