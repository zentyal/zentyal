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

use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Capabilities;
use EBox::RemoteServices::Exceptions::NotCapable;
use EBox::RemoteServices::Subscription;
use Error qw(:try);

# Constants
use constant BANNED_MODULES => qw(asterisk ids jabber mail mailfilter virt zarafa);
# FIXME? To be provided by users mod?
use constant MAX_SB_USERS   => 25;

# Group: Public methods

# Constructor: new
#
#     Create the subscription checker
#
sub new
{
    my ($class, %params) = @_;

    my $self = {};

    bless($self, $class);
    return $self;
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
#    <EBox::RemoteServices::Exceptions::NotCapable> - thrown if any module don't let the
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
#    to its capabilities and the available subscription from the cloud.
#
#    If the server is already connected, then only serverName must be
#    provided, if the server is not connected it requires the user and
#    password pair instead
#
# Parameters:
#
#    user - String the username
#
#    password - String the password
#
#    serverName - String the server name
#
#    - Named parameters
#
# Returns:
#
#    True - if there is no problem in subscribing
#
# Exceptions:
#
#    <EBox::RemoteServices::Exceptions::NotCapable> - thrown if it is not possible to
#    subscribe your server
#
sub subscribe
{
    my ($self, %params) = @_;

    my $availableEditions;
    if ( exists($params{serverName})) {
        my $capabilitiesGetter = new EBox::RemoteServices::Capabilities();
        $availableEditions = $capabilitiesGetter->availableEdition();
    } else {
        my $subscriber     = new EBox::RemoteServices::Subscription(user     => $params{user},
                                                                    password => $params{password});
        $availableEditions = $subscriber->availableEdition();
    }

    foreach my $edition (@{$availableEditions}) {
        if ( $edition eq 'sb' ) {
            try {
                $self->_performSBChecks();
            } catch EBox::RemoteServices::Exceptions::NotCapable with {
                my ($exc) = @_;
                if ( $availableEditions->[-1] eq 'sb' ) {
                    throw $exc;
                }
            };
        }
    }
    return 1;
}

# Group: Private methods

# Perform the required checks for SB edition
sub _performSBChecks
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    $self->_modCheck($gl);
    $self->_usersCheck($gl);
    $self->_vpnCheck($gl);
}

# Check no communication profile, ids and virt module are enabled
sub _modCheck
{
    my ($self, $gl) = @_;

    foreach my $modName (BANNED_MODULES) {
        if ( $gl->modExists($modName) ) {
            my $mod = $gl->modInstance($modName);
            if ( $mod->isEnabled() ) {
                throw EBox::RemoteServices::Exceptions::NotCapable(
                    __sx('You cannot get Module {mod} enabled with Small Business Edition',
                         mod => $mod->printableName()));
            }
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
                throw EBox::RemoteServices::Exceptions::NotCapable(
                    __s('The Small Business Edition can be only used in master mode'));
            }
            if ( scalar(@{$usersMod->listSlaves()}) > 0 ) {
                throw EBox::RemoteServices::Exceptions::NotCapable(
                    __s('The Small Business Edition cannot have got slaves'));
            }
            my $users = $usersMod->usersList();
            if ( scalar(@{$users}) > MAX_SB_USERS ) {
                throw EBox::RemoteServices::Exceptions::NotCapable(
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
                throw EBox::RemoteServices::Exceptions::NotCapable(
                    __sx('The Small Business Edition cannot have VPN tunnels among Zentyal servers and '
                         . "'{name}' VPN server is configured to allow this kind of tunnels",
                         name => $server->name()));
            }
        }
        my @clients = $openvpnMod->clients();
        foreach my $client (@clients) {
            if ( (not $client->internal()) and $client->ripPasswd() ) {
                throw EBox::RemoteServices::Exceptions::NotCapable(
                    __sx('The Small Business Edition cannot have VPN tunnels among Zentyal servers '
                         . "and '{name}' VPN client is connected to another Zentyal server",
                         name => $client->name()));
            }
        }
    }
}

1;
