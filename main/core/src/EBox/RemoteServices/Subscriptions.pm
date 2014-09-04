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

# Class: EBox::RemoteServices::Subscription
#
#       Class to manage the Zentyal subscription to Zentyal Cloud
#
package EBox::RemoteServices::Subscriptions;

use base 'EBox::RemoteServices::Base';

#no warnings 'experimental::smartmatch';
#use feature qw(switch);

use EBox::Config;
use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::RESTClient;
# use EBox::RemoteServices::Configuration;
# use EBox::RemoteServices::Connection;

# use EBox::RemoteServices::Subscription::Check;
# use EBox::Sudo;
# use EBox::Util::Nmap;

# use AptPkg::Cache;
# use Archive::Tar;
# use Cwd;
use TryCatch::Lite;
use File::Copy::Recursive;
use File::Slurp;
use File::Temp;
use JSON::XS;
use HTML::Mason;

use constant SERVER => 'api.cloud.zentyal.com';

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


    my $self = $class->SUPER::new();
    $self->{remoteservices} = $params{remoteservices};


    # Set the REST client

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
        server      => SERVER,
        credentials => { username => $username,
                         password => $password,
                        }
       );
    return $restClient;
}

sub subscribeServer
{
    my ($self, $name, $uuid, $mode) = @_;
    my $resource = '/v2/subscriptions/subscribe/';
    my $query = { name => $name, subscription_uuid => $uuid, mode=> $mode};

    my $res = $self->_restClientWithUserCredentials()->POST($resource, query => $query);
    return $res->data();
}

sub unsubscribeServer
{
    my ($self, $name, $uuid, $mode) = @_;
    my $resource = '/v2/subscriptions/unsubscribe/';
    $self->_restClientWithServerCredentials()->POST($resource);    
}

sub list
{
    my ($self) = @_;
    my $res = $self->_restClientWithUserCredentials()->GET('/v2/subscriptions/list/');
    return $res->data();
}

sub subscriptionInfo
{
    my ($self) = @_;
    my $resource = '/v2/subscriptions/info/';

    my $res = $self->_restClientWithServerCredentials()->GET('/v2/subscriptions/info/');
    use Data::Dumper;
    EBox::debug("XXX res \n". Dumper($res));
    return $res->data();
}

# must not be there
sub auth
{
    my ($self) = @_;
    my $res = $self->_restClientWithUserCredentials()->GET('/v2/auth/');
    return $res->data();
}

1;
