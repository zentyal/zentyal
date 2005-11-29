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

package EBox::NetWrappers;

use strict;
use warnings;

use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::DataNotFound;

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw();
	%EXPORT_TAGS  = (all => [qw{    list_ifaces iface_exists iface_is_up 
					iface_netmask iface_addresses 
					iface_mac_address list_routes
					route_is_up
					ip_network ip_broadcast
					bits_from_mask mask_from_bits
				} ],
			);
	@EXPORT_OK = qw();
	Exporter::export_ok_tags('all');
	$VERSION = EBox::Config::version;
}

# Method: iface_exists 
#
#	Checks if a given interface exists in the system using *ifconfig*	 
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       True if exits, otherwise undef
#
sub iface_exists #(iface)
{
        my $iface = shift;
	defined($iface) or return undef;
        return (system("/sbin/ifconfig $iface > /dev/null 2>&1") == 0);
}

#
# Method: list_ifaces 
#
#   	Returns a list of all real interfaces in the machine via */proc/net/dev*
#
# Returns:
#
#      	An array containg the interfaces 
#
sub list_ifaces
{
        my @devices = `cat /proc/net/dev 2>/dev/null | sed 's/^ *//' | cut -d " " -f 1 | grep : | sed 's/:.*//'` ;
        chomp(@devices);
        return @devices;
}

#
# Method: iface_is_up
#
#	Checks if a given interface is up.
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       True if it's up, undef otherwise
#
# Exceptions:
#
#       DataNotFound - If interface does not exists
#
sub iface_is_up
{
        my $iface = shift;
        unless (iface_exists($iface)) {
                throw EBox::Exceptions::DataNotFound(
						data => __('Interface'),
						value => $iface);
        }
        return (system("/sbin/ifconfig $iface 2>/dev/null | sed 's/^ *//' | cut -d ' ' -f 1 | grep UP > /dev/null") == 0);
}

#
# Method: iface_netmask
#
# 	Returns the netmask for a given interface (dot format)	
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       A string containing the netmask
#
# Exceptions:
#
#       DataNotFound - If interface does not exists
#
sub iface_netmask
{
        my $if = shift;
        unless (iface_exists($if)) {
                throw EBox::Exceptions::DataNotFound(
						data => __('Interface'),
						value => $if);
        }

        my $mask = `/sbin/ifconfig $if 2> /dev/null | sed 's/ /\\n/g' | grep Mask: | sed 's/^.*://'`;
        chomp($mask);
        return $mask;
}

#
# Method: iface_mac_address
#
# 	Returns the mac address for a given interface 
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       A string containing the mac address 
#
# Exceptions:
#
#       DataNotFound - If interface does not exists
#
sub iface_mac_address
{
        my $if = shift;
        unless (iface_exists($if)) {
                throw EBox::Exceptions::DataNotFound(
						data => __('Interface'),
						value => $if);
        }
        my $mac = `/sbin/ifconfig $if 2> /dev/null | grep HWaddr | sed 's/^.*HWaddr //' | sed 's/ *\$//'`;
        chomp($mac);
	defined($mac) or return undef;
	($mac ne '') or return undef;
        return $mac;
}

#
# Method: iface_address
#
# 	Returns the  address for a given interface (dot format)	
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       A string containing the address 
#
# Exceptions:
#
#       DataNotFound - If interface does not exists
#
sub iface_addresses
{
        my $if = shift;
        unless (iface_exists($if)) {
                throw EBox::Exceptions::DataNotFound(
						data => __('Interface'),
						value => $if);
        }
        my @addrs = `/bin/ip address show $if 2> /dev/null | sed 's/^ *//' |    grep '^inet ' | cut -d ' ' -f 2`;
        chomp(@addrs);
        return @addrs;
}

#
# Method: list_routes 
#
#   	Rertuns the list of current routes
#
# Returns:
#
#      	An array containing hash references. Each hash contains a route 
#      	and consists of:
#	
#	network -  network destination
#	router  -  router used to reach the above network
#
sub list_routes
{
        my @array = ();
        my @routes = `/bin/ip route show 2>/dev/null | grep via`;
        chomp(@routes);
        foreach (@routes) {
                my ($net, $via, $router) = split(/ /,$_);
                my $elmnt;
                $elmnt->{router} = $router;
                $elmnt->{network} = $net;
                push(@array, $elmnt);
        }
        return @array;
}

#
# Method: route_is_up 
#
#	Checks if a given route is already up.
#
# Parameters:
#
#       network - network destination
#	router -  router used to reach the network
#
# Returns:
#
#       True if it's up, undef otherwise
#
sub route_is_up # (network, router)
{
        my ($network, $router) = @_;
        my @routes = list_routes();
        foreach (@routes) {
                if (($_->{router} eq $router) and
                    ($_->{network} eq $network)) {
                    return 1;
                }
        }
        return undef;
}

#
# Method: ip_network
#
# 	Returns the network for an address and netmask	
#
# Parameters:
#
#       address - IPv4 address
#	netmask - network mask for the above ip
#
# Returns:
#
#       The network address
#
sub ip_network # (address, netmask)
{
	my ($address, $netmask) = @_;
	my $net_bits = pack("CCCC", split(/\./, $address));
	my $mask_bits = pack("CCCC", split(/\./, $netmask));
	return join(".", unpack("CCCC", $net_bits & $mask_bits));
}

#
# Method: ip_broadcast
#
# 	Returns the broadcast address  for an address and netmask	
#
# Parameters:
#
#       address - IPv4 address
#	netmask - network mask for the above ip
#
# Returns:
#
#       The broadcast address
#
sub ip_broadcast # (address, netmask)
{
	my ($address, $netmask) = @_;
	my $net_bits = pack("CCCC", split(/\./, $address));
	my $mask_bits = pack("CCCC", split(/\./, $netmask));
	return join(".", unpack("CCCC", $net_bits | (~$mask_bits)));
}

#
# Method: bits_from_mask 
#
# 	Given a network mask it returns it in binary format 	
#
# Parameters:
#
#	netmask - network mask 
#
# Returns:
#
#      Network mask in binary format 
#
sub bits_from_mask # (netmask)
{
	my $netmask = shift;
	return unpack("%B*", pack("CCCC", split(/\./, $netmask)));
}

#
# Method: mask_from_bits 
#
# 	Given a network mask in binary format it returns it in decimal dot notation	
#
# Parameters:
#
#	netmask - network mask 
#
# Returns:
#
#      Network mask in decimal dot notation
#
sub mask_from_bits # (bits)
{
	my $bits = shift;
	unless($bits >= 0 and $bits <= 32) {
		return undef;
	}
	my $mask_binary = "1" x $bits . "0" x (32 - $bits);
	return join(".",unpack("CCCC", pack("B*",$mask_binary)));
}
1;
