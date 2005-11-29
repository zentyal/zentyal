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

package EBox::FirewallObserver;

use strict;
use warnings;

use EBox::Gettext;

sub new 
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: firewallHelper 
#
#       All modules using any of the functions in FirewallHelper.pm 
#       should override this method to return the implementation
#       of that interface.
#
# Returns:
#
#       An object implementing EBox::FirewallHelper
sub firewallHelper
{
	return undef;
}

# Method: usesPort 
#
#	This method is used by the firewall to find out if a given port
#	is available or not. So if your module implements the 
#	EBox::FirewallHelper to allow some ports for the service it manages,
#	you must implement this method to inform about this when requested.
#	This means you should check if the requested port is used by your
#	service.
#	
# Parameters:
#
#   	protocol - protocol (tcp|udp)
#	port - port numer
#	iface - interface
#
# Returns:
#
#	boolean - if the given port is used
sub usesPort # (protocol, port, iface)
{
	return undef;
}

1;
