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

package EBox::Validate;

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::NetWrappers qw(:all);
use Net::IP;

use constant IFNAMSIZ => 16; #Max length name for interfaces

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw();
	%EXPORT_TAGS  = (all => [qw{    checkCIDR checkIP checkNetmask 
					checkIPNetmask	
					checkProtocol checkPort
					checkName checkMAC checkVifaceName
					checkDomainName isIPInNetwork
					checkVlanID makePrivateDir isANumber 
					isAPositiveNumber
				} ],
			);
	@EXPORT_OK = qw();
	Exporter::export_ok_tags('all');
	$VERSION = EBox::Config::version;
}

#
# Method: isIPInNetwork 
#
#   Checks if an IP is within a given network address and its masks
#
# Parameters:
#
#       network_ip - network address
#	network_mask - network mask for above address
#	host_ip - host address to check it belongs to the given network
#
# Returns:
#
#	boolean - True if the address is within the network, false otherwise 
#
sub isIPInNetwork # net_ip, net_mask, host_ip
{
	my ($net_ip, $net_mask, $host_ip) = @_;
	my $net_net = ip_network($net_ip, $net_mask);
	
	my $bits = bits_from_mask($net_mask);
	my $ip = new Net::IP("$net_net/$bits");
	my $ip2 = new Net::IP($host_ip);
	return ($ip2->overlaps($ip)==$IP_A_IN_B_OVERLAP);
}

# 
# Method: checkCIDR 
#
#   Checks the validity for a given cidr block 
#
# Parameters:
#
#       cidr - cidr block to check
#	name - Data's name to be used when throwing an Exception
#
# Returns:
#	
#	boolean - True if the cidr is correct, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - cidr is incorrect
#
sub checkCIDR # (cidr, name?)
{
	my $cidr = shift;
	my $name = shift;

	my $ip;

	my @values = split(/\//, $cidr);

	if(@values == 2) {
		my ($address,$mask)  = @values;
		if(checkIP($address)) {
			my $netmask = mask_from_bits($mask);
			if($netmask){
				my $network = ip_network($address, $netmask);
    				if ($network eq $address) {
                                        $ip = new Net::IP("$network/$mask");
                                }

			}
		}
	}

	unless($ip) {
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $cidr);
		} else {
			return undef;
		}
	}
	return 1;
}

# 
# Method: checkIP
#
#	Checks if the string param that holds an ip address is a valid 
#	IPv4 address.
#
# Parameters:
#
#       ip - IPv4 address 
#	name - ip's name to be used when throwing an Exception (optional)
#
# Returns:
#	
#	boolean - True if it is a valid IPv4 address, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - IP is invalid
#
sub checkIP # (ip, name?) 
{
	my $ip = shift;
	my $name = shift;

	if("$ip\." =~ m/^(([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){4}$/){
		my $first = (split(/\./, $ip))[0];
		if(($first != 0) and ($first < 224)) {
			return 1;
		}
	}
	if ($name) {
		throw EBox::Exceptions::InvalidData
			('data' => $name, 'value' => $ip);
	} else {
		return undef;
	}
}

# 
# Method: checkNetmask
#
#	Checks if the string param that holds a network mask is valid .
#
# Parameters:
#
#       nmask - netowrk mask
#	name - Data's name to be used when throwing an Exception
#
# Returns:
#	
#	boolean - True if it is a valid network mask, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - mask is incorrect
#
sub checkNetmask # (mask, name?) 
{
	my $nmask = shift;
	my $name = shift;
	my $error;

	if("$nmask\." =~ m/^(([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){4}$/){
		my $bits;
		foreach (split(/\./, $nmask)){
		 	$bits .= unpack( "B*", pack( "C", $_ ));	
		}
		unless ($bits =~ /^((0+)|(1+0*))$/){
			$error = 1;
		}
	} else {
		$error = 1;
	}

	if ($error) {
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $nmask);
		} else {
			return undef;
		}
	}
	return 1;
}

# 
# Method: checkIPNetmask
#
# 	Checks if the IP and the mask are valid and that the IP is not a 
#	network or  broadcast address with the given mask.
#
# 	Note that both name_ip and name_mask should be set, or not set at all
#
#
# Parameters:
#
#       ip - IPv4 address
#	mask -  network mask address 
#	name_ip - Data's name to be used when throwing an Exception
#	name_mask - Data's name to be used when throwing an Exception
# Returns:
#	
#	boolean - True if it is a valid IPv4 address, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - ip/mask is incorrect
#
sub checkIPNetmask # (ip, mask, name_ip?, name_mask?) 
{
	my ($ip,$mask,$name_ip, $name_mask) = @_;
	my $error = 0;

	checkIP($ip,$name_ip);
	checkNetmask($mask,$name_mask);

	my $ip_bpack = pack("CCCC", split(/\./, $ip));
	my $mask_bpack = pack("CCCC", split(/\./, $mask));

	my $net_bits .= unpack("B*", $ip_bpack & (~$mask_bpack));
	my $broad_bits .= unpack("B*", $ip_bpack | $mask_bpack);

	if(($net_bits =~ /^0+$/) or ($broad_bits =~ /^1+$/)){
		$error = 1;
	}
	if ($error) {
		if ($name_ip) {
			throw EBox::Exceptions::InvalidData
				('data' => $name_ip . "/" . $name_mask,
				 'value' => $ip . "/" . $mask);
		} else {
			return undef;
		}
	}
	return 1;
}

#
# Method: checkPort
#
# 	Checks if the given port is valid
#
# Parameters:
#
#       port - port number
#	name - Data's name to be used when throwing an Exception
#
# Returns:
#	
#	boolean - True if it is a valid port, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - ip/mask is incorrect
#
sub checkPort # (port, name?) 
{
	my $pnumber = shift;
	my $name = shift;

	unless($pnumber =~/^\d+$/){
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $pnumber);
		} else {
			return undef;
		}
	}

	if (($pnumber > 0)&&($pnumber<65535)) {
		return 1;
	} else {
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $pnumber);
		} else {
			return undef;
		}
	}
}

# 
# Method: checkVlanID
#
# 	Checks if the given vlan identifier is valid
#
# Parameters:
#
#       id - vlan idintifier
#	name - Data's name to be used when throwing an Exception
#
# Returns:
#	
#	boolean - True if it is a valid vlan id, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - id is incorrect
#
sub checkVlanID # (id, name?) 
{
	my $id = shift;
	my $name = shift;

	unless($id =~/^\d+$/){
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $id);
		} else {
			return undef;
		}
	}

	if (($id > 0) && ($id <= 4096)) {
		return 1;
	} else {
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $id);
		} else {
			return undef;
		}
	}
}

#
# Method: checkProtocol 
#
# 	Checks if the given protocol is valid (tcp or udp)
#
# Parameters:
#
#       proto - protocolo's name
#	name - Data's name to be used when throwing an Exception
#
# Returns:
#	
#	boolean - True if it is a valid protocol , false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - protocol is incorrect
#
sub checkProtocol # (protocol, name?) 
{
	my $proto = shift;
	my $name = shift;

	if ($proto eq "tcp") {
		return 1;
	} elsif ($proto eq "udp") {
		return 1;
	} else {
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $proto);
		} else {
			return undef;
		}
	}
}

#
# Method: checkMAC
#
# 	Checks if the given mac address  is valid
#
# Parameters:
#
#       mac - mac address
#	name - Data's name to be used when throwing an Exception
#
# Returns:
#	
#	boolean - True if it is a valid mac address, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - protocol is incorrect
#
sub checkMAC # (mac, name?) 
{
	my $mac = shift || '';
	my $name = shift;
        $mac .= ':';
	unless ($mac =~ /^([0-9a-fA-F]{1,2}:){6}$/) {
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $mac);
		} else {
			return undef;
		}
	}

	return 1;

}

#
# Method: checkVifaceName
#
# 	Checks if a virtual interface name is correct. The whole name's length
#	(real + virtual interface) must be no longer than IFMASIZ. Only
#	alphanumeric characters are allowed.
#
# Parameters:
#
#       real - real interface (i.e: eth0, eth1..)
#	virtual - virtual interface (i.e: foo, bar)
#	name - Data's name to be used when throwing an Exception
#
# Returns:
#	
#	boolean - True if it is a valid virtual interface, false otherwise 
#
# Exceptions:
#
#	If name is passed an exception could be raised	
#
#	InvalidData - protocol is incorrect
#

sub checkVifaceName # (real, virtual, name?) 
{
	my $iface  = shift;
	my $viface = shift;
	my $name   = shift;
	
	my $fullname = $iface . ":" . $viface;
	unless (($viface =~ /^\w+$/) and (length($fullname) < IFNAMSIZ)){
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $viface);
		} else {
			return undef;
		}
	}	
	return 1;
}

# Method: checkName 
#
#	Checks if a given name is valid.
#
#	To be a valid name it must fulfil these requirements
#
#       - starts with a letter
#       - contains only letters, numbers and '_'
#       - isn't longer than 20 characters
#
# Parameters:
#
#	name - name to check       
#
# Returns:
#
#	boolean - True if it is a valid name, false otherwise 
#
sub checkName # (name) 
{
	my $name = shift;
	(length($name) <= 20) or return undef;
	(length($name) > 0) or return undef;
	($name =~ /^[\d_]/) and return undef;
	($name =~ /^\w/) or return undef;
	($name =~ /\W/) and return undef;
	return 1;
}

sub _checkDomainName {
	my $d = shift;
	($d =~ /^\w/) or return undef;
	($d =~ /\w$/) or return undef;
	($d =~ /\.-/) and return undef;
	($d =~ /-\./) and return undef;
	($d =~ /\.\./) and return undef;
	($d =~ /^[-\.\w]+$/) or return undef;
	return 1;
}

# Method: checkDomainName 
#
#	Checks if a given domain name is valid.
#
# Parameters:
#
#	name - name to check       
#
# Returns:
#
#	boolean - True if it is a valid domain name, false otherwise 
#
sub checkDomainName # (domain, name?)
{
	my $domain = shift;
	my $name = shift;

	unless (_checkDomainName($domain)) {
		if ($name) {
			throw EBox::Exceptions::InvalidData
				('data' => $name, 'value' => $domain);
		} else {
			return undef;
		}
	}
	return 1;
}
# Method: makePrivateDir
#
#	Creates of checks a private directory owned by the user running this
#	process and with private permissions.
#
# Parameters:
#
#	path - The path of the directory to be created, if it exists it must
#	       already have proper ownership and permissions.
#
# Exceptions:
#
#	Internal - The path exists and is not a directory or has wrong
#		   ownership or permissions. Or it does not exist and 
#		   cannot be created.
sub makePrivateDir # (path)
{
	my $dir = shift;

        if ( -e $dir and not -d $dir) {
                throw EBox::Exceptions::Internal(
                        "Cannot create private directory $dir: file exists");
        }

        unless (-e $dir) {
                mkdir($dir, 0700) or throw EBox::Exceptions::Internal(
                        "Could not create directory: $dir");
        }

        my @stat = stat($dir) or throw EBox::Exceptions::Internal(
                "Cannot stat: $dir");
        if ($< != $stat[4]) {
                throw EBox::Exceptions::Internal("Owner mismatch: $dir");
        }
        my $perm = sprintf ("%04o\n", $stat[2] & 07777);
        unless ($perm =~ /.700/) {
                throw EBox::Exceptions::Internal("Wrong permissions in $dir");
        }
}

# Method: isANumber
#
#	Check if the parameter is a number.
#
# Parameters:
#
#	value - The parameter to test.
#
# Returns
# 	true if the parameter is a number, undef otherwise.
# 	
sub isANumber # (value)
{
	my $value = shift;

	($value =~ /^-?[\d]+$/) and return 1;

	return undef;
}

# Method: isAPositiveNumber
#
#	Check if the parameter is a positive number.
#
# Parameters:
#
#	value - The parameter to test.
#
# Returns
# 	true if the parameter is a postive number, undef otherwise.
# 	
sub isAPositiveNumber # (value)
{
	my $value = shift;

	($value =~ /^[\d]+$/) and return 1;

	return undef;
}

1;
