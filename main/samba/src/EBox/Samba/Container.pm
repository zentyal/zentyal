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

# Class: EBox::Samba::Container
#
#   container, stored in LDB
#

package EBox::Samba::Container;
use base 'EBox::Samba::LdbObject';

use EBox;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::External;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Global;
use EBox::Users::OU;

use TryCatch::Lite;

# Method: mainObjectClass
#
sub mainObjectClass
{
    return 'container';
}

# Method: isContainer
#
#   Return that this Container can hold other objects.
#
sub isContainer
{
    return 1;
}

# Method: name
#
#   Return the name of this container.
#
sub name
{
    my ($self) = @_;

    return $self->get('cn');
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
        my $ou = EBox::Users::OU->create(name => scalar($name), parent => $parent, ignoreMods  => ['samba']);
        $self->_linkWithUsersObject($ou);
    } catch (EBox::Exceptions::DataExists $e) {
        EBox::debug("OU $name already in $parentDN on OpenLDAP database");
    } catch {
        my $error = shift;
        EBox::error("Error loading OU '$name' in '$parentDN': $error");
    }
}

sub updateZentyal
{
    my ($self) = @_;

    my $dn = $self->dn();
    EBox::warn("updateZentyal called in Container $dn. No implemented editables changes in Containers");
}

sub set
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Container objects cannot be modified');
}

sub delete
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Container objects cannot be modified');
}

sub save
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Container objects cannot be modified');
}

sub deleteObject
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Container objects cannot be modified');
}

1;
