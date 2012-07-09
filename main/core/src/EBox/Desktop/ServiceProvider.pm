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

# Class: EBox::Desktop::ServiceProvider
#
#   This is an abstract class for desktop services providers
#
#   'desktopActions' method should return an array reference containing, for
#   each one of the exposed actions, a name and a reference to this action:
#       'action_name' => \&action
#
package EBox::Desktop::ServiceProvider;

use strict;
use warnings;

# Method: actions
#
#   Return an array ref with the exposed methods
#
# Returns:
#
#   array ref - Containing pairs: action_name => action_ref
#
sub desktopActions
{
    return {};
}

1;
