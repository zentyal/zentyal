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

# Class: EBox::Samba::OU::ExternalAD
#
#   OU retrieved from external AD
#

package EBox::Samba::OU::ExternalAD;
use base 'EBox::Samba::OU';

use EBox::Exceptions::UnwillingToPerform;

# Method: mainObjectClass
#
#  Overrides:
#    EBox::Samba::OU::mainObjectClass
sub mainObjectClass
{
    return 'organizationalUnit';
}

sub set
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD OU cannot be modified');
}

sub delete
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD OU cannot be modified');
}

sub save
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD OU cannot be modified');
}

sub deleteObject
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'External AD OU cannot be modified');
}

1;
