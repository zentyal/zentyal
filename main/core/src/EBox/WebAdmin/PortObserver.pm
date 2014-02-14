# Copyright (C) 2014 Zentyal S.L.
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

package EBox::WebAdmin::PortObserver;

# Class: EBox::WebAdmin::PortObserver
#
#     Implement this port observer if you want to be notified when the
#     admin port is changed
#

# Method: adminPortChanged
#
#   Invoked after a change in admin port takes place.
#
# Parameters:
#
#   port - Int the new webadmin port
#
sub adminPortChanged
{
    my ($self, $port) = @_;
}

1;
