# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::NetWrappers;

use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;
use Perl6::Junction qw(any);
use EBox::Validate;
use EBox::Sysfs;
use IO::Socket::INET;
use File::Slurp qw(read_dir);

BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

    @ISA = qw(Exporter);
    @EXPORT = qw();
    %EXPORT_TAGS  = (all => [qw{    list_ifaces iface_exists iface_is_up
                    iface_netmask iface_addresses iface_addresses_with_netmask iface_by_address
                    iface_mac_address list_routes
                    list_local_addresses list_local_addresses_with_netmask
                    route_is_up ip_network ip_broadcast ip_mac
                    bits_from_mask mask_from_bits to_network_with_mask to_network_without_mask
                } ],
            );
    @EXPORT_OK = qw();
    Exporter::export_ok_tags('all');
    $VERSION = EBox::Config::version;
}

my @ifaceList;

# Function: iface_exists
#
#    Check if a given interface exists in the system
#
# Parameters:
#
#       iface - Interface's name
#
# Returns:
#
#       True if exists, otherwise undef
#
sub iface_exists
{
    my ($iface) = @_;
    my @ifaces = list_ifaces();
    return ($iface eq any(@ifaces));
}

# Function: list_ifaces
#
#       Return a list of all real interfaces in the machine
#
# Returns:
#
#       An array containg the interfaces
#
sub list_ifaces
{
    unless (@ifaceList) {
        @ifaceList = @{read_dir('/sys/class/net')};
        @ifaceList = grep (!/:/, @ifaceList);
        @ifaceList = sort @ifaceList;
        @ifaceList = grep (-l "/sys/class/net/$_", @ifaceList);
    }
    return @ifaceList;
}

# Function clean_ifaces_list_cache
#
#  invalidates the ifaces name cache, must be call after adding, removing
#  or renaming interfaces
#
sub clean_ifaces_list_cache
{
    @ifaceList = ();
}

# Function: iface_is_up
#
#   Checks if a given interface is up.
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
    my $state = EBox::Sysfs::read_value("/sys/class/net/$iface/operstate");
    return ($state eq 'up' or
            $state eq 'unknown'); # backward compatibility
}

# Function: iface_mac_address
#
#   Returns the mac address for a given interface
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
    my ($if) = @_;

    unless (iface_exists($if)) {
        throw EBox::Exceptions::DataNotFound(
                data => __('Interface'),
                value => $if);
    }
    my $mac = EBox::Sysfs::read_value("/sys/class/net/$if/address");
    return $mac;
}

# Function: iface_addresses
#
#   Return the addresses for a given interface (dot format)
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

#  Function: iface_by_address
#
#  Search a iface by his address
#
#  Returns:
#
#     The list of ifaces which have that address
sub iface_by_address
{
    my ($addr) = @_;

    my @ifaces;
    foreach my $if (list_ifaces()) {
        my @addresses = iface_addresses($if);
        if ( $addr eq any(@addresses)  ) {
            push @ifaces, $if;
            next;
        }
    }

    return @ifaces;
}

# Function: iface_addresses_with_netmask
#
#   Returns the  addresses for a given interface (dot format)
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
        my ($number, $iface, $family,  $ip, $otherAddrType, $otherAddr) =  split /\s+/, $_, 7;
        if ($otherAddrType eq 'peer') {
            my ($peerIp, $peerMask) = split '/', $otherAddr, 2;
            "$ip/$peerMask"
        } else {
            $ip;
        }
    }  @output;

    return @addrs;
}

# Function: list_routes
#
#   Rertuns the list of current routes
#
#  Parameters:
#     viaGateway - returns  routes that uses a gateway (default: true)
#     localSource - returns routes that uses a local source (default: false)
#
# Returns:
#
#   An array containing hash references. Each hash contains a route
#   and consists of:
#
#   network -  network destination
#   router  -  router used to reach the above network if used
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

# Function: route_is_up
#
#   Checks if a given route is already up.
#
# Parameters:
#
#   network - network destination
#   router -  router used to reach the network
#
# Returns:
#
#       True if it's up, undef otherwise
#
sub route_is_up
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

# Function: ip_network
#
#   Returns the network for an address and netmask
#
# Parameters:
#
#   address - IPv4 address
#   netmask - network mask for the above ip
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

# Function: ip_broadcast
#
#   Returns the broadcast address  for an address and netmask
#
# Parameters:
#
#   address - IPv4 address
#   netmask - network mask for the above ip
#
# Returns:
#
#       The broadcast address
#
sub ip_broadcast
{
    my ($address, $netmask) = @_;
    my $net_bits = pack("CCCC", split(/\./, $address));
    my $mask_bits = pack("CCCC", split(/\./, $netmask));
    return join(".", unpack("CCCC", $net_bits | (~$mask_bits)));
}

# Function: ip_mac
#
#   Returns the mac address for a given IP
#
# Parameters:
#
#   address - IPv4 address
#
# Returns:
#
#   The mac address if found or undef
#
sub ip_mac
{
    my ($address) = @_;
    my $output = `arp -an $address`;

    my ($mac) = ($output =~ /(([0-9a-f]{2}:){5}[0-9a-f]{2})/i);
    return $mac;
}

# Function: bits_from_mask
#
#   Given a network mask it returns it in binary format
#
# Parameters:
#
#   netmask - network mask
#
# Returns:
#
#      Network mask in binary format
#
sub bits_from_mask
{
    my $netmask = shift;
    return unpack("%B*", pack("CCCC", split(/\./, $netmask)));
}

# Function: mask_from_bits
#
#   Given a network mask in binary format it returns it in decimal dot notation
#
# Parameters:
#
#   bits - number of bits
#
# Returns:
#
#      Network mask in decimal dot notation
#
sub mask_from_bits
{
    my ($bits) = @_;

    unless($bits >= 0 and $bits <= 32) {
        return undef;
    }
    my $mask_binary = "1" x $bits . "0" x (32 - $bits);
    return join(".",unpack("CCCC", pack("B*",$mask_binary)));
}

# Function: to_network_with_mask
#
#   Given a network and a netmask rerurns the network with embeded mask (form x.x.x.x/n)
#
# Parameters:
#
#   network - network address
#   netmask - network mask
#
# Returns:
#
#      The network in format  x.x.x.x/m
#
sub to_network_with_mask
{
    my ($network, $netmask) = @_;

    my $bits = bits_from_mask($netmask);
    return "$network/$bits";
}

# Function: to_network_without_mask
#
#   Given a  network with embeded mask (form x.x.x.x/n) it returns the network and netmask
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

# Function: list_local_addresses
#
# Returns:
#    a list with all local ipv4 addresses
#
sub list_local_addresses
{
    my @ifaces = list_ifaces();
    my @localAddresses = map { iface_is_up($_) ?  iface_addresses($_) : () } @ifaces;
    @localAddresses    = map { s{/.*$}{}; $_  } @localAddresses;
    return @localAddresses;
}

# Function: list_local_addresses_with_netmask
#
# Returns:
#   a flat list with pairs of all local ipv4 addresses
#       and their netmask
sub list_local_addresses_with_netmask
{
    my @ifaces = list_ifaces();
    my @localAddresses = map { iface_is_up($_) ?  %{ iface_addresses_with_netmask($_) } : () } @ifaces;
    return @localAddresses;
}

# Method: getFreePort
#
#  Looks for a unused port
#
#  Parameters:
#    proto - protocol ('tcp' or 'udp')
#    localAddess - local address on which look for a free port
#
#   Returns:
#     port number or undef if it could not find a free port
sub getFreePort
{
    my ($proto, $localAddr) = @_;
    $proto or
        throw EBox::Exceptions::MissingArgument('proto');
    $localAddr or
        throw EBox::Exceptions::MissingArgument('localAddr');

    my @socketParams = (
                        Proto => $proto,
                        LocalAddr => $localAddr,
                        LocalPort => 0, # to select a unused port
                       );

    my $sock = IO::Socket::INET->new(@socketParams );
    defined $sock
        or return undef;

    my $port = $sock->sockport();
    $sock->close();

    return $port;
}

1;
