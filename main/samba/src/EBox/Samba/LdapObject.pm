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

package EBox::Samba::LdapObject;

use EBox::Global;
use EBox::Gettext;

use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;

use Data::Dumper;
use Net::LDAP::LDIF;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR LDAP_CONTROL_PAGED LDAP_SUCCESS);
use Net::LDAP::Control::Paged;
use Net::LDAP::Control::Relax;

use Perl6::Junction qw(any);
use TryCatch;

my $_usersMod; # cached users module

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

    unless ($params{entry} or $params{dn}  or
            $params{ldif} or $params{objectGUID}) {
        throw EBox::Exceptions::MissingArgument('entry|dn|ldif|objectGUID');
    }

    my $self = {};
    bless ($self, $class);

    if ($params{entry}) {
        $self->{entry} = $params{entry};
    } elsif ($params{ldif}) {
        my $ldif = Net::LDAP::LDIF->new($params{ldif}, "r");
        $self->{entry} = $ldif->read_entry();
    } elsif ($params{dn}) {
        $self->{dn} = $params{dn};
    } elsif ($params{objectGUID}) {
        $self->{objectGUID} = $params{objectGUID};
    }

    return $self;
}

# Method: dn
#
#   Return DN for this object
#
sub dn
{
    my ($self) = @_;

    my $entry = $self->_entry();
    unless ($entry) {
        my $message = "Got an unexisting LDAP Object!";
        if (defined $self->{dn}) {
            $message .= " (" . $self->{dn} . ")";
        }
        throw EBox::Exceptions::Internal($message);
    }

    my $dn = $entry->dn();
    utf8::decode($dn);
    return $dn;
}

# Method: baseDn
#
#   Return base DN for this object
#
sub baseDn
{
    my ($self, $dn) = @_;
    if (not $dn and ref $self) {
        $dn = $self->dn();
    } elsif (not $dn) {
        throw EBox::Exceptions::MissingArgument("Called as class method and no DN supplied");
    }

    return $dn if ($self->_ldap->dn() eq $dn);

    my ($trash, $basedn) = split(/,/, $dn, 2);
    return $basedn;
}

# Method: exists
#
#   Returns 1 if the object exist, 0 if not
#
sub exists
{
    my ($self) = @_;

    # User exists if we already have its entry
    return 1 if ($self->{entry});

    $self->{entry} = $self->_entry();

    return (defined $self->{entry});
}

# Method: get
#
#   Read an user attribute
#
#   Parameters:
#
#       attribute - Attribute name to read
#
sub get
{
    my ($self, $attr) = @_;

    my $entry = $self->_entry();
    unless (defined $entry) {
        my $dn = $self->{dn} ? $self->{dn} : "Unknown";
        my $msg = "get method called but entry does not exists ($dn)";
        throw EBox::Exceptions::Internal($msg);
    }

    if (wantarray()) {
        my @value = $entry->get_value($attr);
        foreach my $el (@value) {
            utf8::decode($el);
        }
        return @value;
    } else {
        my $value = $entry->get_value($attr);
        utf8::decode($value) if defined ($value);
        return $value;
    }
}

# Method: hasValue
#
#   Check if a value is defined on a multi-value attribute
#
#   Parameters:
#
#       attribute - Attribute name to read
#       value     - Value to check for existence
#
sub hasValue
{
    my ($self, $attr, $value) = @_;

    foreach my $val ($self->get($attr)) {
        return 1 if ($val eq $value);
    }

    return 0;
}

sub hasObjectClass
{
    my ($self, $objectClass) = @_;
    $objectClass = lc $objectClass;
    foreach my $oc ($self->get('objectClass')) {
        return 1 if ((lc $oc) eq $objectClass);
    }
    return 0;
}

# Method: set
#
#   Set an user attribute.
#
#   Parameters:
#
#       attribute - Attribute name to read
#       value     - Value to set (scalar or array ref)
#       lazy      - Do not update the entry in LDAP
#
sub set
{
    my ($self, $attr, $value, $lazy) = @_;
    $self->_entry->replace($attr => $value);
    $self->save() unless $lazy;
}

# Method: add
#
#   Adds a value to an attribute without removing previous ones (if any)
#
#   Parameters:
#
#       attribute - Attribute name to read
#       value     - Value to set (scalar or array ref)
#       lazy      - Do not update the entry in LDAP
#
sub add
{
    my ($self, $attr, $value, $lazy) = @_;

    $self->_entry->add($attr => $value);
    $self->save() unless $lazy;
}

# Method: delete
#
#   Delete all values from an attribute
#
#   Parameters (for attribute deletion):
#
#       attribute - Attribute name to remove
#       lazy      - Do not update the entry in LDAP
#
sub delete
{
    my ($self, $attr, $lazy) = @_;
    $self->deleteValues($attr, [], $lazy);
}

# Method: deleteValues
#
#   Deletes values from an object if they exists
#
#   Parameters (for attribute deletion):
#
#       attribute - Attribute name to read
#       values    - reference to the list of values to delete.
#                   Empty list means all attributes
#       lazy      - Do not update the entry in LDAP
#
sub deleteValues
{
    my ($self, $attr, $values, $lazy) = @_;

    if ($attr eq any $self->_entry->attributes) {
        $self->_entry->delete($attr, $values);
        $self->save() unless $lazy;
    }
}

# Method: remove
#
#   Remove a value from the given attribute, or the whole
#   attribute if no values left
#
#   If an array ref is received as value, all the values will be
#   deleted at the same time
#
# Parameters:
#
#   attribute - Attribute name
#   value(s)  - Value(s) to remove (value or array ref to values)
#   lazy      - Do not update the entry in LDAP
#
sub remove
{
    my ($self, $attr, $value, $lazy) = @_;

    # Delete attribute only if it exists
    if ($attr eq any $self->_entry->attributes) {
        if (ref ($value) ne 'ARRAY') {
            $value = [ $value ];
        }

        $self->_entry->delete($attr, $value);
        $self->save() unless $lazy;
    }
}

# Method: setIgnoredModules
#
#   Set the modules that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining module names
#
sub setIgnoredModules
{
    my ($self, $mods) = @_;
    $self->{ignoreMods} = $mods;
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
#   Whether the object can be deleted or not.
#
# Return
#
#   Boolean - Whether the object can be deleted or not.
#
sub checkObjectErasability
{
    my ($self) = @_;

    # Refuse to delete critical system objects
    return not $self->isCritical();
}

# Method: deleteObject
#
#   Deletes this object from the LDAP
#
#   Override EBox::Samba::LdapObject::deleteObject
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
        my $obj = new EBox::Samba::LdapObject(entry => $entry);
        $obj->deleteObject();
    }

    $self->_entry->delete();
    $self->save();
}

# Method: save
#
#   Store all pending lazy operations (if any)
#
#   This method is only needed if some operation
#   was used using lazy flag
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

# Method: entryOpChangesInUpdate
#
#  string with the pending changes in a LDAP entry. This string is intended to
#  be used only for human consumption
#
#  Warning:
#   a entry with a failed update preserves the failed changes. This is
#   not documented in Net::LDAP so it could change in the future
#
sub entryOpChangesInUpdate
{
    my ($self, $entry) = @_;
    local $Data::Dumper::Terse = 1;
    my @changes = $entry->changes();
    my $args = $entry->changetype() . ' ' . Dumper(\@changes);
    return $args;
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the object
#
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

# Method: clearCache
#
#   Clear cached Net::LDAP::Entry to force reload on next call
#
sub clearCache
{
    my ($self) = @_;
    if (not $self->{dn}) {
        $self->{dn} = $self->{entry}->dn();
    }

    $self->{entry} = undef;
}

# Class method

# Method: _ldap
#
#   Returns the LDAP object
#
#   Override EBox::Samba::LdapObject::_ldap
#
sub _ldap
{
    my ($class) = @_;

    return $class->_ldapMod()->ldap();
}

# Method _ldapMod
#
#   Return the Module implementation that calls this method (Either users or samba).
#
# Override:
#   EBox::Samba::LdapObject::_ldapMod
#
sub _ldapMod
{
    my ($class) = @_;

    return $class->_usersMod();
}

sub _usersMod
{
    if (not $_usersMod) {
        $_usersMod = EBox::Global->modInstance('samba')
    }
    return $_usersMod;
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

# Method: isCritical
#
#   Whether this object is a critical one or not.
#
# Return:
#
#   Boolean - Whether it's a critical object or not.
#
sub isCritical
{
    my ($self) = @_;

    my $isCritical = $self->get('isCriticalSystemObject');
    return ($isCritical and (lc ($isCritical) eq 'true'));
}

# Method: setCritical
#
#   Tags / untags the object as a critical system object.
#   This method doesn't support the lazy flag because it requires to relax restrictions to apply this change.
#
sub setCritical
{
    my ($self, $critical) = @_;

    if ($critical) {
        $self->set('isCriticalSystemObject', 'TRUE', 1);
    } else {
        $self->delete('isCriticalSystemObject', 1);
    }

    my $relaxOidControl = new Net::LDAP::Control::Relax();
    # SAMBA requires the critical flag set to 0 to be able to get the Relax control working, however,
    # Net::LDAP::Control::Relax forces it always to 1 so we need to force it back to 0.
    $relaxOidControl->{critical} = 0;
    $self->save($relaxOidControl);
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

    my $relaxOidControl = new Net::LDAP::Control::Relax();
    # SAMBA requires the critical flag set to 0 to be able to get the Relax control working, however,
    # Net::LDAP::Control::Relax forces it always to 1 so we need to force it back to 0.
    $relaxOidControl->{critical} = 0;
    $self->save($relaxOidControl) unless $lazy;
}

# Method baseName
#
#   Return a string representing the object's base name. Root node doesn't follow the standard naming schema,
#   thus, it should override this method.
#
#   Throw EBox::Exceptions::Internal if the method is not overrided by the root node implementation.
#
sub baseName
{
    my ($self) = @_;

    my $parent = $self->parent();

    unless ($parent) {
        throw EBox::Exceptions::Internal("Root nodes must override this method: DN: " . $self->dn());
    }

    my $dn = $self->dn();
    my $parentDN = $parent->dn();
    my ($contentDN, $trashDN) = split ($parentDN, $dn);
    my ($trashTag, $baseName) = split ('=', $contentDN, 2);

    return substr($baseName, 0, -1);
}

# Method: as_ldif
#
#   Returns a string containing the LDAP entry as LDIF
#
sub as_ldif
{
    my ($self) = @_;

    return $self->_entry->ldif(change => 0);
}

# Method: isContainer
#
#   Return whether this LdapObject can hold other objects or not.
#
sub isContainer
{
    return undef;
}

# Method: defaultContainer
#
#   Return the default container that would hold this object.
#
sub defaultContainer
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: isInDefaultContainer
#
#   Return whether this object is stored in its default container.
#
sub isInDefaultContainer
{
    my ($self) = @_;

    my $parent = $self->parent();
    my $defaultContainer = $self->defaultContainer();
    return ($parent->dn() eq $defaultContainer->dn());
}

# Method: children
#
#   Return a reference to the list of objects that are children of this node.
#
sub children
{
    my ($self, $childrenObjectClass, $customFilter) = @_;

    return [] unless $self->isContainer();
    my $filter;
    if ($childrenObjectClass) {
        $filter = "(&(!(objectclass=organizationalRole))(objectclass=$childrenObjectClass))";
    } else {
        $filter = '(!(objectclass=organizationalRole))';
    }
    if ($customFilter) {
        $filter = '(&' . $filter . "($customFilter))";
    }

    # All children except for organizationalRole objects which are only used
    # internally. Paged by 500 results
    my $page = Net::LDAP::Control::Paged->new( size => 500 );
    my $attrs = {
        base => $self->dn(),
        filter => $filter,
        scope  => 'one',
        control => [ $page ],
    };

    my $ldapMod = $self->_ldapMod();

    my $cookie;
    my @objects = ();
    while (1) {
        my $result = $self->_ldap->search($attrs);
        if ($result->code() ne LDAP_SUCCESS) {
            last;
        }

        foreach my $entry ($result->entries) {
            my $object = $ldapMod->entryModeledObject($entry);
            push (@objects, $object) if ($object);
        }

        my ($resp) = $result->control( LDAP_CONTROL_PAGED );
        if (not $resp) {
            last;
        }
        $cookie = $resp->cookie;
        if (not $cookie) {
            # finished
            last;
        }

        $page->cookie($cookie);
    }

    if ($cookie) {
        # We had an abnormal exit, so let the server know we do not want any more
        $page->cookie($cookie);
        $page->size(0);
        $self->_ldap->search($attrs)
    }

    # sort by dn (as it is currently the only common attribute, but maybe we can change this)
    # FIXME: Fix the API so all ldapobjects have a valid name method to use here.
    @objects = sort {
        my $aValue = $a->dn();
        my $bValue = $b->dn();
        (lc $aValue cmp lc $bValue) or
        ($aValue cmp $bValue)
    } @objects;

    return \@objects;
}

# Method: parent
#
#   Return the parent of this object or undef if it's the root.
#
#   Throw EBox::Exceptions::Internal on error.
#
sub parent
{
    my ($self) = @_;
    my $dn = $self->dn();
    my $ldapMod = $self->_ldapMod();

    my $defaultNamingContext = $ldapMod->defaultNamingContext();
    return undef if ($dn eq $defaultNamingContext->dn());

    my $parentDn = $self->baseDn($dn);
    my $parent = $ldapMod->objectFromDN($parentDn);

    if ($parent) {
        return $parent;
    } else {
        throw EBox::Exceptions::Internal("The dn '$dn' is not representing a valid parent!");
    }
}

# Method: relativeDN
#
#   Return the dn of this object without the naming Context.
#
sub relativeDN
{
    my ($self) = @_;

    my $ldapMod = $self->_ldapMod();
    return $ldapMod->relativeDN($self->dn());
}

# Method: printableType
#
#   Override in subclasses to return the printable type name.
#   By default returns the class name
sub printableType
{
    my ($self) = @_;
    return ref($self);
}

# Method: checkCN
#
#  Check if the given CN is correct.
#  The default implementation just checks that there is no other object with
#  the same CN in the container
sub checkCN
{
    my ($class, $container, $cn)= @_;
    my @children = @{ $container->children(undef, "cn=$cn") };
    if (@children) {
        my ($sameCN) = @children;
        my $type = $sameCN->printableType();
        throw EBox::Exceptions::External(
            __x("There is already an object of type {type} with CN={cn} in this container",
                type => $type,
                cn => $cn
               )
           );
    }
}

# Method: checkMail
#
#   Helper class to check if a mail address is valid and not in use
sub checkMail
{
    my ($class, $address) = @_;
    EBox::Validate::checkEmailAddress($address, __('Group E-mail'));

    my $global = EBox::Global->getInstance();
    my $mod = $global->modExists('mail') ? $global->modInstance('mail') : $global->modInstance('samba');
    $mod->checkMailNotInUse($address);
}

1;
