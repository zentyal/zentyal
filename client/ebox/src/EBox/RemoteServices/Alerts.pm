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

package EBox::RemoteServices::Alerts;
use base 'EBox::RemoteServices::Auth';

# Class: EBox::RemoteServices::Alerts
#
#      This class sends events to the Control Panel using the SOAP
#      client through VPN. It already takes into account to establish
#      the VPN connection and the required data to auth data
#

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::DataNotFound;

use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Backup> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: pushAlerts
#
#     Push alerts to the CC
#
# Parameters:
#
#     alerts - array ref of <EBox::Event> to be sent to the CC
#
sub pushAlerts
{
    my ($self, $alerts) = @_;

    $self->soapCall('pushAlerts', alerts => $alerts);
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
    return 'alertsServiceUrn';
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

1;
