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

package EBox::Samba::LdbObject;
use base 'EBox::Users::LdapObject';

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::LDAP;

use Data::Dumper;
use Net::LDAP::LDIF;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);
use Net::LDAP::Control;

use Perl6::Junction qw(any);
use Error qw(:try);

my $_sambaMod;

# Method: new
#
#   Instance an object readed from LDAP.
#
#   Parameters:
#
#      dn - Full dn for the user
#  or
#      ldif - Reads the entry from LDIF
#  or
#      entry - Net::LDAP entry for the user
#  or
#      objectGUID - The LDB's objectGUID.
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    if ($params{objectGUID}) {
        $self->{objectGUID} = $params{objectGUID};
    } else {
        try {
            $self = $class->SUPER::new(%params);
        } catch EBox::Exceptions::MissingArgument with {
            my ($error) = @_;

            throw EBox::Exceptions::MissingArgument("$error|objectGUID");
        };
    }

    return $self;
}


# Method: objectGUID
#
#   Return the objectGUID attribute existent in any LDB object.
sub objectGUID
{
    my ($self) = @_;

    my $objectGUID = $self->get('objectGUID');
    return $self->_objectGUIDToString($objectGUID);
}

sub _objectGUIDToString
{
    my ($class, $objectGUID) = @_;

    my $unpacked = unpack("H*hex", $objectGUID);

    my $objectGUIDString = substr($unpacked, 6, 2);
    $objectGUIDString .= substr($unpacked, 4, 2);
    $objectGUIDString .= substr($unpacked, 2, 2);
    $objectGUIDString .= substr($unpacked, 0, 2);
    $objectGUIDString .= '-';
    $objectGUIDString .= substr($unpacked, 10, 2);
    $objectGUIDString .= substr($unpacked, 8, 2);
    $objectGUIDString .= '-';
    $objectGUIDString .= substr($unpacked, 14, 2);
    $objectGUIDString .= substr($unpacked, 12, 2);
    $objectGUIDString .= '-';
    $objectGUIDString .= substr($unpacked, 16, 4);
    $objectGUIDString .= '-';
    $objectGUIDString .= substr($unpacked, 20);

    return $objectGUIDString;
}

sub _stringToObjectGUID
{
    my ($class, $objectGUIDString) = @_;

    my $tmpString = substr($objectGUIDString, 6, 2);
    $tmpString .= substr($objectGUIDString, 4, 2);
    $tmpString .= substr($objectGUIDString, 2, 2);
    $tmpString .= substr($objectGUIDString, 0, 2);
    $tmpString .= substr($objectGUIDString, 11, 2);
    $tmpString .= substr($objectGUIDString, 9, 2);
    $tmpString .= substr($objectGUIDString, 16, 2);
    $tmpString .= substr($objectGUIDString, 14, 2);
    $tmpString .= substr($objectGUIDString, 19, 4);
    $tmpString .= substr($objectGUIDString, 24);

    my $objectGUID = pack("H*", $tmpString);

    return $objectGUID;
}

# Method: checkObjectErasability
#
#   Returns whether the object could be deleted or not.
sub checkObjectErasability
{
    my ($self) = @_;

    # Refuse to delete critical system objects
    my $isCritical = $self->get('isCriticalSystemObject');
    return not ($isCritical and (lc ($isCritical) eq 'true'));

}

# Method: deleteObject
#
#   Deletes this object from the LDAP
#
#   Override EBox::Users::LdapObject::deleteObject
#
sub deleteObject
{
    my ($self) = @_;

    unless ($self->checkObjectErasability()) {
        throw EBox::Exceptions::UnwillingToPerform(
            reason => __x('The object {x} is a system critical object.',
                          x => $self->dn()));
    }

	# Delete all entry childs or LDAP server will refuse to delete the entry
	my $searchParam = {
		base => $self->_entry->dn(),
		scope => 'one',
		filter => '(objectClass=*)',
		attrs => ['*'],
	};
	my $result = $self->_ldap->search($searchParam);
	foreach my $entry ($result->entries()) {
		my $obj = new EBox::Samba::LdbObject(entry => $entry);
		$obj->deleteObject();
	}

    $self->SUPER::deleteObject();
}

# Method: save
#
#   Store all pending lazy operations (if any)
#
#   This method is only needed if some operation
#   was used using lazy flag
#
#   Override EBox::Users::LdapObject::save
#
sub save
{
    my ($self, $control) = @_;
    my $entry = $self->_entry;

    $control = [] unless $control;
    my $result = $entry->update($self->_ldap->connection(), control => $control);
    if ($result->is_error()) {
        unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
            throw EBox::Exceptions::LDAP(
                message => __('There was an error updating LDAP:'),
                result =>   $result,
                opArgs   => $self->entryOpChangesInUpdate($entry),
            );
        }
    }
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the object
#
#   Override EBox::Users::LdapObject::_entry
#
sub _entry
{
    my ($self) = @_;

    if ($self->{entry} and (not $self->{entry}->exists('objectGUID'))) {
        $self->{dn} = $self->{entry}->dn();
        delete $self->{entry};
    }

    unless ($self->{entry}) {
        my $result = undef;
        my $base = undef;
        my $filter = undef;
        my $scope = undef;
        if ($self->{objectGUID}) {
            $base = $self->_ldap()->dn();
            $filter = "(objectGUID=" . $self->{objectGUID} . ")";
            $scope = 'sub';
        } elsif ($self->{dn}) {
            my $dn = $self->{dn};
            $base = $dn;
            $filter = "(objectclass=*)";
            $scope = 'base';
        } else {
            return undef;
        }

        my $attrs = {
            base   => $base,
            filter => $filter,
            scope  => $scope,
            attrs  => ['*', 'objectGUID', 'unicodePwd', 'supplementalCredentials'],
        };

        $result = $self->_ldap->search($attrs);
        return undef unless ($result);

        if ($result->count() > 1) {
            throw EBox::Exceptions::Internal(
                __x('Found {count} results for, expected only one.',
                    count => $result->count()));
        }

        $self->{entry} = $result->entry(0);
    }

    return $self->{entry};
}

# Method: _ldap
#
#   Returns the LDAP object
#
#   Override EBox::Users::LdapObject::_ldap
#
sub _ldap
{
    my ($class) = @_;

    return $class->_ldapMod()->ldb();
}

# Method _ldapMod
#
#   Return the Module implementation that calls this method (Either users or samba).
#
# Override:
#   EBox::Users::LdapObject::_ldapMod
#
sub _ldapMod
{
    my ($class) = @_;

    return $class->_sambaMod();
}

sub _sambaMod
{
    if (not $_sambaMod) {
        $_sambaMod = EBox::Global->modInstance('samba')
    }
    return $_sambaMod;
}

sub _guidToString
{
    my ($self, $guid) = @_;

    return sprintf "%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X",
           unpack("I", $guid),
           unpack("S", substr($guid, 4, 2)),
           unpack("S", substr($guid, 6, 2)),
           unpack("C", substr($guid, 8, 1)),
           unpack("C", substr($guid, 9, 1)),
           unpack("C", substr($guid, 10, 1)),
           unpack("C", substr($guid, 11, 1)),
           unpack("C", substr($guid, 12, 1)),
           unpack("C", substr($guid, 13, 1)),
           unpack("C", substr($guid, 14, 1)),
           unpack("C", substr($guid, 15, 1));
}

sub _stringToGuid
{
    my ($self, $guidString) = @_;

    return undef
        unless $guidString =~ /([0-9,a-z]{8})-([0-9,a-z]{4})-([0-9,a-z]{4})-([0-9,a-z]{2})([0-9,a-z]{2})-([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})([0-9,a-z]{2})/i;

    return pack("I", hex $1) . pack("S", hex $2) . pack("S", hex $3) .
           pack("C", hex $4) . pack("C", hex $5) . pack("C", hex $6) .
           pack("C", hex $7) . pack("C", hex $8) . pack("C", hex $9) .
           pack("C", hex $10) . pack("C", hex $11);
}

sub setCritical
{
    my ($self, $critical, $lazy) = @_;

    if ($critical) {
        $self->set('isCriticalSystemObject', 'TRUE', 1);
    } else {
        $self->delete('isCriticalSystemObject', 1);
    }

    my $relaxOidControl = Net::LDAP::Control->new(
        type => '1.3.6.1.4.1.4203.666.5.12',
        critical => 0 );
    $self->save($relaxOidControl) unless $lazy;
}

sub isInAdvancedViewOnly
{
    my ($self) = @_;

    my $value = $self->get('showInAdvancedViewOnly');
    if ($value and $value eq "TRUE") {
        return 1;
    } else {
        return 0;
    }
}

sub setInAdvancedViewOnly
{
    my ($self, $enable, $lazy) = @_;

    if ($enable) {
        $self->set('showInAdvancedViewOnly', 'TRUE', 1);
    } else {
        $self->delete('showInAdvancedViewOnly', 1);
    }
    my $relaxOidControl = Net::LDAP::Control->new(
        type => '1.3.6.1.4.1.4203.666.5.12',
        critical => 0 );
    $self->save($relaxOidControl) unless $lazy;
}

# Method: _linkWithUsersEntry
#
#   Stores a link to this object into the given Entry.
#
sub _linkWithUsersEntry
{
    my ($self, $entry) = @_;

    unless ($entry and $entry->isa('Net::LDAP::Entry')) {
        throw EBox::Exceptions::Internal("Invalid entry argument. It's not a Net::LDAP::Entry.");
    }

    my @attributes = ();
    unless (grep { $_ eq 'zentyalSambaLink' } @{[$entry->get_value('objectClass')]}) {
        push (@attributes, objectClass => 'zentyalSambaLink');
    }
    push (@attributes, msdsObjectGUID => $self->objectGUID());
    $entry->add(@attributes);
}

# Method: _linkWithUsersObject
#
#   Stores a link to this object into the given OpenLDAP object.
#
sub _linkWithUsersObject
{
    my ($self, $ldapObject) = @_;

    unless ($ldapObject and $ldapObject->isa('EBox::Users::LdapObject')) {
        throw EBox::Exceptions::Internal("Invalid ldapObject argument. It's not an EBox::Users::LdapObject.");
    }

    unless (grep { $_ eq 'zentyalSambaLink' } @{[$ldapObject->_entry()->get_value('objectClass')]}) {
        $ldapObject->add('objectClass', 'zentyalSambaLink', 1);
    }
    $ldapObject->set('msdsObjectGUID', $self->objectGUID(), 1);
    $ldapObject->setIgnoredModules(['samba']);
    $ldapObject->save();
}

1;
