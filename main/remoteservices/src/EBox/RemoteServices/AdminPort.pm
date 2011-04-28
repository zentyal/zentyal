# Copyright (C) 2011 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::AdminPort
#
#     This class is intended as the client side of the AdminPort WS
#

package EBox::RemoteServices::AdminPort;
use base 'EBox::RemoteServices::Auth';

use strict;
use warnings;

use EBox;
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::AdminPort> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: setAdminPort
#
#     Set the TCP port where the Zentyal server UI is listening to
#
# Parameters:
#
#     port - Int the new TCP port
#
# Returns:
#
#     true - if everything goes as it should
#
sub setAdminPort
{
    my ($self, $port) = @_;

    try {
        $self->soapCall('setAdminPort', port => $port);
    } otherwise {
        EBox::warn("SOAP call setAdminPort failed: $@");
    };

}

# Method: serviceUrn
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::serviceUrn>
#
sub serviceUrn
{
    my ($self) = @_;

    my $urn;
    try {
        $urn = $self->SUPER::serviceUrn();
    } catch EBox::Exceptions::External with {
        # Hardcore the value since the bundle may be updated in a week
        # and this is not called in a cron job
        $urn = 'Zentyal/Cloud/AdminPort';
    };

    return $urn;
}

# Group: Protected methods

# Method: _serviceUrnKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceUrnKey>
#
sub _serviceUrnKey
{
    return 'adminPortServiceUrn';
}

# Method: _serviceHostNameKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceHostNameKey>
#
sub _serviceHostNameKey
{
    return 'managementProxy';
}

# Group: Private methods

1;
