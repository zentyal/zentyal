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
use strict;
use warnings;

# Class: EBox::RemoteServices::Bundle
#
#      This class gathers the bundle sent by Zentyal Cloud while subscribing
#      process is done.
#
#      This bundle can be obtained only when the server is subscribed
#      and has the credentials
#
package EBox::RemoteServices::Bundle;
use base 'EBox::RemoteServices::Cred';

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

# Method: retrieveBundle
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
sub retrieveBundle
{
    my ($self, $remoteServicesVersion, $bundleVersion, $force) = @_;

    my $response = $self->RESTClient()->GET('/v1/servers/' . $self->{cred}->{uuid} . '/',
                                            query => { version => $bundleVersion,
                                                       client_version => $remoteServicesVersion,
                                                       force => $force
                                                      }
                                           );
    return $response->as_string();
}

1;
