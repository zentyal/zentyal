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

use EBox::Exceptions::Internal;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::MissingArgument;

use EBox::Users::Contact;

use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use Error qw(:try);

# Method: create
#
# FIXME: We should find a way to share code with the Contact::create method using the common class. I had to revert it
# because an OrganizationalPerson reconversion to a Contact failed.
#
#   Adds a new user
#
# Parameters:
#
#   args - Named parameters:
#       name
#       givenName
#       initials
#       sn
#       displayName
#       description
#       mail
#       samAccountName - string with the user name
#       clearPassword - Clear text password
#       kerberosKeys - Set of kerberos keys
#       uidNumber - user UID numberer
#
# Returns:
#
#   Returns the new create user object
#
sub create
{
    my ($class, %args) = @_;

    # Check for required arguments.
    throw EBox::Exceptions::MissingArgument('name') unless ($args{name});

    my $name = $args{name};
    # TODO Is the user added to the default OU?
    my $baseDn = $class->_ldap->dn();
    my $dn = "CN=$name,CN=Users,$baseDn";

    $class->_checkAccountNotExists($name);

    my @attr = ();
    push (@attr, objectClass => ['top', 'person', 'organizationalPerson', 'contact']);
    push (@attr, cn          => $name);
    push (@attr, name        => $name);
    push (@attr, givenName   => $args{givenName}) if ($args{givenName});
    push (@attr, initials    => $args{initials}) if ($args{initials});
    push (@attr, sn          => $args{sn}) if ($args{sn});
    push (@attr, displayName => $args{displayName}) if ($args{displayName});
    push (@attr, description => $args{description}) if ($args{description});

    my $res = undef;
    my $entry = undef;
    try {
        $entry = new Net::LDAP::Entry($dn, @attr);

        my $result = $entry->update($class->_ldap->ldbCon());
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on person LDAP entry creation:'),
                    result => $result,
                    opArgs => $class->entryOpChangesInUpdate($entry),
                );
            };
        }

        $res = new EBox::Samba::Contact(dn => $dn);

    } otherwise {
        my ($error) = @_;

        EBox::error($error);

        if (defined $res and $res->exists()) {
            $res->SUPER::deleteObject(@_);
        }
        $res = undef;
        $entry = undef;
        throw $error;
    };

    return $res;
}

sub addToZentyal
{
    my ($self, $ou) = @_;
    $ou or throw EBox::Exceptions::MissingArgument('ou');

    my $fullName = $self->get('name');
    my $givenName = $self->get('givenName');
    my $initials = $self->get('initials');
    my $surName = $self->get('sn');
    my $displayName = $self->get('displayName');
    my $description = $self->get('description');
    $givenName = '-' unless defined $givenName;
    $surName = '-' unless defined $surName;

    my $parent = EBox::Users::Contact->defaultContainer();

    my %args = (
        fullname => $fullName,
        givenname => $givenName,
        initials => $initials,
        surname => $surName,
        displayname => $displayName,
        description => $description,
        parent => $parent,
        ignoreMods => ['samba'],
    );

    EBox::info("Adding samba contact '$fullName' to Zentyal");
    my $zentyalContact = EBox::Users::Contact->create(%args);
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
    $givenName = '-' unless defined $givenName;
    $surName = '-' unless defined $surName;

    my $users = EBox::Global->modInstance('users');

    my $dn = 'cn=' . $name . ',' . $users->usersDn();

    my $zentyalContact = new EBox::Users::Contact(dn => $dn);
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
