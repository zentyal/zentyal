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

# Class: EBox::Samba::BuiltinDomain
#
#   builtinDomain, stored in LDB
#

package EBox::Samba::BuiltinDomain;
use base 'EBox::Samba::LdapObject';

use EBox;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::External;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Global;
use EBox::Samba::OU;

use TryCatch;

# Method: mainObjectClass
#
sub mainObjectClass
{
    return 'builtinDomain';
}

# Method: isContainer
#
#   Return that this BuiltinDomain can hold other objects.
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

sub set
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'BuiltinDomain objects cannot be modified');
}

sub delete
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'BuiltinDomain objects cannot be modified');
}

sub save
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'BuiltinDomain objects cannot be modified');
}

sub deleteObject
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'BuiltinDomain objects cannot be modified');
}

1;
