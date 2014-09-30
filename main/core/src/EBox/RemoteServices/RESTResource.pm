# Copyright (C) 2014 Zentyal S.L.
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


package EBox::RemoteServices::RESTResource;

use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::RESTClient;
use EBox::RemoteServices::Configuration;

use TryCatch::Lite;

# Group: Public methods

# Constructor: new
#
#     Create the subscription client object
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

    exists $params{remoteservices} or
      throw EBox::Exceptions::MissingArgument('remoteservices');

    my $self = {};
    $self->{remoteservices} = $params{remoteservices};
    my $userPassword   = $params{userPassword};
    if ($params{requireUserPassword} and (not $userPassword)) {
        throw EBox::Exceptions::MissingArgument('userPassword');
    }
    $self->{userPassword} = $userPassword;

    bless $self, $class;
    return $self;
}

# Method: restClientWithUserCredentials
#
#      Return the REST client with user credentials.
#
# Returns:
#
#      <EBox::RESTClient>
#
sub restClientWithUserCredentials
{
    my ($self) = @_;
    my $username = $self->{remoteservices}->username();
    my $password = $self->{userPassword};
    if (not $password) {
        throw EBox::Exceptions::MissingArgument('User password for REST client');
    }

    return $self->_restClient($username, $password, 'rc_uc');
}

# Method: restClientWithServerCredentials
#
#      Return the REST client with server credentials.
#
# Returns:
#
#      <EBox::RESTClient>
#
sub restClientWithServerCredentials
{
    my ($self) = @_;
    my $credentials = $self->{remoteservices}->subscriptionCredentials();
    if (not $credentials) {
        throw EBox::Exceptions::Internal('No subscribed server credentials');
    }

    return $self->_restClient($credentials->{server_uuid}, $credentials->{password}, 'rc_sc');
}


# Method: restClientNoCredentials
#
#      Return the REST client with no credentials.
#
# Returns:
#
#      <EBox::RESTClient>
#
sub restClientNoCredentials
{
    my ($self) = @_;
    if (exists $self->{rc_nc}) {
        return $self->{rc_nc};
    }

    my $restClient = new EBox::RESTClient(
        server      => EBox::RemoteServices::Configuration::APIEndPoint(),
       );

    $self->{rc_nc} = $restClient;
    return $restClient;
}

# Group: Private methods

# Return a <EBox::RESTClient> with proper server and credentials.
sub _restClient
{
    my ($self, $username, $password, $id) = @_;
    if (not $username) {
        throw EBox::Exceptions::Internal('username');
    }
    if (not $password) {
        throw EBox::Exceptions::Internal('password');
    }

    if ((exists $self->{$id}) and $self->{$id}) {
        return $self->{$id};
    }

    my $restClient = new EBox::RESTClient(
        server      => EBox::RemoteServices::Configuration::APIEndPoint(),
        credentials => { username => $username,
                         password => $password,
                        }
       );

    $self->{$id} = $restClient;
    $self->{lastClient} = $restClient;
    return $restClient;
}


1;
