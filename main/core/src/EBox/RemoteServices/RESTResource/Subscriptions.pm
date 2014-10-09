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

# Class: EBox::RemoteServices::Subscriptions
#
#       Class for Subscriptions REST resource
#
package EBox::RemoteServices::RESTResource::Subscriptions;
use base 'EBox::RemoteServices::RESTResource';

use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use TryCatch::Lite;

# Group: Public methods

# Constructor: new
#
#     Create the subscription client object
#
# Parameters:
#
#     - remoteservices (named)
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    bless $self, $class;
    return $self;
}

# Method: subscribeServer
#
#      Subscribe a server
#
# Parameters:
#
#      name - String the server's name
#
#      uuid - String the subscription's identifier
#
#      mode - String the mode. Options: new, associate and overwrite
#
# Returns:
#
#      Hash ref - containing the following keys:
#
#          name - String the server's name
#          server_uuid - String the server's identifier
#          subscription_uuid - String the subscription's identifier
#          product_code - String the product code (Optional)
#          password - String the generated password for the user
#
sub subscribeServer
{
    my ($self, $name, $uuid, $mode, @forcedCredentials) = @_;
    my $resource = '/v2/subscriptions/subscribe/';
    my $query = { name => $name, subscription_uuid => $uuid, mode=> $mode};

    my $restClient;
    if (not @forcedCredentials) {
        $restClient = $self->restClientWithUserCredentials();
    } else {
        # FIXME: Delete it?
        $restClient = $self->_restClient(@forcedCredentials);
    }


    my $res = $restClient->POST($resource, query => $query);
    return $res->data();
}

# Method: unsubscribeServer
#
#      Unsubscribe a server.
#
#      Using the server's credentials.
#
sub unsubscribeServer
{
    my ($self, @forcedCredentials) = @_;
    my $resource = '/v2/subscriptions/unsubscribe/';

    my $restClient;
    if (not @forcedCredentials) {
        $restClient = $self->restClientWithServerCredentials();
    } else {
        # FIXME: Delete it?
        $restClient = $self->_restClient(@forcedCredentials);
    }

    $restClient->POST($resource);
}

# Method: list
#
#      List current subscriptions
#
# Returns:
#
#      Array ref - of hash refs with the following keys:
#
#         label - String the subscription label
#
#         subscription_end - String the subscription end with
#                            YYYY-MM-DD HH:MM:SS format
#
#         subscription_start - String the subscription start with
#                              YYYY-MM-DD HH:MM:SS format
#
#         server - Hash ref with the following keys: name and uuid
#
#         codename - String the subscription codename
#
#         company - Hash ref with the following keys: name, uuid and description
#
#         uuid - String the subscription's identifier
#
#         product_code - String the product's code
#
sub list
{
    my ($self) = @_;
    my $res = $self->restClientWithUserCredentials()->GET('/v2/subscriptions/list/');
    return $res->data();
}

# Method: subscriptionInfo
#
#      Get the current subscription information using server credentials.
#
# Returns:
#
#      Hash ref - what an element of <list> returns
#
sub subscriptionInfo
{
    my ($self) = @_;
    my $resource = '/v2/subscriptions/info/';

    my $res = $self->restClientWithServerCredentials()->GET('/v2/subscriptions/info/');
    return $res->data();
}

1;
