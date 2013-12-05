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
#   Organizational Unit, stored in LDB
#

package EBox::Samba::OU;
use base 'EBox::Samba::LdbObject';

use EBox;
use EBox::Gettext;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::LDAP;
use EBox::Global;
use EBox::Users::OU;

use Net::LDAP::Util qw(canonical_dn);
use Net::LDAP::Constant qw(LDAP_LOCAL_ERROR);

use Error qw(:try);

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

sub addToZentyal
{
    my ($self) = @_;
    my $sambaMod = EBox::Global->getInstance(1)->modInstance('samba');

    my $parent = $sambaMod->ldapObjectFromLDBObject($self->parent);
    if (not $parent) {
        my $dn = $self->dn();
        throw EBox::Exceptions::External("Unable to to find the container for '$dn' in OpenLDAP");
    }

    my $name = $self->name();
    my $parentDN = $parent->dn();

    try {
        my $zentyalOU = EBox::Users::OU->create(name => scalar($name), parent => $parent, ignoreMods  => ['samba']);
        $self->_linkWithUsersObject($zentyalOU);
    } catch EBox::Exceptions::DataExists with {
        EBox::debug("OU $name already in $parentDN on OpenLDAP database");
    } otherwise {
        my $error = shift;
        EBox::error("Error loading OU '$name' in '$parentDN': $error");
    };
}

sub updateZentyal
{
    my ($self) = @_;

    my $dn = $self->dn();
    EBox::warn("updateZentyal called in OU $dn. No implemented editables changes in OU ");
}

# Method: create
#
#   Add and return a new Organizational Unit.
#
#   Throw EBox::Exceptions::InvalidData if a non valid character is detected on $name.
#   Throw EBox::Exceptions::InvalidType if $parent is not a valid container.
#
# Parameters:
#
#   args - Named parameters:
#       name   - Organizational Unit name
#       parent - Parent container that will hold this new OU.
#
sub create
{
    my ($class, %args) = @_;

    $args{name} or
        throw EBox::Exceptions::MissingArgument('name');
    $args{parent} or
        throw EBox::Exceptions::MissingArgument('parent');
    $args{parent}->isContainer() or
        throw EBox::Exceptions::InvalidData(data => 'parent', value => $args{parent}->dn());

    my @attr;
    push (@attr, objectClass => ['organizationalUnit']);
    push (@attr, ou => $args{name});

    my $dn = canonical_dn("OU=" . $args{name} . "," . $args{parent}->dn());
    my $res = undef;
    try {
        my $entry = new Net::LDAP::Entry($dn, @attr);
        my $result = $entry->update($class->_ldap->connection());
        if ($result->is_error()) {
            unless ($result->code() == LDAP_LOCAL_ERROR and $result->error() eq 'No attributes to update') {
                throw EBox::Exceptions::LDAP(
                    message => __('Error creating entry:'),
                    result => $result,
                    opArgs => $class->entryOpChangesInUpdate($entry),
                );
            };
        }
        $res = new EBox::Samba::OU(dn => $dn);
    } otherwise {
        my ($error) = @_;

        EBox::error($error);

        if (defined $res and $res->exists()) {
            $res->SUPER::deleteObject(@_);
        }
        $res = undef;
        throw $error;
    };
    return $res;
}

1;
