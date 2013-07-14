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
    my $result = $entry->update($self->_ldap->ldbCon(), control => $control);
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

    unless ($self->{entry}) {
        my $result = undef;
        if (defined $self->{dn}) {
            my $dn = $self->{dn};
            my $attrs = {
                base => $dn,
                filter => "(distinguishedName=$dn)",
                scope => 'base',
                attrs => ['*', 'unicodePwd', 'supplementalCredentials'],
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

# Method: _ldap
#
#   Returns the LDAP object
#
#   Override EBox::Users::LdapObject::_ldap
#
sub _ldap
{
    return __PACKAGE__->_sambaMod()->ldb();
}

sub _sambaMod
{
    if (not $_sambaMod) {
        $_sambaMod = EBox::Global->getInstance(0)->modInstance('samba')
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

sub setViewInAdvancedOnly
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

sub getXidNumberFromRID
{
    my ($self) = @_;

    my $sid = $self->sid();
    my $rid = (split (/-/, $sid))[7];

    return $rid + 50000;
}

# Method: children
#
#   Return a reference to the list of objects that are children of this node.
#
#   Override EBox::Users::LdapObject::children
#
# TODO: Try to share code with parent class...
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
    my $sambaMod = $self->_sambaMod();

    my @objects = ();
    foreach my $entry ($result->entries) {
        my $object = $sambaMod->entryModeledObject($entry);

        push (@objects, $object) if ($object);
    }

    @objects = sort {
        my $aValue = $a->canonicalName();
        my $bValue = $b->canonicalName();
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
#   Override EBox::Users::LdapObject::parent
#
# TODO: Try to share code with parent class...
sub parent
{
    my ($self, $dn) = @_;
    if (not $dn and ref $self) {
        $dn = $self->dn();
    } elsif (not $dn) {
        throw EBox::Exceptions::MissingArgument("Called as class method and no DN supplied");
    }
    my $sambaMod = $self->_sambaMod();

    my $defaultNamingContext = $sambaMod->defaultNamingContext();
    return undef if ($dn eq $defaultNamingContext->dn());

    my $parentDn = $self->baseDn($dn);
    my $parent = $sambaMod->objectFromDN($parentDn);

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
#   Override EBox::Users::LdapObject::relativeDN
#
# TODO: Try to share code with parent class...
sub relativeDN
{
    my ($self) = @_;

    my $sambaMod = $self->_sambaMod();
    return $sambaMod->relativeDN($self->dn());
}

1;
