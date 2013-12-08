# Copyright (C) 2012-2012 Zentyal S.L.
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
use constant COMM_MODULES   => qw(asterisk jabber mail webmail zarafa);
# FIXME? To be provided by users mod?
use constant MAX_SB_USERS   => 25;

# Group: Public methods

# Constructor: new
#
#     Create the subscription checker
#
sub new
{
    my ($class) = @_;

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

# Method: check
#
#    Check if a server is suitable for the given edition codename
#
# Parameters:
#
#    edition - String the subscription edition
#
#    commAddOn - Boolean Communications add-on
#
# Returns:
#
#    True - if it is suitable
#
sub check
{
    my ($self, $edition, $commAddOn) = @_;

    my $capable = 1;
    if ($edition eq 'sb') {
        try {
            $self->_performSBChecks($commAddOn);
        } catch EBox::RemoteServices::Exceptions::NotCapable with {
            $capable = 0;
        };
    }
    return $capable;
}

# Method: subscribe
#
#    Check whether the host is able to subscribe this server according
#    to its capabilities.
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
    my ($self) = @_;

    my $capabilitiesGetter = new EBox::RemoteServices::Capabilities();
    my $availableEditions  = $capabilitiesGetter->availableEdition();
    my $commAddOn          = $capabilitiesGetter->commAddOn();
    foreach my $edition (@{$availableEditions}) {
        if ( $edition eq 'sb' ) {
            try {
                $self->_performSBChecks($commAddOn);
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
    my ($self, $commAddOn) = @_;

    my $gl = EBox::Global->getInstance();
    $self->_modCheck($gl, $commAddOn);
    $self->_usersCheck($gl);
}

# Check no communication profile is enabled
sub _modCheck
{
    my ($self, $gl, $commAddOn) = @_;

    my @mod = ();
    push(@mod, COMM_MODULES) unless ( $commAddOn );

    foreach my $modName (@mod) {
        if ( $gl->modExists($modName) ) {
            my $mod = $gl->modInstance($modName);
            if ( $mod->isEnabled() ) {
                throw EBox::RemoteServices::Exceptions::NotCapable(
                    __sx('Communications add-on is required in order to enable '
                         . '{mod} in the Small Business Edition.',
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
            if ( not ( ($usersMod->mode() eq 'master') or ($usersMod->mode() eq 'ad-slave') ) ) {
                throw EBox::RemoteServices::Exceptions::NotCapable(
                    __s('The Small Business Edition can be only used in master mode or Active Directory slave'));
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

1;
