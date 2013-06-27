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

use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Users::OU;

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

sub relativeDn
{
    my ($self, $dnBase) = @_;
    my $dn = $self->dn();
    if (not $dn =~ s/,$dnBase$//) {
        throw EBox::Exceptions::Internal("$dn is not contained in $dnBase");
    }

    return $dn;
}



sub addToZentyal
{
    my ($self, $rDn) = @_;
    my $users = EBox::Global->getInstance(1)->modInstance('users');

    my ($name, $parentDn) = split ',', $rDn, 2;
    my $parent;
    if ($parentDn) {
        $parentDn .= ',' . $users->ldap()->dn();
        $parent = $users->objectFromDN($parentDn);
    } else {
        $parent = $users->defaultNamingContext();
    }

    my $ou = EBox::Users::OU->create($name, $parent);
    $ou->exists() or
        throw EBox::Exceptions::Internal("Error addding samba OU '$name' to Zentyal");
}

sub updateZentyal
{
    my ($self, $rDn) = @_;
    EBox::warn("updateZentyal called in OU $rDn. No implemented editables changes in OU ");
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
#   name   - Organizational Unit name
#   parent - Parent container that will hold this new OU.
#
sub create
{
    my ($self, $name, $parent) = @_;

    $parent->isContainer() or
        throw EBox::Exceptions::InvalidData(data => 'parent', value => $parent->dn());

    my $args = {
        attr => [
            'objectclass' => ['organizationalUnit'],
            'ou' => $name,
        ]
    };

    my $dn = "ou=$name," . $parent->dn();
    my $result = $self->_ldap->add($dn, $args);
    my $res = EBox::Samba::OU->new(dn => $dn);
    return $res;
}

1;
