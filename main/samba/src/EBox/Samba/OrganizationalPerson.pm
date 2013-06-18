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

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::UnwillingToPerform;

use EBox::Samba::Credentials;

use EBox::Users::User;
use EBox::Samba::Group;

use Perl6::Junction qw(any);
use Encode;
use Net::LDAP::Control;
use Date::Calc;
use Error qw(:try);

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
    my ($self) = @_;

    return $self->_groups();
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
    my ($self) = @_;

    return $self->_groups(1);
}

sub _groups
{
    my ($self, $invert) = @_;

    my $dn = $self->dn();
    my $filter;
    if ($invert) {
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

    if ($self->checkObjectErasability()) {
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

# Method: create
#
#   Adds a new person
#
# Parameters:
#
#   name - The person name
#
#   params hash ref (all optional):
#       givenName
#       initials
#       sn
#       displayName
#       description
#
# Returns:
#
#   Returns the new create person object
#
sub create
{
    my ($self, $name, $params) = @_;

    # TODO Is the user added to the default OU?
    my $baseDn = $self->_ldap->dn();
    my $dn = "CN=$name,CN=Users,$baseDn";

    $self->_checkAccountNotExists($name);

    my $attr = [];
    push ($attr, objectClass => ('top', 'person', 'organizationalPerson'));
    push ($attr, name        => $name);
    push ($attr, givenName   => $params->{givenName}) if defined $params->{givenName};
    push ($attr, initials    => $params->{initials}) if defined $params->{initials};
    push ($attr, sn          => $params->{sn}) if defined $params->{sn};
    push ($attr, displayName => $params->{displayName}) if defined $params->{displayName};
    push ($attr, description => $params->{description}) if defined $params->{description};

    # Add the entry
    my $result = $self->_ldap->add($dn, { attr => $attr });
    my $createdPerson = new EBox::Samba::OrganizationalPerson(dn => $dn);

    # Return the new created person
    return $createdPerson;
}

1;
