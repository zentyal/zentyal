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
#
package EBox::Samba::Group::ExternalAD;
use base 'EBox::Samba::Group';

use EBox::Gettext;
use EBox::Exceptions::UnwillingToPerform;


use TryCatch::Lite;

sub new
{
    my ($class, @opts) = @_;

    my $self = $class->SUPER::new(@opts);


    bless ($self, $class);
    return $self;
}

# Method: mainObjectClass
#
# Overrides:
#   EBox::Samba::Groupr::mainObjectClass
#
sub mainObjectClass
{
    return 'group';
}

# Method: defaultContainer
#
#   Return the default container that will hold Group objects.
#
# Overrides:
#   EBox::Samba::Group::defaultContainer
#
sub defaultContainer
{
    my $usersMod = EBox::Global->modInstance('samba');
    return $usersMod->objectFromDN('cn=Users,'.$usersMod->ldap->dn());
}


# Method: name
#
#   Return group name
#
sub name
{
    my ($self) = @_;
    return $self->get('name');
}

# Method: isSystem
#
#   Whether the security group is a system group.
#
# Overides:
#   EBox::Samba::Group::isSystem
#
sub isSystem
{
    my ($self) = @_;

    # XXX look gor more attributes
    return $self->get('isCriticalSystemObject');
}

sub addMember
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Cannot add members to a external AD group')
}

sub removeMember
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'Cannot remove members from a external AD group')
}

sub set
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub add
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub delete
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub deleteValues
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub deleteObjects
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}

sub save
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD group are readonly')
}


1;
