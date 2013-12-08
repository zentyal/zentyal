# Copyright (C) 2012-2013 Zentyal S.L.
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
use warnings;
use strict;

package EBox::RemoteServices::Connection;
use base 'EBox::RemoteServices::Base';
# Class: EBox::RemoteServices::Connection
#
#       Class to manage the VPN connection to Zentyal Cloud
#

use EBox::Config;
use EBox::Global;
use EBox::NetWrappers;

# Constants
use constant SERV_SUBDIR => 'remoteservices/subscription';

# Group: Public methods

sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new();

    $self->{gl} = EBox::Global->getInstance();
    $self->{rs} = $self->{gl}->modInstance('remoteservices');
    $self->{openvpn} = $self->{gl}->modInstance('openvpn');

    # Merge self with the certs
    my %certificates = %{$self->_certificates()};
    while ( my ($key, $value) = each(%certificates)) {
        $self->{$key} = $value;
    }

    bless($self, $class);
    return $self;
}

# Method: clientName
#
#     OpenVPN client daemon name to be used by remote services which
#     requires authentication
#
# Returns:
#
#     String - the client daemon name
#
sub clientName
{
    # TODO: Migration script for this
    return "remoteservices_client";
}

# Method: create
#
#     Create the VPN client
#
# Returns:
#
#     <EBox::OpenVPN::Client> - the VPN client instance
#
sub create
{
    my ($self) = @_;

    my $openvpn = $self->{openvpn};
    my $clientName = $self->clientName();

    if ($openvpn->clientExists($clientName)) {
        $self->{client} = $openvpn->client($clientName);
    } else {
        my ($address, $port, $protocol, $vpnServerName) = @{$self->vpnLocation()};

        # Configure and enable VPN module and its dependencies
        foreach my $depName ((@{$openvpn->depends()}, $openvpn->name())) {
            my $mod = $self->{gl}->modInstance($depName);
            if (not $mod->configured() ) {
                $mod->setConfigured(1);
                $mod->enableActions();
            }
            if (not $mod->isEnabled() ) {
                $mod->enableService(1);
            }
        }

        my @localParams;
        my $localAddr = $self->_vpnClientLocalAddress($address);
        if ($localAddr) {
            my $localPort = EBox::NetWrappers::getFreePort($protocol, $localAddr);
            @localParams = (
                            localAddr  => $localAddr,
                            lport  => $localPort,
                           );
        }

        $self->{client} = $openvpn->newClient(
            $clientName,
            internal       => 1,
            service        => 1,
            proto          => $protocol,
            servers        => [
                [$vpnServerName => $port],
               ],
            caCertificate  => $self->{caCertificate},
            certificate    => $self->{certificate},
            certificateKey => $self->{certificateKey},
            ripPasswd      => '123456', # Not used
            @localParams,
           );
        $openvpn->save();
        # We need to save logs config as newClient performs EBox::OpenVPN::notifyLogChange
        # as it may be changes in the log configuration
        $self->{gl}->modInstance('logs')->save();
    }
    return $self->{client};
}

# Method: connect
#
#    Connect the VPN client if it is not already
#
sub connect
{
    my ($self) = @_;

    my $openvpn = $self->{openvpn};
    my $client = $self->vpnClient();

    my $connected = $client->isRunning(); # XXX change for other thing

    if (not $connected) {
        $client->start();
    }
}

# Method: disconnectAndRemove
#
#     Disconnect and remove the VPN client
#
sub disconnectAndRemove
{
    my ($self) = @_;

    my $openvpnMod = $self->{openvpn};
    my $client = $self->vpnClient();
    if ( $client ) {
        $client->stop() if $client->isRunning();
        #     $client->delete();
        $openvpnMod->deleteClient($client->name());
        $openvpnMod->save();
    }
}

# Method: vpnClient
#
#     Get the VPN client, if exists
#
# Returns:
#
#     <EBox::OpenVPN::Client> - the VPN Client
#
#     undef - if the VPN client does not exist
#
sub vpnClient
{
    my ($self) = @_;

    unless ( exists($self->{client}) ) {
        my $openvpn = $self->{openvpn};
        my $clientName = $self->clientName();
        if ($openvpn->clientExists($clientName)) {
            $self->{client} = $openvpn->client($clientName);
        }
    }
    return $self->{client};
}

# Method: vpnClientAdjustLocalAddress
#
#     Adjust local address and port for VPN client if there is any
#     change in the network configuration to reach VPN server
#
# Parameters:
#
#     client - <EBox::OpenVPN::Client> the VPN client to adjust
#
sub vpnClientAdjustLocalAddress
{
    my ($self, $client) = @_;

    my ($server_r) = @{ $client->servers() };
    my ($serverAddr, $serverPort) = @{ $server_r };
    my $localAddr = $client->localAddr();

    my $newLocalAddr = $self->_vpnClientLocalAddress($serverAddr);
    my $newLocalPort;
    if ($newLocalAddr) {
        if ($localAddr and ($localAddr eq $newLocalAddr)) {
            # no changes
            return;
        }

        $newLocalPort = EBox::NetWrappers::getFreePort($client->proto(), $newLocalAddr);
    } else {
        if (not $localAddr) {
            # no changes
            return;
        }
        $newLocalAddr = undef;
        $newLocalPort = undef;
    }

    # There are changes
    $client->setLocalAddrAndPort($newLocalAddr, $newLocalPort);
    my $openvpn = $self->{openvpn};
    $openvpn->save();
}

# Method: vpnLocation
#
#     Get the VPN server location, that includes IP address, port and
#     protocol
#
# Returns:
#
#     array ref - containing the two following elements
#
#             ipAddr - String the VPN IP address
#             port   - Int the port to connect to
#             protocol - String the protocol 'udp' or 'tcp'
#             serverName - String the server domain name
#
sub vpnLocation
{
    my ($self) = @_;

    unless ( exists ($self->{vpnLocation}) ) {
        my $configKeys = EBox::Config::configKeysFromFile($self->_confFile());

        $self->{vpnLocation} = { 'server'   => $configKeys->{vpnServer},
                                 'address'  => $self->_queryServicesNameserver($configKeys->{vpnServer},
                                                                               $self->_nameservers()),
                                 'port'     => $configKeys->{vpnPort},
                                 'protocol' => $configKeys->{vpnProtocol} };
    }
    return [$self->{vpnLocation}->{address}, $self->{vpnLocation}->{port},
            $self->{vpnLocation}->{protocol}, $self->{vpnLocation}->{server}];
}

# Method: isConnected
#
#    Check whether server is connected to Zentyal Cloud or not
#
# Returns:
#
#    Boolean - indicating the state
#
sub isConnected
{
    my ($self) = @_;

    my $openvpn = $self->{openvpn};
    my $client  = $self->vpnClient();
    if ( $client ) {
        return ($client->isRunning() and $client->ifaceAddress());
    } else {
        return 0;
    }
}

# Method: checkVPNConnectivity
#
#      Check the VPN server is reachable
#
# Exceptions:
#
#      <EBox::Exceptions::External> - thrown if the VPN server is not reachable
#
sub checkVPNConnectivity
{
    my ($self) = @_;

    # return if EBox::Config::boolean('subscription_skip_vpn_scan');

    my ($ipAddr, $port, $proto, $host) = @{$self->vpnLocation()};

    my $ok = 0;
    if ( $proto eq 'tcp' ) {
        $ok = $self->_checkHostPort($host, $proto, $port);
    } else {
        # we use echo service to make sure no firewall stands on our way
         $ok = $self->_checkUDPEchoService($host, $proto, $port);
    }

    if (not $ok) {
        throw EBox::Exceptions::External(
            __x(
                'Could not connect to VPN server "{addr}:{port}/{proto}". '
                . 'Check your network firewall',
                addr => $host,
                port => $port,
                proto => $proto,
               )
           );
    }
}

# Group: Private methods

# get local address for connect with server
sub _vpnClientLocalAddress
{
    my ($self, $serverAddr) = @_;
    my $network = $self->{gl}->modInstance('network');

    # get interfaces to check and their order
    my ($ifaceGw , $gw) = $network->_defaultGwAndIface();
    # check first external ifaces..
    my @ifaces = ( @{ $network->ExternalIfaces() }, @{ $network->InternalIfaces()}  );
    # remove ifaces configured via dhcp
    @ifaces = grep {
        $network->ifaceMethod($_) ne 'dhcp'
    } @ifaces;

    my @addresses;
    foreach my $iface ( @ifaces ) {
        my @ifAddrs = EBox::NetWrappers::iface_addresses($iface);
        if (defined $ifaceGw and ($iface eq $ifaceGw)) {
            # first addresses to look up
            unshift @addresses, @ifAddrs;
        } else {
            push @addresses, @ifAddrs;
        }
    }

    # look whether address can connect to the VPN server
    foreach my $addr (@addresses) {
        # Change this... to use nmap check
        my $pingCmd = "ping -w 3 -I $addr -c 1 $serverAddr 2>&1 > /dev/null";
        system $pingCmd;
        if ($? == 0) {
            return $addr;
        }
    }

    # no address found
    return undef;
}

# Method: _confFile
#
#    Get the configuration file from a directory
#
# Returns:
#
#    String - containing the path to that configuration file
#
sub _confFile
{
    my ($self) = @_;

    my $confDir = EBox::Config::conf() . SERV_SUBDIR . '/' . $self->_cn();
    my @confFiles = <$confDir/*.conf>;

    return $confFiles[0];

}

# Get the certificates path from the configuration file
sub _certificates
{
    my ($self) = @_;

    my $keys = EBox::Config::configKeysFromFile($self->_confFile());

    my $dirPath = EBox::Config::conf() . SERV_SUBDIR . '/' . $self->_cn() . '/';
    my $caCertificate  = $dirPath . $keys->{caCertificate};
    my $certificate    = $dirPath . $keys->{certificate};
    my $certificateKey = $dirPath . $keys->{certificateKey};

    my %certs = (
        caCertificate   => $caCertificate,
        certificate     => $certificate,
        certificateKey  => $certificateKey,
       );

    return \%certs;
}

# Remote services options
sub _cn
{
    my ($self) = @_;
    return $self->{rs}->eBoxCommonName();
}

1;
