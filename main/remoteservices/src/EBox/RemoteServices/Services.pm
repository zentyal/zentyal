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

package EBox::RemoteServices::Services;

# Class: EBox::RemoteServices::Services
#
#       Class to manage the Zentyal services passwords in Zentyal Cloud
#

use base qw(EBox::RemoteServices::Cred);

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;
use EBox::RemoteServices::RESTClient;
use Perl6::Junction qw(any);

# Allowed service names
use constant SERVICES  => ('dyndns', 'ocsinventory');

# Group: Public methods

# Method: getPassword
#
#       Gets the password the given service must use for the connections to
#       Zentyal Cloud
#
# Parameters:
#
#       service_name - String the nameof the service
#
# Returns:
#
#       password - String the newly generated password
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if the compulsory
#       argument is missing
#
#       <EBox::Exceptions::InvalidData> - thrown if the service name is
#       not in SERVICES
#
sub getPassword
{
    my ($self, $service_name) = @_;

    $service_name or throw EBox::Exceptions::MissingArgument('service_name');

    throw EBox::Exceptions::InvalidData('service_name', $service_name)
        unless $service_name eq any(SERVICES);

    # FIXME: Do not ask Zentyal Cloud every time
    my $response = $self->RESTClient()->GET("v1/services/$service_name/password/");

    return $response->data()->{password};
}

1;
