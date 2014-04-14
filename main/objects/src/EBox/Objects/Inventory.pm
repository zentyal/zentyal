#!/usr/bin/perl

use strict;
use warnings;

package EBox::Objects::Inventory;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidArgument;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Objects;
use EBox::Validate qw( checkCIDR checkIP );
use EBox::Gettext;

use IO::Socket::UNIX;
use IO::Socket;

use constant DEBUG => 0;

use constant P0F_QUERY_MAGIC      => 0x50304601;
use constant P0F_RESP_MAGIC       => 0x50304602;
use constant P0F_STATUS_BADQUERY  => 0x00;
use constant P0F_STATUS_OK        => 0x10;
use constant P0F_STATUS_NOMATCH   => 0x20;
use constant P0F_ADDR_IPV4        => 0x04;
use constant P0F_ADDR_IPV6        => 0x06;
use constant P0F_MATCH_FUZZY      => 0x01;
use constant P0F_MATCH_GENERIC    => 0x02;
use constant P0F_CMD_QUERY_HOST   => 0x01;
use constant P0F_CMD_QUERY_CACHE  => 0x02;

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}

sub connect
{
    my ($self) = @_;

    my $client = new IO::Socket::UNIX(
        Peer    => EBox::Objects::P0F_SOCKET(),
        Type    => SOCK_STREAM,
        Timeout => 10);
    unless (defined $client) {
        throw EBox::Exceptions::External("Failed to connect to p0f daemon");
    }

    return $client;
}

# Method: queryNetwork
#
#   Retrieve all gathered hosts in the given network. The source of this info
#   is the p0f daemon host cache, which expiration time is configured in the
#   EBox::Objects::_setConf.
#
# Arguments:
#
#   network - Network address in CIDR format (network/prefix)
#
# Returns:
#
#   array ref - Contains hash references, each of them contain host info
#
sub queryNetwork
{
    my ($self, $network) = @_;

    unless (defined $network) {
        throw EBox::Exceptions::MissingArgument('network');
    }
    unless (checkCIDR($network)) {
        throw EBox::Exceptions::InvalidArgument('network');
    }

    # The return list
    my $list = [];

    # Split the network and mask to build the query
    my ($addr, $mask) = split (/\//, $network);
    my @addr = split (/\./, $addr);

    # Connect to p0f daemon API socket
    my $client = $self->connect();

    # Build query, 26 bytes
    my $query = '';
    $query .= pack ('L L C C16', P0F_QUERY_MAGIC,
                    P0F_CMD_QUERY_CACHE, P0F_ADDR_IPV4, @addr);
    $query .= pack ('C', 24);
    syswrite ($client, $query, 26);

    # Read response header, 8 bytes
    my $header;
    sysread ($client, $header, 8);

    # Check response magic and response status code
    my ($magic, $status) = unpack('L L', $header);
    if ($magic != P0F_RESP_MAGIC) {
        $client->shutdown(2);
        throw EBox::Exceptions::External("Bad response magic: $magic");
    }
    if ($status != P0F_STATUS_OK) {
        $client->shutdown(2);
        throw EBox::Exceptions::External("Response status not OK: $status");
    }

    # Next read host count and return if count is not > 0
    my $count;
    sysread ($client, $count, 4);
    $count = unpack('L', $count);
    if ($count > 0) {
        # Read the payload NOTE: This can be really big!
        my $payload;
        my $chunkSize = 16 + 1 + 6 + 7*4 + 2 + 1 + 1 + 32*6;
        sysread ($client, $payload, $chunkSize * $count);

        my $offset = 0;
        for (my $i = 0; $i < $count; $i++) {
            my ($addr,
                $addrType,
                $mac,
                $firstSeen,
                $lastSeen,
                $totalConn,
                $uptimeMinutes,
                $uptimeDays,
                $lastNAT,
                $lastOSChange,
                $distance,
                $badSW,
                $matchQuality,
                $osName,
                $osFlavour,
                $httpName,
                $httpFlavour,
                $linkType,
                $language) = unpack("@" ."$offset" . "(A16 C A6 L L L L L L L s C C A32 A32 A32 A32 A32 A32)", $payload);
            $offset += $chunkSize;

            my ($addr1, $addr2, $addr3, $addr4) = unpack('C4', $addr);
            $addr1 = '0' unless defined $addr1;
            $addr2 = '0' unless defined $addr2;
            $addr3 = '0' unless defined $addr3;
            $addr4 = '0' unless defined $addr4;
            $addr = "$addr1.$addr2.$addr3.$addr4";

            my @mac = unpack('(H2)6', $mac);
            $mac = join (':', @mac);

            my $host = {};
            $host->{address}        = $addr;
            $host->{address_type}   = $addrType;
            $host->{mac}            = $mac;
            $host->{os_name}        = $osName;
            $host->{os_flavour}     = $osFlavour;
            $host->{http_name}      = $httpName;
            $host->{http_flavour}   = $httpFlavour;
            $host->{link_type}      = $linkType;
            $host->{language}       = $language;
            push (@{$list}, $host);
        }
    }

    # Shutdown socket
    $client->shutdown(2);

    # And return list
    return $list;
}

# Method: queryHost
#
#   Retrieve host information by IP address. The source of this info
#   is the p0f daemon host cache, which expiration time is configured in the
#   EBox::Objects::_setConf.
#
# Arguments:
#
#   ip - IP address
#
# Returns:
#
#   hash ref - contains host info
#
sub queryHost
{
    my ($self, $ip) = @_;

    unless (defined $ip) {
        throw EBox::Exceptions::MissingArgument('ip');
    }
    unless (checkIP($ip)) {
        throw EBox::Exceptions::InvalidArgument('ip');
    }

    # Connect to p0f daemon API socket
    my $client = $self->connect();

    my @ip = split (/\./, $ip);
    my $query = '';
    $query .= pack ('L L C C16', P0F_QUERY_MAGIC,
                    P0F_CMD_QUERY_HOST, P0F_ADDR_IPV4, @ip);
    $query .= pack ('C', 0);
    syswrite ($client, $query, 26);

    # Read response header, 8 bytes
    my $header;
    sysread ($client, $header, 8);

    # Check response magic and response status code
    my ($magic, $status) = unpack('L L', $header);
    if ($magic != P0F_RESP_MAGIC) {
        $client->shutdown(2);
        throw EBox::Exceptions::External("Bad response magic: $magic");
    }
    if ($status == P0F_STATUS_NOMATCH) {
        $client->shutdown(2);
        throw EBox::Exceptions::DataNotFound(data => __('Host'), value => $ip);
    }
    if ($status != P0F_STATUS_OK) {
        $client->shutdown(2);
        throw EBox::Exceptions::External("Response status not OK: $status");
    }

    my $payload;
    my $chunkSize = 16 + 1 + 6 + 7*4 + 2 + 1 + 1 + 32*6;
    sysread ($client, $payload, $chunkSize);

    $client->shutdown(2);

    my ($addr,
        $addrType,
        $mac,
        $firstSeen,
        $lastSeen,
        $totalConn,
        $uptimeMinutes,
        $uptimeDays,
        $lastNAT,
        $lastOSChange,
        $distance,
        $badSW,
        $matchQuality,
        $osName,
        $osFlavour,
        $httpName,
        $httpFlavour,
        $linkType,
        $language) = unpack("A16 C A6 L L L L L L L s C C A32 A32 A32 A32 A32 A32", $payload);

    my ($addr1, $addr2, $addr3, $addr4) = unpack('C4', $addr);
    $addr1 = '0' unless defined $addr1;
    $addr2 = '0' unless defined $addr2;
    $addr3 = '0' unless defined $addr3;
    $addr4 = '0' unless defined $addr4;
    $addr = "$addr1.$addr2.$addr3.$addr4";

    my @mac = unpack('(H2)6', $mac);
    $mac = join (':', @mac);

    my $host = {
        address      => $addr,
        address_type => $addrType,
        mac          => $mac,
        os_name      => $osName,
        os_flavour   => $osFlavour,
        http_name    => $httpName,
        http_flavour => $httpFlavour,
        link_type    => $linkType,
        language     => $language,
    };

    return $host;
}

1;
