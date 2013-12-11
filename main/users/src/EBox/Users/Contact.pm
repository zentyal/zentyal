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

# Class: EBox::Users::Contact
#
#   Zentyal contact, stored in LDAP
#

package EBox::Users::Contact;

use base 'EBox::Users::InetOrgPerson';

use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;
use EBox::Exceptions::MissingArgument;

use TryCatch::Lite;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

# Method: mainObjectClass
#
sub mainObjectClass
{
    return 'inetOrgPerson';
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
    my $usersMod = EBox::Global->getInstance($ro)->modInstance('users');
    return $usersMod->objectFromDN('ou=Users,'.$usersMod->ldap->dn());
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
            $usersMod->notifyModsLdapUserBase('modifyContact', $self, $self->{ignoreMods}, $self->{ignoreSlaves});
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
    $usersMod->notifyModsLdapUserBase('delContact', $self, $self->{ignoreMods}, $self->{ignoreSlaves});

    # Call super implementation
    shift @_;
    $self->SUPER::deleteObject(@_);
}

# Method: fullname
#
#  Overrided because we cannot use the cn
sub fullname
{
    my ($self) = @_;
    my $givenname = $self->get('givenname');
    my $surname   = $self->get('sn');
    return "$givenname $surname";
}

# Method: create
#
#       Adds a new contact
#
# Parameters:
#
#   args - Named parameters:
#       parent
#       fullname
#       givenname
#       initials
#       surname
#       displayname
#       description
#       mail
#       ignoreMods - modules that should not be notified about the contact creation
#       ignoreSlaves - slaves that should not be notified about the contact creation
#
sub create
{
    my ($class, %args) = @_;

    # Check for required arguments.
    throw EBox::Exceptions::MissingArgument('fullname') unless ($args{fullname});
    throw EBox::Exceptions::MissingArgument('parent') unless ($args{parent});
    throw EBox::Exceptions::InvalidData(
        data => 'parent', value => $args{parent}->dn()) unless ($args{parent}->isContainer());

    my $fullName = $args{fullname};
    my $parent = $args{parent};
    my $ignoreMods   = $args{ignoreMods};
    my $ignoreSlaves = $args{ignoreSlaves};

    $fullName = $class->generatedFullName(%args) unless ($fullName);

    unless ($fullName) {
        throw EBox::Exceptions::InvalidData(
            data => __('given name, initials, surname'),
            value => __('empty'),
            advice => __('Either given name, initials or surname must be non empty')
        );
    }

    $class->checkCN($parent, $fullName);

    my $usersMod = EBox::Global->modInstance('users');

    my $dn = 'cn=' . $fullName . ',' . $parent->dn();

    my $res = undef;
    my $parentRes = undef;
    my $entry = undef;
    try {
        $args{dn} = $dn;
        $parentRes = $class->SUPER::create(%args);

        # Call modules initialization. The notified modules can modify the entry, add or delete attributes.
        $entry = $parentRes->_entry();
        $usersMod->notifyModsPreLdapUserBase(
            'preAddContact', [$entry, $parent], $ignoreMods, $ignoreSlaves);

        my $result = $entry->update($class->_ldap->{ldap});
        if ($result->is_error()) {
            unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error on contact LDAP entry creation:'),
                    result => $result,
                    opArgs => $class->entryOpChangesInUpdate($entry),
                   );
            };
        }

        $res = new EBox::Users::Contact(dn => $dn);

        # Call modules initialization
        $usersMod->notifyModsLdapUserBase('addContact', $res, $ignoreMods, $ignoreSlaves);
    } catch ($error) {
        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if (defined $res and $res->exists()) {
            $usersMod->notifyModsLdapUserBase('addContactFailed', $res, $ignoreMods, $ignoreSlaves);
            $res->SUPER::deleteObject(@_);
        } elsif ($parentRes and $parentRes->exists()) {
            $usersMod->notifyModsPreLdapUserBase(
                'preAddContactFailed', [$entry, $parent], $ignoreMods, $ignoreSlaves);
            $parentRes->deleteObject(@_);
        }
        $res = undef;
        $parentRes = undef;
        $entry = undef;
        throw $error;
    }

    if ($res->{core_changed}) {
        $res->save();
    }

    return $res;
}

1;
