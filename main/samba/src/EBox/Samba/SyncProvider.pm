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

# Class: EBox::Samba::SyncProvider
#
#   This is an abstract class for user synchronization providers.
#   Each provider can act as master, slave or both.
#
#   "slaves" method should return a list of slaves for this provider
#
#   To act as master, common methods (create, modify and delete) should
#   be used on users and group objects.
#
use strict;
use warnings;

package EBox::Samba::SyncProvider;

use EBox::Exceptions::NotImplemented;

# Method: slaves
#
#   Return a list of instances implementing EBox::UsersSync::Base
#
# Returns:
#
#   array ref - UserSynchronizer instances for this module
#
sub slaves
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: allowUserChanges
#
#   Return 1 if the user should be allowed to make changes
#   to the users. 0 if not (usually slave machines)
#
sub allowUserChanges
{
    throw EBox::Exceptions::NotImplemented();
}

1;
