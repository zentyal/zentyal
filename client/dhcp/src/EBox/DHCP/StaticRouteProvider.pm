# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::DHCP::StaticRouteProvider;

use strict;
use warnings;

use EBox::Global;

#  Method: staticRoutes
#
#    The static routes provider must use this method to return the static routes which must be pushed out by the dhcp server
#
#  Returns:
#   the reference to a list with net and routes pairs. The net is provided in CIDR notation and the route is a hash reference with the following fields: network, dnetmask, gatewat
sub staticRoutes
{
  throw EBox::Exceptions::Internal ('staticRoutes not implemented');
}

#  Method: notifyStaticRoutesChange
#
#    This must be called by the static routes providers when their routes change
sub notifyStaticRoutesChange
{
  my $dhcp = EBox::Global->modInstance('dhcp');
  $dhcp->notifyStaticRoutesChange();
}


1;
