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

# Class: EBox::Samba::OrganizationalPerson
#
#   Samba Organization Person, stored in samba LDAP
#
package EBox::Samba::OrganizationalPerson;

use base 'EBox::Samba::LdbObject';

use EBox::Gettext;

use EBox::Exceptions::UnwillingToPerform;

use EBox::Samba::Group;

# Method: name
#
#   Return the name of this person
#
sub name
{
    my ($self) = @_;
    return $self->get('cn');
}

# Method: givenName
#
#   Return the given name of this person
#
sub givenName
{
    my ($self) = @_;
    return $self->get('givenName');
}

# Method: initials
#
#   Return the initials of this person
#
sub initials
{
    my ($self) = @_;
    return $self->get('initials');
}

# Method: surname
#
#   Return the surname of this person
#
sub surname
{
    my ($self) = @_;
    return $self->get('sn');
}

# Method: displayName
#
#   Return the display name of this person
#
sub displayName
{
    my ($self) = @_;
    return $self->get('displayName');
}

# Method: description
#
#   Return the description of this person
#
sub description
{
    my ($self) = @_;
    return $self->get('description');
}

# Method: mail
#
#   Return the mail of this person
#
sub mail
{
    my ($self) = @_;
    return $self->get('mail');
}

# Method: addGroup
#
#   Add this person to the given group
#
# Parameters:
#
#   group - Group object
#
sub addGroup
{
    my ($self, $group) = @_;

    $group->addMember($self);
}

# Method: removeGroup
#
#   Removes this person from the given group
#
# Parameters:
#
#   group - Group object
#
sub removeGroup
{
    my ($self, $group) = @_;

    $group->removeMember($self);
}

# Method: groups
#
#   Groups this person belongs to
#
# Returns:
#
#   array ref of EBox::Samba::Group objects
#
sub groups
{
    my ($self, %params) = @_;

    return $self->_groups(%params);
}

# Method: groupsNotIn
#
#   Groups this person does not belong to
#
# Returns:
#
#   array ref of EBox::Users::Group objects
#
sub groupsNotIn
{
    my ($self, %params) = @_;

    $params{invert} = 1;

    return $self->_groups(%params);
}

sub _groups
{
    my ($self, %params) = @_;

    my $dn = $self->dn();
    my $filter;
    if ($params{invert}) {
        $filter = "(&(objectclass=group)(!(member=$dn)))";
    } else {
        $filter = "(&(objectclass=group)(member=$dn))";
    }

    my $attrs = {
        base => $self->_ldap->dn(),
        filter => $filter,
        scope => 'sub',
    };

    my $result = $self->_ldap->search($attrs);

    my $groups = [];
    if ($result->count > 0) {
        foreach my $entry ($result->sorted('cn')) {
            push (@{$groups}, new EBox::Samba::Group(entry => $entry));
        }
    }
    return $groups;
}

# Method: deleteObject
#
#   Delete the person
#
sub deleteObject
{
    my ($self) = @_;

    unless ($self->checkObjectErasability()) {
        throw EBox::Exceptions::UnwillingToPerform(
            reason => __x('The object {x} is a system critical object.',
                          x => $self->dn()));
    }

    # remove this user from all its grups
    foreach my $group (@{$self->groups()}) {
        $self->removeGroup($group);
    }

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

1;
