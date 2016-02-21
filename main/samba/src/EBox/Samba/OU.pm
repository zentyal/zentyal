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

# Class: EBox::Samba::OU
#
#   Organizational Unit, stored in LDAP
#

package EBox::Samba::OU;
use base 'EBox::Samba::LdapObject';

use EBox::Gettext;
use EBox::Global;
use EBox::Samba;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::MissingArgument;

use Net::LDAP::Entry;
use Net::LDAP::Constant;
use TryCatch;

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
#   Override <EBox::Samba::LdapObject::isContainer>
#
sub isContainer
{
    return 1;
}

sub printableType
{
    return __('Organization Unit');
}

# Method: name
#
#   Return the name of this OU.
#
#   Override <EBox::Samba::LdapObject::name>
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
#       name    - Organizational Unit name
#       parent - Parent container that will hold this new OU.
#
sub create
{
    my ($class, %args) = @_;

    my $usersMod = EBox::Global->modInstance('samba');

    $args{parent} or
        throw EBox::Exceptions::MissingArgument('parent');
    $class->_checkParent($args{parent});

    my $name = $args{name};
    my $parent = $args{parent};
    my $ignoreMods   = $args{ignoreMods};

    my @attrs = (
            'objectclass' => ['organizationalUnit'],
            'ou' => $name,
           );

    my $entry;
    my $ou;
    my $dn = "ou=$name," . $parent->dn();
    try {
        # Call modules initialization. The notified modules can modify the entry,
        # add or delete attributes.
        $entry = new Net::LDAP::Entry($dn, @attrs);
        $usersMod->notifyModsPreLdapUserBase(
            'preAddOU', [$entry, $parent], $ignoreMods);
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

        $ou = EBox::Samba::OU->new(dn => $dn);
        # Call modules initialization
        $usersMod->notifyModsLdapUserBase('addOU', $ou, $ignoreMods);
    } catch ($error) {
        EBox::error($error);

        # A notified module has thrown an exception. Delete the object from LDAP
        # Call to parent implementation to avoid notifying modules about deletion
        # TODO Ideally we should notify the modules for beginTransaction,
        #      commitTransaction and rollbackTransaction. This will allow modules to
        #      make some cleanup if the transaction is aborted
        if ($ou and $ou->exists()) {
            $usersMod->notifyModsLdapUserBase('addOUFailed', [ $ou ], $ignoreMods);
            $ou->SUPER::deleteObject(@_);
        } else {
            $usersMod->notifyModsPreLdapUserBase(
                'preAddOUFailed', [$entry, $parent], $ignoreMods);
            throw EBox::Exceptions::DataExists('data' => __('Organizational Unit'),
                                               'value' => $name);
        }
        $ou = undef;
        $entry = undef;
        $error->throw();
    }

    return $ou;
}

sub _checkParent
{
    my ($class, $parent) = @_;

    my $parentDN = $parent->dn();
    $parent->isContainer() or
        throw EBox::Exceptions::InvalidData(data => 'parent',
                                            value => $parentDN,
                                            advice => 'Parent should be a container'
                                           );

    my $baseDN    = $class->_ldap->dn();
    my @forbidden = qw(cn=Users ou=Users cn=Groups ou=Groups cn=Computers ou=Computers);
    foreach my $ouPortion (@forbidden) {
        my $dn = $ouPortion . ',' . $baseDN;
        if ($parentDN eq $dn) {
            throw  EBox::Exceptions::InvalidData(data => 'parent',
                                            value => $parentDN,
                                            advice => __('Creation of OUs inside either Users, Groups or Computer default OUs is not supported')
                                           );
        }
    }
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
    $usersMod->notifyModsLdapUserBase('delOU', $self, $self->{ignoreMods});
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
    my $usersMod = EBox::Global->getInstance()->modInstance('samba');
    return $usersMod->defaultNamingContext();
}

1;
