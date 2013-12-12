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

package EBox::RemoteServices::Cred;

# Class: EBox::RemoteServices::Cred
#
#       This could be applied as the base class to inherit from when a
#       connection with a remote service is done with authentication
#       required and you already have the required credentials
#

use warnings;
use strict;

use base 'EBox::RemoteServices::Base';

use EBox::Global;
use EBox::RemoteServices::RESTClient;
use File::Slurp;
use JSON::XS;

# Group: Public methods

sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new();

    my $rs = EBox::Global->getInstance()->modInstance('remoteservices');
    my $credFile = $self->_credentialsFilePath($rs->eBoxCommonName());

    $self->{cred} = decode_json(File::Slurp::read_file($credFile));

    $self->{restClient} = new EBox::RemoteServices::RESTClient(
        credentials => { username => $self->{cred}->{uuid},
                         password => $self->{cred}->{password} });

    bless($self, $class);
    return $self;
}

# Method: RESTClient
#
#     Get the  REST client with credentials to perform requests
#
# Returns:
#
#     <EBox::RemoteServices::RESTClient> - the client
#
sub RESTClient
{
    my ($self) = @_;
    return $self->{restClient};
}

# Method: subscribedHostname
#
#     Get the subscribed hostname
#
# Returns:
#
#     String - the company name + '-' + server name
#
sub subscribedHostname
{
    my ($self) = @_;

    return $self->{cred}->{company} . '-' . $self->{cred}->{name};
}

# Method: subscribedUUID
#
#     Get the subscribed UUID
#
# Returns:
#
#     String - the UUID
#
sub subscribedUUID
{
    my ($self) = @_;

    # Already in string format
    return $self->{cred}->{uuid};
}

# Method: serverName
#
#     Get the subscribed server name
#
# Returns:
#
#     String - the server name
#
sub serverName
{
    my ($self) = @_;

    return $self->{cred}->{name};
}

# Method: cloudDomain
#
#     Get the Zentyal Cloud Domain
#
# Returns:
#
#     String - the Zentyal Cloud Domain
#
sub cloudDomain
{
    my ($self) = @_;

    return $self->{cred}->{cloud_domain};
}

# Method: dynamicDomain
#
#     Get the Zentyal Cloud Dynamic Domain for Dynamic DNS
#
# Returns:
#
#     String - the Zentyal Cloud Dynamic Domain
#
sub dynamicDomain
{
    my ($self) = @_;

    return $self->{cred}->{dynamic_domain};
}

# Method: cloudCredentials
#
#     Get the Zentyal Cloud Credentials
#
# Returns:
#
#        Hash ref - 'uuid' and 'password'
#
sub cloudCredentials
{
    my ($self) = @_;

    return { 'uuid'     => $self->{cred}->{uuid},
             'password' => $self->{cred}->{password} };
}

1;
