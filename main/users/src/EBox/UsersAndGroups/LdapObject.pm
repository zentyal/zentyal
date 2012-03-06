#!/usr/bin/perl -w

# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::UsersAndGroups::LdapObject;

use strict;
use warnings;

use EBox::Config;
use EBox::Global;
use EBox::UsersAndGroups;
use EBox::Gettext;

use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use Perl6::Junction qw(any);

# Method: new
#
#   Instance an object readed from LDAP.
#
#   Parameters:
#
#      dn - Full dn for the user
#  or
#      entry - Net::LDAP entry for the user
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless($self, $class);

    unless ( $params{entry} or $params{dn} ) {
        throw EBox::Exceptions::MissingArgument('dn');
    }

    if ( $params{entry} ) {
        $self->{entry} = $params{entry};
        $self->{dn} = $params{entry}->dn();
    }
    else {
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

    my ($filter, $basedn) = split(/,/, $self->{dn}, 2);
    my %attrs = (
        base => $basedn,
        filter => $filter,
        scope => 'one',
    );

    my $result = $self->_ldap->search(\%attrs);
    return ($result->count() > 0);
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

    return $self->_entry->get_value($attr);
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
#   Deletes an attribute from the object if given
#
#   Parameters (for attribute deletion):
#
#       attribute - Attribute name to read
#       lazy      - Do not update the entry in LDAP
#
sub delete
{
    my ($self, $attr, $lazy) = @_;

    if ($attr eq any $self->_entry->attributes) {
        $self->_entry->delete($attr);
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
#   Parameters:
#
#       attribute - Attribute name
#       value(s)   - Value(s) to remove (value or array ref to values)
#       lazy      - Do not update the entry in LDAP
#
sub remove
{
    my ($self, $attr, $value, $lazy) = @_;

    # Delete attribute only if it exists
    if ($attr eq any $self->_entry->attributes) {
        if(ref($value) ne 'ARRAY') {
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
    my $result = $self->_entry->update($self->_ldap->{ldap});

    if ($result->is_error()) {
        throw EBox::Exceptions::External(__('There was an error updating LDAP: ') . $result->error());
    }
}


# Method: dn
#
#   Return DN for this object
#
sub dn
{
    my ($self) = @_;

    return $self->{dn};
}


# Method: baseDn
#
#   Return base DN for this object
#
sub baseDn
{
    my ($self) = @_;

    my ($trash, $basedn) = split(/,/, $self->{dn}, 2);
    return $basedn;
}


# Return Net::LDAP::Entry entry for the user
sub _entry
{
    my ($self) = @_;

    unless ($self->{entry})
    {
        my %attrs = (
            base => $self->{dn},
            filter => 'objectclass=*',
            scope => 'base',
        );

        my $result = $self->_ldap->search(\%attrs);
        $self->{entry} = $result->entry(0);
    }

    return $self->{entry};
}


sub _ldap
{
    my ($self) = @_;

    return EBox::Global->modInstance('users')->ldap();
}


# Method: to_ldif
#
#   Returns a string containing the LDAP entry as LDIF
#
sub as_ldif
{
    my ($self) = @_;

    return $self->_entry->ldif(change => 0);
}

1;
