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
use EBox::Exceptions::NotImplemented;

use Data::Dumper;
use TryCatch::Lite;
use Net::LDAP::LDIF;
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR LDAP_CONTROL_PAGED LDAP_SUCCESS);
use Net::LDAP::Control::Paged;

use Perl6::Junction qw(any);

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
    my ($self) = @_;

    $self->_entry->delete();
    $self->save();
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

# Method: setIgnoredSlaves
#
#   Set the slaves that should not be notified of the changes
#   made to this object
#
# Parameters:
#
#   mods - Array reference cotaining slave names
#
sub setIgnoredSlaves
{
    my ($self, $slaves) = @_;
    $self->{ignoreSlaves} = $slaves;
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
    my $entry = $self->_entry;

    my $result = $entry->update($self->_ldap->{ldap});
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

# Method: _entry
#
#   Return Net::LDAP::Entry entry for the user
#
sub _entry
{
    my ($self) = @_;

    if ($self->{entry} and (not $self->{entry}->exists('entryUUID'))) {
        $self->{dn} = $self->{entry}->dn();
        delete $self->{entry};
    }

    unless ($self->{entry}) {
        my $result = undef;
        if ($self->{dn}) {
            my $dn = $self->{dn};
            my $base = $dn;
            my $filter = "(objectclass=*)";
            my $scope = 'base';

            my $attrs = {
                base => $base,
                filter => $filter,
                scope => $scope,
                attrs => ['*', 'entryUUID'],
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

# Class method
sub _ldap
{
    my ($class) = @_;
    return $class->_ldapMod()->ldap();
}

# Method _ldapMod
#
#   Return the Module implementation that calls this method (Either users or samba).
#
sub _ldapMod
{
    my ($class) = @_;

    return $class->_usersMod();

}

# Method _usersMod
sub _usersMod
{
    if (not $_usersMod) {
        $_usersMod = EBox::Global->modInstance('users');
    }

    return $_usersMod;
}

# Method canonicalName
#
#   Return a string representing the object's canonical name.
#
#   Parameters:
#
#       excludeRoot - Whether the LDAP root's canonical name should be excluded
#
sub canonicalName
{
    my ($self, $excludeRoot) = @_;

    my $parent = $self->parent();

    my $canonicalName = '';
    if ($parent) {
        unless ($excludeRoot and (not $parent->parent())) {
            $canonicalName = $parent->canonicalName($excludeRoot) . '/';
        }
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
            __x("There exists already a object of type {type} with CN={cn} in this container",
                type => $type,
                cn => $cn
               )
           );
    }
}

1;
