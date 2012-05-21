# Copyright (C) 2008-2012 eBox Technologies S.L.
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

use base 'EBox::RemoteServices::Connection';

use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::NetWrappers;

use IO::Socket::INET;

# Constants
use constant SERV_SUBDIR => 'remoteservices/subscription';
use constant MON_HOSTS   => 'monitorHosts';

# Group: Public methods

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new();

    bless $self, $class;
    return $self;
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

# Method: serviceUrn
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceUrn>
#
sub serviceUrn
{
    my ($self) = @_;

    my $urnKey = $self->_serviceUrnKey();
    my $confFile =  $self->_confFile();
    my $urn = EBox::Config::configkeyFromFile($urnKey, $confFile);
    if ( not $urn ) {
        throw EBox::Exceptions::External(
            __x('Cannot retrieve service URN; key "{key}" not found in {file}',

                key => $urnKey,
                file => $confFile,
               )
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
    my ($self) = @_;

    return $self->valueFromBundle($self->_serviceHostNameKey());

}

# Method: valueFromBundle
#
#    Get the value for a key in the given bundle
#
# Returns:
#
#    String - the value corresponding to that key
#
sub valueFromBundle
{
    my ($self, $key) = @_;

    my $value = EBox::Config::configkeyFromFile($key,
                                                $self->_confFile());
    if ( not $value ) {
        throw EBox::Exceptions::External(
            __x('Value for key {k} not found', k => $key)
           );
    }

    return $value;
}

# Method: monitorGatherers
#
#      Return the monitor gatherer IP addresses
#
# Returns:
#
#      array ref - the monitor gatherer IP addresses to sends stats to
#
sub monitorGatherers
{
    my ($self) = @_;

    my $monHosts = $self->valueFromBundle(MON_HOSTS);
    if ( ref $monHosts ne 'ARRAY' ) {
        $monHosts = [ $monHosts ];
    }
    my @monHosts = map { $self->_queryServicesNameserver($_) } @{$monHosts};
    return \@monHosts;

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

    my $vpnClient = $self->vpnClient();
    unless ( $vpnClient ) {
        $self->create();
    }
    $self->connect();
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
    $self->disconnectAndRemove();
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

# Client token

sub _newClientToken
{
  my ($self, $soapConn) = @_;

  my $username = $self->_userName();
  my $hostname = $self->_cn();
  if ( not $hostname or not $username ) {
      throw EBox::Exceptions::Internal('Zentyal is not subscribed to perform '
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

sub _userName
{
    my ($self) = @_;
    return $self->{rs}->subscriberUsername();
}

1;
