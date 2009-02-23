# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::RemoteServices::Auth;

# Class: EBox::RemoteServices::Auth
#
#       This could be applied as the base class to inherit from when a
#       connection with a remote service is done with authentication required
#

use warnings;
use strict;

use base 'EBox::RemoteServices::Base';

# eBox uses
use EBox::Config;
use EBox::Gettext;
use EBox::Global;

use Digest::MD5;
use IO::Socket::INET;

# Constants
use constant SERV_SUBDIR => 'remoteservices/subscription';

# Group: Public methods

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new();

    # Merge self with the certs
    my %certificates = %{$self->_certificates()};
    while ( my ($key, $value) = each(%certificates)) {
        $self->{$key} = $value;
    }

    bless $self, $class;
    return $self;
}

# Method: clientNameForRemoteServices
#
#     OpenVPN client daemon name to be used by remote services which
#     requires authentication
#
# Returns:
#
#     String - the client daemon name
#
sub clientNameForRemoteServices
{
    my ($self) = @_;

    # Create the MD5sum with this and get the first 10 chars
    my $md5 = new Digest::MD5();
    $md5->add($self->_cn());
    my $md5Str = $md5->hexdigest();

    $md5Str = substr($md5Str, 0, 9);

    return "R_D_SRVS_$md5Str";
}

# Method: soapCall
#
# Overrides:
#
#    <EBox::RemoteServices::Base::soapCall>
#
sub soapCall
{
  my ($self, $method, @params) = @_;

  my $conn = $self->connection();

#  my $clientToken = $self->_clientToken();

#  return $conn->$method(commonName => $clientToken, @params);
  return  $conn->$method(@params);
}

# Method: cleanDaemons
#
#    Clean the VPN daemons
#
sub cleanDaemons
{
    my ($self) = @_;

    $self->_disconnect();
}

# Method: serviceUrn
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceUrn>
#
sub serviceUrn
{
    my ($self) = @_;

    my $urn = EBox::Config::configkeyFromFile($self->_serviceUrnKey(),
                                              $self->_confFile());
    if ( not $urn ) {
        throw EBox::Exceptions::External(
            __('Key for service URN not found')
           );
    }
    return $urn;
}

# Method: serviceHostName
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceHostName>
#
sub serviceHostName
{
    my ($class) = @_;
    my $host = EBox::Config::configkeyFromFile($class->_serviceHostNameKey(),
                                               $class->_confFile());
    if ( not $host ) {
        throw EBox::Exceptions::External(
            __('Key for service proxy not found')
           );
    }

    return $host;
}

# Method: vpnClientForServices
#
#     Get the VPN client class for remote services
#
# Returns:
#
#     <EBox::OpenVPN::Client> - the OpenVPN client instance
#
sub vpnClientForServices
{
    my ($self) = @_;

    my $openvpn = EBox::Global->modInstance('openvpn');

    my $client;
    my $clientName = $self->clientNameForRemoteServices();

    if ($openvpn->clientExists($clientName)) {
        $client = $openvpn->client($clientName);
    } else {
        my ($address, $port) = @{$self->vpnAddressAndPort()};

        $client = $openvpn->newClient(
            $clientName,
            internal       => 1,
            service        => 1,
            proto          => 'udp',
            servers        => [
                [$address => $port],
               ],
            caCertificate  => $self->{caCertificate},
            certificate    => $self->{certificate},
            certificateKey => $self->{certificateKey},
            ripPasswd      => '123456' # Not used
           );
        $openvpn->save();
    }

    return $client;
}

# Method: vpnAddressAndPort
#
#     Get the VPN server IP address and port
#
#     We assume UDP protocol.
#
# Returns:
#
#     array ref - containing the two following elements
#
#             ipAddr - String the VPN IP address
#             port   - Int the port to connect to
#
sub vpnAddressAndPort
{
    my ($self) = @_;

    my $address = EBox::Config::configkeyFromFile('vpnIPAddr',
                                                  $self->_confFile());
    my $port    = EBox::Config::configkeyFromFile('vpnPort',
                                                  $self->_confFile());

    return [$address, $port];
}

# Group: Protected methods

# Method: _connect
#
#    This class requires a VPN connection to work correctly
#
# Overrides:
#
#    <EBox::RemoteServices::Base::_connect>
#
sub _connect
{
    my ($self) = @_;

    $self->_vpnConnect();
    $self->SUPER::_connect();

}

# Method: _disconnect
#
# Overrides:
#
#    <EBox::RemoteServices::Base::_disconnect>
#
sub _disconnect
{
    my ($self) = @_;

    $self->SUPER::_disconnect();
    $self->_vpnDisconnect();

}

# Method: _assureConnection
#
#
# Overrides:
#
#      <EBox::RemoteServices::Base::_assureConnection>
#
sub _assureConnection
{
    my ($self) = @_;

    if (not $self->{connection}) {
        $self->_connect();
        # Trying to connect avoiding sleep
        my $timeout = 1;
        while ( $timeout < 10 ) {
            my $sock = new IO::Socket::INET(PeerAddr => $self->_servicesServer(),
                                            PeerPort => 443,
                                            Timeout  => 1);
            sleep(1);
            if ( $sock ) {
                $timeout = 10;
                close($sock);
            } else {
                $timeout++;
            }
        }
    }

    return $self->{connection};
}

# Method: _nameservers
#
#
# Overrides:
#
#      <EBox::RemoteServices::Base::_nameservers>
#
sub _nameservers
{
    my ($self) = @_;

    my $confFile = $self->_confFile();
    my $ns = EBox::Config::configkeyFromFile('dnsServer', $confFile);
    if ( ref($ns) eq 'ARRAY' ) {
        return $ns;
    } else {
        return [ $ns ];
    }

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

# Method: _serviceUrnKey
#
#      Return the key in the configuration file whose value stores the
#      service URN
#
# Returns:
#
#      String - the key whose value stores the service URN
#
sub _serviceUrnKey
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: _serviceHostNameKey
#
#      Return the key in the configuration file whose value stores the
#      service host name
#
# Returns:
#
#      String - the key whose value stores the service host name
#
sub _serviceHostNameKey
{
    throw EBox::Exceptions::NotImplemented();
}


# Group: Private methods

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

# Client token

sub _newClientToken
{
  my ($self, $soapConn) = @_;

  my $username = $self->_userName();
  my $hostname = $self->_cn();
  if ( not $hostname or not $username ) {
      throw EBox::Exceptions::Internal('eBox is not subscribed to perform '
                                       . 'operations which require authentication');
  }

  my $id = $username . '_' . $hostname;

  return $id;

}

sub _clientToken
{
  my ($self) = @_;
  if ( not exists($self->{clientToken})) {
      $self->{clientToken} = $self->_newClientToken($self->connection());
  }
  return $self->{clientToken};

}

# VPN connection related methods
sub _vpnConnect
{
  my ($self) = @_;

  my $openvpn = EBox::Global->modInstance('openvpn');
  my $client = $self->vpnClientForServices();

  my $connected = $client->running(); # XXX change for other thing

  if (not $connected) {
      $client->start();
  }

}

sub _vpnDisconnect
{
  my ($self) = @_;

  my $openvpnMod = EBox::Global->modInstance('openvpn');
  my $client = $self->vpnClientForServices();
  if ( $client ) {
      $client->stop() if $client->running();
#     $client->delete();
      $openvpnMod->deleteClient($client->name());
      $openvpnMod->save();
  }

}

# Remote services options
sub _cn
{
    my ($self) = @_;
    unless ( defined($self->{rs}) ) {
        $self->{rs} = EBox::Global->modInstance('remoteservices');
    }
    return $self->{rs}->eBoxCommonName();
}

sub _userName
{
    my ($self) = @_;
    unless ( defined($self->{rs}) ) {
        $self->{rs} = EBox::Global->modInstance('remoteservices');
    }
    return $self->{rs}->subscriberUsername();
}

1;

