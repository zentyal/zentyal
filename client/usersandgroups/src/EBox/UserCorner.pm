# Copyright (C) 2009  eBox Technologies S.L.
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

package EBox::UserCorner;

use EBox::Config;

use strict;
use warnings;

# Method: usersessiondir
#
#      Get the path where user Web session identifiers are stored
#
# Returns:
#
#      String - the path to that directory
sub usersessiondir
{
    return EBox::Config->var() . 'lib/ebox-usercorner/sids/';
}

1;
