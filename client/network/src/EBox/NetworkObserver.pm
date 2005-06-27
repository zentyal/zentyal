# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::NetworkObserver;

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

#
# Method: staticIfaceAddressChanged
#
#	Invoked when the address of an static network interface is going to 
#	be changed, this method receives the old and new addresses and masks 
#	as arguments. Returning a true value means that this 
#	module's configuration would become inconsistent if such a change
#	was made. In that case the network module will not make the change, 
#	but warn the user instead. You should override this method if you need
#	to.
#
# Parameters:
#
#	iface - interface name
#	oldaddr - old address
#	oldmask - old mask
#	newaddr - new address
#	newmask - new mask
#
# Returns:
#
#	boolean - true if module's configuration becomes inconsistent, otherwise
#	fasle
sub staticIfaceAddressChanged # (iface, oldaddr, oldmask, newaddr, newmask)
{
        return undef;
}

#
# Method: ifaceMethodChanged
#
# 	Invoked when the configuration method for a network interface is 
#	going to change. Both the old and new methods are passed as 
#	arguments to this function. They are strings: static, dhcp,
#	trunk or notset. As with the previous function, a return value of 
#	true will prevent the change from being made. You should override this
#	method if you need to.
#
#   Parameteres:
#
#	iface - interface name
#	oldmethod - old method
#	newmethod - newmethod
#
# Returns:
#
#	boolean - true if module's configuration becomes inconsistent, otherwise
#	fasle
sub ifaceMethodChanged # (iface, oldmethod, newmethod)
{
        return undef;
}

#
# Method: vifaceDelete 
#
#	Invoked when a  virtual interface is going to be removed. Its 
#	arguments are the real interface  which it's going to be removed from, 
#	the name of the  interface to remove, its ip address and its netmask. It
#	works the same way: return true if the removal of the virtual 
#	interface is incompatible with your module's current configuration.
#
#   Parameteres:
#
#	iface - interface name
#	viface - virtual interface to be removed
#	newmethod - newmethod
#
# Returns:
#
#	boolean - true if module's configuration becomes inconsistent, otherwise
#	fasle
sub vifaceDelete # (iface, viface)
{
        return undef;
}

#
# Method: vifaceAdded
#
#	Invoked when a new virtual interface is going to be created. Its 
#	arguments are the real interface to which it's going to be added, 
#	the name of the new interface, its ip address and its netmask. It
#	works the same way: return true if the creation of the virtual 
#	interface is incompatible with your module's current configuration.
#
#   Parameteres:
#
#	iface - interface name
#	viface - virtual interface to be removed
#	newmethod - newmethod
#
# Returns:
#
#	boolean - true if module's configuration becomes inconsistent, otherwise
#	fasle
sub vifaceAdded # (iface, viface, address, netmask)
{
        return undef;
}

#
# Method: freeIface
#
#	Invoked when a interface is going to be removed. Its argument 
#	is the name of the real interface. It works exactly 
#	the same way as the three methods above.
#
#   Parameteres:
#
#	iface - interface name
#
# Returns:
#
#	boolean - true if module's configuration becomes inconsistent, otherwise
#	fasle
sub freeIface # (iface)
{
        # default empty implementation. Subclasses should override this as
        # needed.
}

#
# Method: freeViface
#
#	Invoked when a virtual interface is going to be removed. Its arguments 
#	are the names of the real and virtual interfaces. It works exactly 
#	the same way as the three methods above.
#
#   Parameteres:
#
#	iface - interface name
#	viface - virtual interface to be removed
#
# Returns:
#
#	boolean - true if module's configuration becomes inconsistent, otherwise
#	fasle
sub freeViface # (iface, viface)
{
        # default empty implementation. Subclasses should override this as
        # needed.
}

1;
