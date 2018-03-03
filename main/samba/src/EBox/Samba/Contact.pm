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

use EBox::Samba::Contact;

use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use TryCatch;

sub mainObjectClass
{
    return 'contact';
}

sub printableType
{
    return __('contact');
}

# Class method: defaultContainer
#
#   Parameters:
#     ro - wether to use the read-only version of the users module
#
#   Return the default container that will hold Group objects.
#
sub defaultContainer
{
    my ($class, $ro) = @_;
    my $usersMod = EBox::Global->getInstance($ro)->modInstance('samba');
    return $usersMod->objectFromDN('CN=Users,' . $usersMod->ldap->dn());
}

# Method: save
#
#   Saves the contact changes.
#
sub save
{
    my ($self) = @_;

    my $changetype = $self->_entry->changetype();

    my $hasCoreChanges = $self->{core_changed};

    shift @_;
    $self->SUPER::save(@_);

    if ($changetype ne 'delete') {
        if ($hasCoreChanges) {

            my $usersMod = $self->_usersMod();
            $usersMod->notifyModsLdapUserBase('modifyContact', $self, $self->{ignoreMods});
        }
    }
}

# Method: deleteObject
#
#   Delete the contact
#
sub deleteObject
{
    my ($self) = @_;

    # Notify contact deletion to modules
    my $usersMod = $self->_usersMod();
    $usersMod->notifyModsLdapUserBase('delContact', $self, $self->{ignoreMods});

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

# Method: create
#
#   Adds a new contact
#
# Parameters:
#
#   args - Named parameters:
#       name *optional*
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
    throw EBox::Exceptions::MissingArgument('parent') unless ($args{parent});
    throw EBox::Exceptions::InvalidData(
        data => 'parent', value => $args{parent}->dn()) unless ($args{parent}->isContainer());

    my $name = $args{name};
    unless ($name) {
        $name = $class->generatedFullName(%args);
    }

    my $dn = "CN=$name," . $args{parent}->dn();

    # Check DN not exists
    my $msg = $class->_ldap->search({
        base => $dn,
        scope => 'base',
        filter => '(objectClass=*)'});
    if ($msg->count()) {
        throw EBox::Exceptions::External(
            __x("Username '{x}' already exists on the same container",
                x => $name));
    }

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
    } catch ($error) {
        EBox::error($error);

        if (defined $res and $res->exists()) {
            $res->SUPER::deleteObject(@_);
        }
        $res = undef;
        $entry = undef;
        throw $error;
    }

    return $res;
}

1;
