# Copyright (C) 2008-2013 Zentyal S.L.
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

    bless $self, $class;
    return $self;
}

sub _restClientWithUserCredentials
{
    my ($self) = @_;
    my $username = $self->{remoteservices}->username();
    my $password = $self->{remoteservices}->password();

    return $self->_restClient($username, $password);
}

sub _restClientWithServerCredentials
{
    my ($self) = @_;
    my $credentials = $self->{remoteservices}->subscriptionCredentials();
    if (not $credentials) {
        throw EBox::Exceptions::Internal('No subscribed server credentials');
    }

    return $self->_restClient($credentials->{server_uuid}, $credentials->{password});
}

sub _restClient
{
    my ($self, $username, $password) = @_;
    if (not $username) {
        throw EBox::Exceptions::Internal('username');
    }
    if (not $password) {
        throw EBox::Exceptions::Internal('password');
    }

    my $restClient = new EBox::RESTClient(
        server      => EBox::RemoteServices::Configuration::APIEndPoint(),
        credentials => { username => $username,
                         password => $password,
                        }
       );
    return $restClient;
}

sub server
{
    return SERVER;
}

1;
