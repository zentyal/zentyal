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

# Class: EBox::UsersAndGroups::SyncProvider
#
#    This is an abstract class for user synchronization providers.
#    Each provider can act as master, slave or both.
#
package EBox::UsersAndGroups::SyncProvider;

use strict;
use warnings;


use EBox::Exceptions::NotImplemented;


# Method: userSync
#
#   Return a list of instances implementing EBox::UsersSync::Base
#
# Returns:
#
#   array ref - UserSynchronizer instances for this module
#
sub userSynchronizers
{
    throw EBox::Exceptions::NotImplemented();
}


1;
