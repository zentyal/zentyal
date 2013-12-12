# Copyright (C) 2008-2012 Zentyal S.L.
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

package EBox::RemoteServices::Bundle;
use base 'EBox::RemoteServices::Auth';

# Class: EBox::RemoteServices::Bundle
#
#      This class gathers the bundle sent by Zentyal Cloud while subscribing
#      process is done.
#
#      This bundle can be obtained only when the server is subscribed
#

use strict;
use warnings;

use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Bundle> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: eBoxBundle
#
#     Get the Zentyal bundle for this Zentyal
#
# Parameters:
#
#     remoteServicesVersion - String the current remoteservices version
#                             is running
#
#     bundleVersion - Int the Zentyal bundle version you have
#
#     force - Boolean indicating the bundle must be reloaded, no
#             matter the version you set in the previous parameter
sub eBoxBundle
{
    my ($self, $remoteServicesVersion, $bundleVersion, $force) = @_;

    return $self->soapCall('eBoxBundle',
                           version => $bundleVersion,
                           remoteServicesVersion => $remoteServicesVersion,
                           force => $force
                          );
}

# Method: serviceUrn
#
#     We override this method instead of the protected one in order to
#     avoid problems with bootstrapping since the URN for bundle WS is
#     introduced in latest package version, so migration won't work
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::serviceUrn>
#
sub serviceUrn
{
    return 'EBox/Services/Bundle';
}

# Group: Protected methods

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
