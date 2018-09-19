# Copyright (C) 2004-2007 Warp Networks S.L.
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

package EBox::Validate;

use EBox::Config;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::NetWrappers qw();
use Net::IP;
use NetAddr::IP;
use Mail::RFC822::Address;
use Data::Validate::Domain qw(is_hostname);

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
                                        checkDomainName  checkHost
                                        isIPInNetwork
                                        checkVlanID isPrivateDir isANumber
                                        isAPositiveNumber
                                        checkFilePath checkAbsoluteFilePath
                                } ],
                        );
        @EXPORT_OK = qw();
        Exporter::export_ok_tags('all');
        $VERSION = EBox::Config::version;
}

# Function: isRangeOverlappingWithRange
#
#   Checks if an given range overlaps with another range
#
# Parameters:
#
#       first_range  - Hash with the first range (keys: from, to)
#       second_range - Hash with the second range (keys: from, to)
#
# Returns:
#
#       boolean - True if the ranges overlap, false otherwise
#
sub isRangeOverlappingWithRange # first_range, second_range
{
    my ($first_range, $second_range) = @_;
    my $range1 = new Net::IP("$first_range->{from}-$first_range->{to}");
    my $range2 = new Net::IP("$second_range->{from}-$second_range->{to}");
    return ($range1->overlaps($range2) != $IP_NO_OVERLAP);
}

# Function: isValidRange
#
#   Checks if an given range is valid
#
# Parameters:
#
#       from - IP range start
#       to   - IP range end
#
# Returns:
#
#       boolean - True if the range is valid, false otherwise
#
sub isValidRange # from, to
{
    my ($from, $to) = @_;
    return new Net::IP("$from-$to");
}

# Function: isIPInRange
#
#   Checks if an IP is within a given range
#
# Parameters:
#
#       from - IP range start
#       to   - IP range end
#       host_ip - host address to check it belongs to the given range
#
# Returns:
#
#       boolean - True if the address is within the range, false otherwise
#
sub isIPInRange # from, to, host_ip
{
    my ($from, $to, $host_ip) = @_;
    my $range = new Net::IP("$from-$to");
    my $ip = new Net::IP($host_ip);
    return ($range->overlaps($ip) != $IP_NO_OVERLAP);
}

# Function: isIPInNetwork
#
#   Checks if an IP is within a given network address and its masks
#
# Parameters:
#
#       network_ip - network address
#       network_mask - network mask for above address
#       host_ip - host address to check it belongs to the given network
#
# Returns:
#
#       boolean - True if the address is within the network, false otherwise
#
sub isIPInNetwork # net_ip, net_mask, host_ip
{
    my ($net_ip, $net_mask, $host_ip) = @_;

    my $net = NetAddr::IP->new($net_ip, $net_mask);
    my $ip = NetAddr::IP->new($host_ip);
    return $ip->within($net);
}

# Function: checkCIDR
#
#       Check the validity for a given CIDR block
#
# Parameters:
#
#       cidr - CIDR block to check
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if the cidr is correct, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       <EBox::Exceptions::InvalidData> - CIDR is incorrect
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
            my $netmask = EBox::NetWrappers::mask_from_bits($mask);
            if($netmask){
                my $network = EBox::NetWrappers::ip_network($address, $netmask);
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

# Function: checkIP
#
#       Checks if the string param that holds an ip address is a valid
#       IPv4 address.
#
# Parameters:
#
#       ip - IPv4 address
#       name - ip's name to be used when throwing an Exception (optional)
#
# Returns:
#
#       boolean - True if it is a valid IPv4 address, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - IP is invalid
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

# Function: checkIP6
#
#       Checks if the string param that holds an ip address is a valid
#       IPv6 address.
#
# Parameters:
#
#       ip - IPv6 address
#       name - ip's name to be used when throwing an Exception (optional)
#
# Returns:
#
#       boolean - True if it is a valid IPv4 address, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - IP is invalid
#
sub checkIP6 # (ip, name?)
{
    my ($ip, $name) = @_;

    if (Net::IP::ip_is_ipv6($ip)) {
        return 1;
    }

    if ($name) {
        throw EBox::Exceptions::InvalidData
            ('data' => $name, 'value' => $ip);
    } else {
        return undef;
    }
}

# Function: checkNetmask
#
#       Checks if the string param that holds a network mask is valid .
#
# Parameters:
#
#       nmask - network mask
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if it is a valid network mask, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - mask is incorrect
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
# Function: checkIPNetmask
#
#       Checks if the IP and the mask are valid and that the IP is not a
#       network or  broadcast address with the given mask.
#
#       Note that both name_ip and name_mask should be set, or not set at all
#
#
# Parameters:
#
#       ip - IPv4 address
#       mask -  network mask address
#       name_ip - Data's name to be used when throwing an Exception
#       name_mask - Data's name to be used when throwing an Exception
# Returns:
#
#       boolean - True if it is a valid IPv4 address, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - ip/mask is incorrect
#
sub checkIPNetmask # (ip, mask, name_ip?, name_mask?)
{
    my ($ip,$mask,$name_ip, $name_mask) = @_;
    my $error = 0;

    checkIP($ip,$name_ip);
    if ($mask eq '255.255.255.255') {
        return 1;
    }
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

# Function: checkPort
#
#       Check if the given port is valid
#
# Parameters:
#
#       port - port number
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if it is a valid port, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - ip/mask is incorrect
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

    if (($pnumber > 0) and ($pnumber <= 65535)) {
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
# Function: checkVlanID
#
#       Checks if the given vlan identifier is valid. The valid identifers are
#       numbers betwwen 01 and 4096 (both included)
#
# Parameters:
#
#       id - vlan idintifier
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if it is a valid vlan id, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - id is incorrect
#
sub checkVlanID # (id, name?)
{
    my $id = shift;
    my $name = shift;

    unless($id =~/^\d+$/){
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name,
                 'value' => $id,
                 'advice' =>
                 __('Must be a number between 1 and 4096')
                );
        } else {
            return undef;
        }
    }

    if (($id > 0) && ($id <= 4096)) {
        return 1;
    } else {
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name, 'value' => $id,
                 'advice' =>
                 __('Must be a number between 1 and 4096')
                );
        } else {
            return undef;
        }
    }
}

# Function: checkProtocol
#
#       Checks if the given protocol is valid (tcp or udp)
#
# Parameters:
#
#       proto - protocolo's name
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if it is a valid protocol , false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - protocol is incorrect
#
sub checkProtocol # (protocol, name?)
{
    my $proto = shift;
    my $name = shift;

    # FIXME: Ask for them to <EBox::Types::Service> -> Double dependency
    if ($proto eq 'tcp' ) {
        return 1;
    } elsif ($proto eq 'udp' ) {
        return 1;
    } elsif ($proto eq 'all' ) {
        return 1;
    } elsif ($proto eq 'icmp') {
        return 1;
    } elsif ($proto eq 'gre' ) {
        return 1;
    }
    else {
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name, 'value' => $proto);
        } else {
            return undef;
        }
    }
}

#
# Function: checkMAC
#
#       Checks if the given mac address  is valid
#
# Parameters:
#
#       mac - mac address
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if it is a valid mac address, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - protocol is incorrect
#
sub checkMAC # (mac, name?)
{
    my ($origMac, $name) = @_;
    my $mac = $origMac . ':';
    unless ($mac =~ /^([0-9a-fA-F]{2}:){6}$/) {
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name, 'value' => $origMac);
        } else {
            return undef;
        }
    }

    return 1;
}

# Function: checkVifaceName
#
#       Checks if a virtual interface name is correct. The whole name's length
#       (real + virtual interface) must be no longer than IFMASIZ. Only
#       alphanumeric characters are allowed.
#
# Parameters:
#
#       real - real interface (i.e: eth0, eth1..)
#       virtual - virtual interface (i.e: foo, bar)
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if it is a valid virtual interface, false otherwise
#
# Exceptions:
#
#       If name is passed an exception could be raised
#
#       InvalidData - protocol is incorrect
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

# Function: checkName
#
#       Checks if a given name is valid.
#
#       To be a valid name it must fulfil these requirements
#
#       - starts with a letter
#       - contains only letters, numbers and '_'
#       - isn't longer than 20 characters
#
# Parameters:
#
#       name - name to check
#
# Returns:
#
#       boolean - True if it is a valid name, false otherwise
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

# TODO: Remove this once the call from the mail wizard is changed
# to the checkDomainName public function
sub _checkDomainName
{
    my ($domain) = @_;

    $domain =~ s/\.$//;
    return is_hostname($domain);
}

# Function: checkDomainName
#
#       Checks if a given domain name is valid.
#
# Parameters:
#
#       domain - domain to check
#       name - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if it is a valid domain name, false otherwise
#
sub checkDomainName # (domain, name?)
{
    my ($domain, $name) = @_;

    # According to RFC underscores are forbidden in "hostnames" but not "domainnames"
    my $options = { domain_allow_underscore => 1 };

    $domain =~ s/\.$//;
    unless (is_hostname($domain, $options)) {
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name, 'value' => $domain);
        } else {
            return undef;
        }
    }
    return 1;
}

# Function: checkHost
#
#       Checks if a given host is valid. It is considered valid either a valid
#       no-CIDR IP address or a valid hostname
#
#
# Parameters:
#
#       host - host to check
#       name - Data's name to be used when throwing an Exception.
#
# Returns:
#
#       boolean - True if it is a valid domain name, false otherwise
#
sub checkHost # (domain, name?)
{
    my ($host, $name) = @_;

    # if the host is made only of numbers and points we check it
    # as a IP address otherwise we check it as a hostname
    if ( $host =~ m/^[\d.]+$/ ) {
        return checkIP($host, $name);
    }
    else {
        return checkDomainName($host, $name);
    }
}

# Function: checkEmailAddress
#
#       Check the validity for a given FQDN email address
#
# Parameters:
#
#       address - email address to check
#       name    - Data's name to be used when throwing an Exception
#
# Returns:
#
#       boolean - True if the address is correct. False on failure when
#       parameter name is NOT defined
#
# Exceptions:
#
#       If name is passed an exception will  be raised on failure
#
#       <EBox::Exceptions::InvalidData> - address is incorrect
#
sub checkEmailAddress
{
    my ($address, $name) = @_;
    my $valid = 0;
    if (($address =~ m/^\s/) or ($address =~ m/\s$/)) {
        $valid = 0;
    } else {
        $valid = Mail::RFC822::Address::valid($address);
    }

    unless ($valid) {
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name, 'value' => $address);
        } else {
            return undef;
        }
    }

    return 1;
}

# Function: isPrivateDir
#
#       Check if the given directory is private and owned by the current user
#
# Parameters:
#
#       dir - The directory
#       throwException - wether to throw a exception if the check fails (default: false)
#
# Returns:
#       true if the parameter is a number, undef otherwise.
#
sub isPrivateDir
{
    my ($dir, $throwException) = @_;

    my @stat = stat($dir) ;
    if (@stat == 0) {
        throw EBox::Exceptions::External (__x("Cannot stat dir: {dir}. This may mean that the directory does not exist or the permissions forbid access to it", dir => $dir)) if $throwException;
        return undef;
    }

    if ($< != $stat[4]) {
        throw EBox::Exceptions::External(__x('The directory {dir} is not private; because it is owned by another user', dir => $dir)) if $throwException;
    }
    my $perm = sprintf ("%04o\n", $stat[2] & 07777);
    unless ($perm =~ /.700/) {
        throw EBox::Exceptions::External(('The directory {dir} is not private; because it has not restrictive permissions', dir => $dir)) if $throwException;
        return undef;
    }
}

# Function: isANumber
#
#       Check if the parameter is a number.
#
# Parameters:
#
#       value - The parameter to test.
#
# Returns
#       true if the parameter is a number, undef otherwise.
#
sub isANumber # (value)
{
    my $value = shift;

    ($value =~ /^-?[\d]+$/) and return 1;

    return undef;
}

# Function: isZeroOrNaturalNumber
#
#       Check if the parameter is a positive number or zero.
#
# Parameters:
#
#       value - The parameter to test.
#
# Returns:
#       true if the parameter is a postive number, undef otherwise.
#
sub isZeroOrNaturalNumber # (value)
{
    my $value = shift;

    ($value =~ /^[\d]+$/) and return 1;

    return undef;
}

# Function: checkFilePath
#
#  checks if a given file path is sintaxically correct
#
# Parameters:
#       $filePath - file path to check
#       $name - if this parameter is present we will throw a exception when given a non-correct path using this as name of the data
#
# Returns:
#  true if the parameter is sintaxically correct, undef otherwise.
sub checkFilePath # (filePath, name)
{
    my ($filePath, $name) = @_;

    # see Regexp::Common::URI::RFC1738 in CPAN for inspiration in the regex

    my $fpart = q{[[:alpha:]\-\$_.+!*(),][|\#]+ }; # there are missing character but this will suffice for now...
    my $fPathRegex = "($fpart)?(/$fpart)*";

    if ( $filePath =~ m/$fPathRegex/ ) {
        return 1;
    }
    else {
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name, 'value' => $filePath, 'advice' => __("The file path supplied is not valid. (Currently not all of the valid file's  characters are supported) ") );
        }
        else {
            return undef;
        }
    }
}

# Function: checkAbsoluteFilePath
#
#  checks if a given absolute file path is sintaxically correct
#
# Parameters:
#       $filePath - file path to check
#       $name - if this parameter is present we will throw a exception when given a non-correct path using this as name of the data
#
# Returns:
#  true if the parameter is sintaxically correct and an absolute path, undef otherwise.
sub checkAbsoluteFilePath
{
    my ($filePath, $name) = @_;

    my $isValidPath = checkFilePath($filePath, $name);
    $isValidPath or return undef;

    if ( ( $filePath =~ m{^[^/]} )  or ( $filePath =~ m{/\.+/} ) ) {
        if ($name) {
            throw EBox::Exceptions::InvalidData
                ('data' => $name, 'value' => $filePath, 'advice' => __("The file path must be absolute") );
        }
        else {
            return undef;
        }
    }

    return 1;
}

# Function: checkRegex
#
#  checks if a given regular expression is sintaxically correct
#
# Parameters:
#       $regex - regular expression to check, as string
#       $name - if this parameter is present we will throw a exception when given a non-correct path using this as name of the data
#
# Returns:
#  true if the parameter is sintaxically correct and an absolute path, undef otherwise.
sub checkRegex
{
    my ($regex, $name) = @_;

    eval { qr/$regex/ } ;
    if ($@) {
        my $error = $@;
        if ($name) {
            throw EBox::Exceptions::InvalidData (
                'data' => $name,
                'value' => $regex,
                'advice' => __x('Error on regular expression: {err}', err => $error)
               );

        } else {
            return 0;
        }
    }

    return 1;
}

1;
