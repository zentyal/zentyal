# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Subscription::Check
#
#  This class performs the required checks to subscribe/unsubscribe
#  your server from the cloud
#

package EBox::RemoteServices::Subscription::Check;

use strict;
use warnings;

use base 'EBox::RemoteServices::Base';

use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;

# Constants
use constant SERV_CONF_FILE => 'remoteservices.conf';
use constant BANNED_MODULES => qw(mail jabber asterisk mailfilter virt);
use constant MAX_SB_USERS   => 25;

# Group: Public methods

# Constructor: new
#
#     Create the subscription checker client
#
# Parameters:
#
#     user - String the username for auth proposes
#     password - String the password used for authenticating the user
#
#     - Named parameters
#
sub new
{
    my ($class, %params) = @_;

    exists $params{user} or
      throw EBox::Exceptions::MissingArgument('user');
    exists $params{password} or
      throw EBox::Exceptions::MissingArgument('password');

    my $self = $class->SUPER::new();

    $self->{user} = $params{user};
    $self->{password} = $params{password};

    bless($self, $class);
    return $self;
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

    return 'EBox/Services/RegisteredEBoxList';
}

# Method: serviceHostName
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceHostName>
#
sub serviceHostName
{
    my $host = EBox::Config::configkeyFromFile('ebox_services_www',
                                               EBox::Config::etc() . SERV_CONF_FILE );
    $host or
      throw EBox::Exceptions::External(
          __('Key for web subscription service not found')
         );

    return $host;
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

  return $conn->$method(
                        user      => $self->{user},
                        password  => $self->{password},
                        @params
                       );
}

# Method: unsubscribeIsAllowed
#
#    Check whether the installed modules let the host be unsubscribed
#    from the cloud
#
#    Static method
#
# Returns:
#
#    True - if there is no problem in unsubscribing
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if any module don't let the
#    host be unsubscribed from the cloud
#
sub unsubscribeIsAllowed
{
    my $modList = EBox::Global->modInstances();
    foreach my $mod (@{  $modList }) {
        my $method = 'canUnsubscribeFromCloud';
        if ($mod->can($method)) {
            $mod->$method();
        }
    }
    return 1;
}

# Method: subscribe
#
#    Check whether the host is able to subscribe this server according
#    to its capabilities and the available subscription from the cloud
#
# Returns:
#
#    True - if there is no problem in subscribing
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if it is not possible to
#    subscribe your server
#
sub subscribe
{
    my ($self) = @_;

    #my $availableEdition = $self->soapCall('availableEdition');
    my $availableEdition = 'sb';

    unless ( $availableEdition eq 'sb' ) {
        $self->_performSBChecks();
    }
    return 1;
}

# Group: Private methods

# Perform the required checks for SB edition
sub _performSBChecks
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    $self->_commProfileAndVirtCheck($gl);
    $self->_usersCheck($gl);
    $self->_vpnCheck($gl);
}

# Check no communication profile and virt module are installed
sub _commProfileAndVirtCheck
{
    my ($self, $gl) = @_;

    foreach my $modName (BANNED_MODULES) {
        if ( $gl->modExists($modName) ) {
            my $mod = $gl->modInstance($modName);
            throw EBox::Exceptions::External(
                __sx('Module {mod} is not possible to be installed with Small Business Edition',
                     mod => $mod->printableName()));
        }
    }
}

# Check number of users and M/S configuration
sub _usersCheck
{
    my ($self, $gl) = @_;

    if ( $gl->modExists('users') ) {
        my $usersMod = $gl->modInstance('users');
        if ( $usersMod->isEnabled() ) {
            unless ( $usersMod->mode() eq 'master' ) {
                throw EBox::Exceptions::External(
                    __s('The Small Business Edition can be only used in master mode'));
            }
            if ( scalar(@{$usersMod->listSlaves()}) > 0 ) {
                throw EBox::Exceptions::External(
                    __s('The Small Business Edition cannot have got slaves'));
            }
            my $users = $usersMod->usersList();
            if ( scalar(@{$users}) > MAX_SB_USERS ) {
                throw EBox::Exceptions::External(
                    __sx('The maximum number of users for Small Business Edition is {max} '
                         . 'and you currently have {nUsers}',
                         max => MAX_SB_USERS, nUsers => scalar(@{$users})));
            }
        }
    }
}

# Check there is no VPN-VPN tunnel
sub _vpnCheck
{
    my ($self, $gl) = @_;

    if ( $gl->modExists('openvpn') ) {
        my $openvpnMod = $gl->modInstance('openvpn');
        my @servers    = $openvpnMod->servers();
        foreach my $server (@servers) {
            if ( $server->pullRoutes() ) {
                throw EBox::Exceptions::External(
                    __sx('The Small Business Edition cannot have VPN tunnels among Zentyal servers and '
                         . '{name} VPN server is configured to allow these tunnels',
                         name => $server->name()));
            }
        }
        my @clients = $openvpnMod->clients();
        foreach my $client (@clients) {
            if ( (not $client->internal()) and $client->ripPasswd() ) {
                throw EBox::Exceptions::External(
                    __sx('The Small Business Edition cannot have VPN tunnels among Zentyal servers '
                         . 'and {name} VPN client is connected to another Zentyal server',
                         name => $client->name()));
            }
        }
    }
}

1;
