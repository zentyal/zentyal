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

use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

use EBox::Users::Contact;

use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use Error qw(:try);

sub mainObjectClass
{
    return 'contact';
}

# Method: create
#
# FIXME: We should find a way to share code with the Contact::create method using the common class. I had to revert it
# because an OrganizationalPerson reconversion to a Contact failed.
#
#   Adds a new contact
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
    throw EBox::Exceptions::MissingArgument('parent') unless ($args{parent});
    throw EBox::Exceptions::InvalidData(
        data => 'parent', value => $args{parent}->dn()) unless ($args{parent}->isContainer());

    my $name = $args{name};
    my $dn = "CN=$name," . $args{parent}->dn();

    my @attr = ();
    push (@attr, objectClass => ['top', 'person', 'organizationalPerson', 'contact']);
    push (@attr, cn          => $name);
    push (@attr, name        => $name);
    push (@attr, givenName   => $args{givenName}) if ($args{givenName});
    push (@attr, initials    => $args{initials}) if ($args{initials});
    push (@attr, sn          => $args{sn}) if ($args{sn});
    push (@attr, displayName => $args{displayName}) if ($args{displayName});
    push (@attr, description => $args{description}) if ($args{description});
    push (@attr, mail        => $args{mail}) if ($args{mail});

    my $res = undef;
    my $entry = undef;
    try {
        $entry = new Net::LDAP::Entry($dn, @attr);

        my $result = $entry->update($class->_ldap->connection());
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
    my ($self) = @_;

    my $sambaMod = EBox::Global->modInstance('samba');
    my $parent = $sambaMod->ldapObjectFromLDBObject($self->parent);

    if (not $parent) {
        my $dn = $self->dn();
        throw EBox::Exceptions::External("Unable to to find the container for '$dn' in OpenLDAP");
    }
    my $name = $self->name();
    my $givenName = $self->givenName();
    my $surname = $self->surname();
    $givenName = '-' unless defined $givenName;
    $surname = '-' unless defined $surname;

    my $zentyalContact = undef;
    EBox::info("Adding samba contact '$name' to Zentyal");
    try {
        my %args = (
            parent       => $parent,
            fullname     => scalar ($name),
            givenname    => scalar ($givenName),
            initials     => scalar ($self->initials()),
            surname      => scalar ($surname),
            displayname  => scalar ($self->displayName()),
            description  => scalar ($self->description()),
            mail         => scalar ($self->mail()),
            ignoreMods   => ['samba'],
        );

        my $zentyalContact = EBox::Users::Contact->create(%args);
        $self->_linkWithUsersObject($zentyalContact);
    } catch EBox::Exceptions::DataExists with {
        EBox::debug("Contact $name already in OpenLDAP database");
    } otherwise {
        my $error = shift;
        EBox::error("Error loading contact '$name': $error");
    };
}

sub updateZentyal
{
    my ($self) = @_;

    my $name = $self->name();
    EBox::info("Updating zentyal contact '$name'");

    my $givenName = $self->givenName();
    my $surname = $self->surname();
    my $initials = $self->initials();
    my $displayName = $self->displayName();
    my $description = $self->description();
    my $mail = $self->mail();
    $givenName = '-' unless defined $givenName;
    $surname = '-' unless defined $surname;

    my $sambaMod = EBox::Global->modInstance('samba');
    my $zentyalContact = $sambaMod->ldapObjectFromLDBObject($self);
    throw EBox::Exceptions::Internal("Zentyal contact '$name' does not exist") unless ($zentyalContact and $zentyalContact->exists());

    $zentyalContact->setIgnoredModules(['samba']);
    $zentyalContact->set('cn', $name, 1);
    $zentyalContact->set('givenName', $givenName, 1);
    $zentyalContact->set('initials', $initials, 1);
    $zentyalContact->set('sn', $surname, 1);
    $zentyalContact->set('displayName', $displayName, 1);
    $zentyalContact->set('description', $description, 1);
    $zentyalContact->set('mail', $mail, 1);
    $zentyalContact->save();
}

1;
