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

# Class: EBox::Users::OU
#
#   Organizational Unit, stored in LDAP
#

package EBox::Users::OU;
use base 'EBox::Users::LdapObject';

use EBox::Gettext;
use EBox::Global;
use EBox::Users;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::MissingArgument;

use Net::LDAP::Entry;
use Net::LDAP::Constant;
use TryCatch::Lite;

# Method: mainObjectClass
#
#  Returns:
#     object class name which will be used to discriminate ou
sub mainObjectClass
{
    return 'organizationalUnit';
}

# Method: isContainer
#
#   Return that this Organizational Unit can hold other objects.
#
#   Override <EBox::Users::LdapObject::isContainer>
#
sub isContainer
{
    return 1;
}

# Method: name
#
#   Return the name of this OU.
#
#   Override <EBox::Users::LdapObject::name>
sub name
{
    my ($self) = @_;

    return $self->get('ou');
}

# Method: create
#
#   Add and return a new Organizational Unit.
#
#   Throw EBox::Exceptions::InvalidData if a non valid character is detected on $name.
#   Throw EBox::Exceptions::InvalidType if $parent is not a valid container.
#   Throw Ebox::Exceptions::DataExists if $name already exists
#
# Parameters:
#
#   args - Named parameters:
#      name    - Organizational Unit name
#       parent - Parent container that will hold this new OU.
#
sub create
{
    my ($class, %args) = @_;

    my $usersMod = EBox::Global->modInstance('users');

    $args{parent} or
        throw EBox::Exceptions::MissingArgument('parent');
    $args{parent}->isContainer() or
        throw EBox::Exceptions::InvalidData(data => 'parent', value => $args{parent}->dn());

    my @attrs = (
            'objectclass' => ['organizationalUnit'],
            'ou' => $args{name},
           );

    my $entry;
    my $ou;
    my $dn = "ou=$args{name}," . $args{parent}->dn();
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($dn, @attrs);
        $usersMod->notifyModsPreLdapUserBase(
            'preAddOU', [$entry, $args{parent}], $args{ignoreMods}, $args{ignoreSlaves});
        my $changetype =  $entry->changetype();
        my $changes = [$entry->changes()];
        my $result = $entry->update($class->_ldap->{ldap});
        if ($result->is_error()) {
            unless (($result->code == Net::LDAP::Constant::LDAP_LOCAL_ERROR) and
                    ($result->error eq 'No attributes to update')
                   ) {
                        throw EBox::Exceptions::LDAP(
                            message => __('Error on group LDAP entry creation:'),
                            result => $result,
                            opArgs   => $class->entryOpChangesInUpdate($entry),
                           );
            }
        }

        $ou = EBox::Users::OU->new(dn => $dn);
        # Call modules initialization
        $usersMod->notifyModsLdapUserBase('addOU', $ou, $args{ignoreMods}, $args{ignoreSlaves});
    } catch ($error) {
        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if ($ou and $ou->exists()) {
            $usersMod->notifyModsLdapUserBase('addOUFailed', [ $ou ], $args{ignoreMods}, $args{ignoreSlaves});
            $ou->SUPER::deleteObject(@_);
        } else {
            $usersMod->notifyModsPreLdapUserBase(
                'preAddOUFailed', [$entry, $args{parent}], $args{ignoreMods}, $args{ignoreSlaves});
            throw EBox::Exceptions::DataExists('data' => __('Organizational Unit'),
                                               'value' => $args{name});
        }
        $ou = undef;
        $entry = undef;
        $error->throw();
    }

    return $ou;
}

# Method: deleteObject
#
#   Delete the OU
#
sub deleteObject
{
    my ($self, %params) = @_;

    # Notify group deletion to modules
    my $usersMod = $self->_usersMod();
    $usersMod->notifyModsLdapUserBase('delOU', $self, $self->{ignoreMods}, $self->{ignoreSlaves});
    if (not $params{recursive}) {
        $self->_deleteObjectAndContents();
    } else {
        $self->SUPER::deleteObject(%params);
    }
}

sub _deleteObjectAndContents
{
    my ($self) = @_;
    my $usersMod = $self->_usersMod();
    my $ldap = $self->_ldap->{ldap};

    my $result = $ldap->search(
        base   => $self->dn(),
        filter => "(objectclass=*)",
    );
    # deeper entries, first in order
    my @entries = sort { $b->dn =~ tr/,// <=> $a->dn =~ tr/,//} $result->entries();
    foreach my $entry (@entries) {
        my $object = $usersMod->entryModeledObject($entry);
        if ($object) {
            # call proper method to give opportunity to clean u[
            $object->deleteObject(recursive => 1);
        } else {
            # standard LDAP removal
            $entry->delete();
            $entry->update($ldap);
        }
    }
}

sub defaultContainer
{
    my $usersMod = EBox::Global->getInstance()->modInstance('users');
    return $usersMod->defaultNamingContext();
}

1;
