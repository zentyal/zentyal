#!/usr/bin/perl -w

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

package EBox::Users::LdapObject;

use EBox::Config;
use EBox::Global;
use EBox::Users;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::LDAP;

use Data::Dumper;
use Net::LDAP::LDIF;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use Perl6::Junction qw(any);

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
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless ($params{entry} or $params{dn} or
            $params{ldif}) {
        throw EBox::Exceptions::MissingArgument('entry|dn|ldif');
    }

    if ($params{entry}) {
        $self->{entry} = $params{entry};
    } elsif ($params{ldif}) {
        my $ldif = Net::LDAP::LDIF->new($params{ldif}, "r");
        $self->{entry} = $ldif->read_entry();
    } elsif ($params{dn}) {
        $self->{dn} = $params{dn};
    }

    return $self;
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

    if (wantarray()) {
        my @value = $self->_entry->get_value($attr);
        foreach my $el (@value) {
            utf8::decode($el);
        }
        return @value;
    } else {
        my $value = $self->_entry->get_value($attr);
        utf8::decode($value);
        return $value;
    }
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

# Method: deleteObject
#
#   Deletes this object from the LDAP
#
sub deleteObject
{
    my ($self, $attr, $lazy) = @_;

    $self->_entry->delete();
    $self->save();
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

# Method: save
#
#   Store all pending lazy operations (if any)
#
#   This method is only needed if some operation
#   was used using lazy flag
#
sub save
{
    my ($self) = @_;
    my $entry= $self->_entry;

    my $result = $entry->update($self->_ldap->{ldap});
    if ($result->is_error()) {
        unless ($result->code == LDAP_LOCAL_ERROR and $result->error eq 'No attributes to update') {
            throw EBox::Exceptions::LDAP( message => __('There was an error updating LDAP:'),
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

# Method: dn
#
#   Return DN for this object
#
sub dn
{
    my ($self) = @_;

    return $self->_entry()->dn();
}

# Method: baseDn
#
#   Return base DN for this object
#
sub baseDn
{
    my ($self) = @_;

    my $dn = $self->dn();
    return $dn if ($self->_ldap->dn() eq $dn);

    my ($trash, $basedn) = split(/,/, $dn, 2);
    return $basedn;
}

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the user
#
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry}) {
        my $result = undef;
        if (defined $self->{dn}) {
            my $dn = $self->{dn};
            my $filter = undef;
            my $baseDN = undef;
            my $scope = undef;
            if ($self->_ldap->dn() eq $dn) {
                $filter = '(objectclass=*)';
                $baseDN = $dn;
                $scope = 'base';
            } else {
                $scope = 'one';
                ($filter, $baseDN) = split(/,/, $self->{dn}, 2);
                if (not $baseDN) {
                    throw EBox::Exceptions::Internal("DN too short: " . $self->{dn});
                }
            }

            my $attrs = {
                base => $baseDN,
                filter => $filter,
                scope => $scope,
            };
            $result = $self->_ldap->search($attrs);
        }
        return undef unless defined $result;

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

    $self->{entry} = undef;
}

sub _ldap
{
    return EBox::Global->modInstance('users')->ldap();
}

sub _usersMod
{
    my ($self) = @_;

    $self->{usersMod} = EBox::Global->modInstance('users') unless (defined $self->{usersMod} and $self->{usersMod});

    return $self->{usersMod}
}

# Method canonicalName
#
#   Return a string representing the object's canonical name.
#
sub canonicalName
{
    my ($self) = @_;

    my $parent = $self->parent();

    my $canonicalName = '';
    if ($parent) {
        $canonicalName = $parent->canonicalName() . '/';
    }

    $canonicalName .= $self->baseName();

    return $canonicalName;
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

    throw EBox::Exceptions::Internal("Root nodes must override this method: DN: " . $self->dn()) unless ($parent);

    my $dn = $self->dn();
    my $parentDN = $parent->dn();
    my ($contentDN, $trashDN) = split ($parentDN, $dn);
    my ($trashTag, $baseName) = split ('=', $contentDN, 2);

    return $baseName;
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
    my ($self) = @_;

    return [] unless $self->isContainer();

    # All children except for organizationalRole objects which are only used internally
    my $attrs = {
        base   => $self->dn(),
        filter => '(!(objectclass=organizationalRole))',
        scope  => 'one',
    };

    my $result = $self->_ldap->search($attrs);
    my $usersMod = $self->_usersMod();

    my @objects = ();
    foreach my $entry ($result->entries) {
        my $object = $usersMod->entryModeledObject($entry);

        push (@objects, $object) if ($object);
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

    my $usersMod = $self->_usersMod();
    my $defaultNamingContext = $usersMod->defaultNamingContext();

    my $dn = $self->dn();
    return undef if ($dn eq $defaultNamingContext->dn());

    my $attrs = {
        base   => $self->baseDn(),
        filter => '(objectclass=*)',
        scope  => 'base',
    };

    my $result = $self->_ldap->search($attrs);
    throw EBox::Exceptions::Internal($result->error) if ($result->code);
    throw EBox::Exceptions::Internal("Found more than one parent for DN: " . $dn) if ($result->count() > 1);
    throw EBox::Exceptions::Internal("Unable to find the parent for DN: " . $dn) if ($result->count() < 1);

    return $usersMod->entryModeledObject($result->entry(0));
}

1;
