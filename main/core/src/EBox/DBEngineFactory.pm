# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::DBEngineFactory;

use EBox;
use EBox::MyDBEngine;

# FIXME: MyDBEngine should be a singleton directly, this factory is
#        useless and was filling the logs with a logs of messages
#        prior to its conversion to singleton, but at the moment
#        we are not changing it to not break the interface with the
#        rest of the code.

my $_instance = undef;

# Function: DBEngine
#
# Returns:
#   a instance of the DBEngine to be used
#
#
sub DBEngine
{
    unless (defined($_instance)) {
        $_instance = new EBox::MyDBEngine;
    }

    return $_instance;
}

# Function: disconnect
#
#   disconenct and destroy the active dbengine
#   A new call to DBngine will create a new one
sub disconnect
{
    if ($_instance) {
        # destroying the object forces discconection
        $_instance = undef;
    }
}

1;
