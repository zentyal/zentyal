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
use Perl6::Junction qw(any);
use EBox::Validate;

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw();
	%EXPORT_TAGS  = (all => [qw{    list_ifaces iface_exists iface_is_up 
					iface_netmask iface_addresses iface_addresses_with_netmask iface_by_address
					iface_mac_address list_routes
					list_local_addresses list_local_addresses_with_netmask
					route_is_up route_to_reach_network local_ip_to_reach_network
					ip_network ip_broadcast
					bits_from_mask mask_from_bits to_network_with_mask to_network_without_mask
				} ],
			);
	@EXPORT_OK = qw();
	Exporter::export_ok_tags('all');
	$VERSION = EBox::Config::version;
}

# Function: iface_exists 
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
# Function: list_ifaces 
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
# Function: iface_is_up
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
# Function: iface_netmask
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
  warn "Deprecated sub; use iface_addresses_with_netmask instead";
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
# Function: iface_mac_address
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
# Function: iface_address
#
# 	Returns the  addresses for a given interface (dot format)	
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       A list of strings containing the addresses
#
# Exceptions:
#
#       DataNotFound - If interface does not exists
#
sub iface_addresses
{
  my ($if) = @_;

  my @addrs = map {  $_ =~ s{/.*$}{}; $_  }  _ifaceShowAddress($if);
  return @addrs;
}


#
#  Function: iface_by_address
#
#  Search a iface by his address
#
#  Assumption/Limitation: It assumes that we have not repeated addresses
#
#  Returns:
#    
#     The iface or undef if there are not any iface with this address
sub iface_by_address
{
  my ($addr) = @_;

  foreach my $if (list_ifaces()) {
    my @addresses = iface_addresses($if);
    if ( $addr eq any(@addresses)  ) {
      return $if;
    }
  }

  return undef;
}



#
# Function: iface_addresses_with_netmask
#
# 	Returns the  addresses for a given interface (dot format)	
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       A hash reference wich keys are the ip addresses and the values the address' netmask
#
# Exceptions:
#
#       DataNotFound - If interface does not exists
#
sub iface_addresses_with_netmask
{
  my ($if) = @_;
  my %netmaskByAddr;

  my @addrs = _ifaceShowAddress($if);
  foreach my $addr (@addrs) {
    $addr =~ /^(.*)\/(.*)$/  ; 
    my $ip = $1; 
    my $netmask = mask_from_bits($2);
    $netmaskByAddr{$ip} = $netmask;
  }

  return \%netmaskByAddr;
}


sub _ifaceShowAddress
{
  my ($if) = @_;

  unless (iface_exists($if)) {
    throw EBox::Exceptions::DataNotFound(
					 data => __('Interface'),
					 value => $if);
  }


 my @output = `/bin/ip -f inet -o address show $if 2> /dev/null`;

  my @addrs = map {  
    my ($number, $iface, $family,  $ip) =  split /\s+/, $_, 5;
    $ip;
  }  @output;
	
  return @addrs;
}

#
# Function: list_routes 
#
#   	Rertuns the list of current routes
#
#  Parameters:
#     viaGateway - returns  routes that uses a gateway (default: true)
#     localSource - returns routes that uses a local source (default: false)
#
# Returns:
#
#      	An array containing hash references. Each hash contains a route 
#      	and consists of:
#	
#	network -  network destination
#	router  -  router used to reach the above network if used
#       source  -  local ip used to reach the above network if used
#
sub list_routes
{
  my ($viaGateway, $localSource) = @_;
  defined $viaGateway  or $viaGateway = 1;
  defined $localSource or $localSource = 0;

  my @routes = ();
  my @ipOutput = `/bin/ip route show 2>/dev/null`;
  chomp(@ipOutput);

  if ($viaGateway) {
    my  @gwRoutes = grep { $_ =~ m{via}  } @ipOutput; # select routes with gateway
    foreach (@gwRoutes) {
      my ($net, $via, $router) = split(/ /,$_);
      my $route = {network => $net, router => $router};
      push(@routes, $route);
  }

  }

  # get no-gateway routes if instructed to do 
  if ($localSource) {
    my @srcRoutes = grep { $_ =~ m{src}  } @ipOutput; 
    foreach my $r (@srcRoutes) {
      $r =~ m/^(.*?)\sdev.*?src\s(.*?)$/;
      my $net = $1;
      my $source = $2;
      my $route = { network => $net, source => $source };
      push(@routes, $route);;
  } 
  }


  return @routes;
}


# Function: route_to_reach_network
# 
#  Returns the route to reach network (it may be the default route)
#
# Parameters:
#         network - network destintation (CIDR notation)
#
# Bugs:
#    it returns only the first candidate found besides default route
#
# Returns:
#      - route  to reach the network (see list_routes for format). Undef if there is not way to reach the network
sub route_to_reach_network
{
  my ($network) = @_;

  my $defaultRoute = undef;

  foreach  my $route (list_routes(1, 1)) {
    if ($route->{network} eq $network) {
      return $route;
    }
    elsif ($route->{network} eq 'default') {
      $defaultRoute = $route;
    }
  } 


  if (network_is_private_class($network)) {
    return undef;
  }

  return $defaultRoute;
}


# Function: local_ip_to_reach_network
# 
#  Searchs for the local ip used to communicate with the given network
#
# Parameters:
#         network - network destintation
#
# Bugs:
#    it depends in gateway_to_network
#
# Returns:
#      - the local ip. Undef if there is not way to reach the network
sub local_ip_to_reach_network
{
  my ($network) = @_;

  my $route = route_to_reach_network($network);
  if (defined $route->{source}) {  # network reachable directly by local address
    return $route->{source};
  }

  # if the network is of a private class we can not relay in the default gateway
  if (network_is_private_class($network)) {
    return undef;
  }

  my $gw = $route->{router};
  my %localAddresses =   list_local_addresses_with_netmask();
  while (my ($localAddr, $netmask) = each %localAddresses) {
    my $localNetwork = ip_network($localAddr, $netmask);
    if (EBox::Validate::isIPInNetwork($localNetwork, $netmask, $gw)) {
      return $localAddr; 
    }
  }
  
  return undef;
}




#
# Function: route_is_up 
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
# Function: ip_network
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
# Function: ip_broadcast
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
# Function: bits_from_mask 
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
# Function: mask_from_bits 
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

#
# Function: to_network_with_mask
#
# 	Given a network and a netmask rerurns the network with embeded mask (form x.x.x.x/n)
#
# Parameters:
#
#       network - network address
#	netmask - network mask 
#
# Returns:
#
#      The network in format  x.x.x.x/m
#
sub to_network_with_mask
{
  my ($network, $netmask) = @_;
  my $bits =bits_from_mask($netmask);
  return "$network/$bits";
}


#
# Function: to_network_without_mask
#
# 	Given a  network with embeded mask (form x.x.x.x/n) it returns the network and netmask
#
# Parameters:
#
#       networkWithMask - network address in format  x.x.x.x/m
#
# Returns:
#
#      (network, netmask)
#
sub to_network_without_mask
{
  my ($networkWithMask) = @_;
  my ($network, $bits) = split '/', $networkWithMask, 2;
  my $netmask = mask_from_bits($bits);
  return ($network, $netmask);
}


#
# Function: list_local_addresses
#
# Returns:
# 	 a list with all local ipv4 addresses

sub list_local_addresses
{
    my @ifaces = list_ifaces();
    my @localAddresses = map { iface_is_up($_) ?  iface_addresses($_) : () } @ifaces;
    @localAddresses    = map { s{/.*$}{}; $_  } @localAddresses;
    return @localAddresses;
}

#
# Function: list_local_addresses_with_netmask
#
# Returns:
# 	a flat list with pairs of all local ipv4 addresses 
#       and their netmask 
sub list_local_addresses_with_netmask
{
    my @ifaces = list_ifaces();
    my @localAddresses = map { iface_is_up($_) ?  %{ iface_addresses_with_netmask($_) } : () } @ifaces;
    return @localAddresses;
}


sub network_is_private_class
{
  my ($network) = @_;



  if ($network eq '10.0.0.0/8') {
       return 1;
  }
  elsif ($network =~ m{^172[.]16[.](\d)+[.]0[/]12$}) {
    my $partialNetId = $1;
    if (($partialNetId >= 0 ) && ($partialNetId <= 32) ) {
      return 1;
    }
  }
  elsif ($network =~ m{^192[.]168[.]\d+[.]0[/]24$}) {
       return 1;
  }
  elsif ($network eq '169.254.0.0/16') {
       return 1;
  }

  return 0;
}

1;
