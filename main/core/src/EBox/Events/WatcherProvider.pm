# Copyright (C) 2012-2012 Zentyal S.L.
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

# Class: EBox::Events::WatcherProvider
#
# This interface needs to be implemented for those modules which add
# custom watchers for the events module

use strict;
use warnings;

package EBox::Events::WatcherProvider;

use EBox::Exceptions::NotImplemented;

# Method: eventWatchers
#
#       This function must return the names of the watcher classes
#       without the "EBox::Event::Watcher" prefix.
#
# Returns:
#
#       array ref - containing the watcher names
#
sub eventWatchers
{
    throw EBox::Exceptions::NotImplemented();
}

1;
