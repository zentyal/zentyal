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

# Class: EBox::RemoteServices::Subscription
#
#       Class to manage the Zentyal subscription to Zentyal Cloud
#
package EBox::RemoteServices::Subscriptions;
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

# FIXME: Missing doc
sub subscribeServer
{
    my ($self, $name, $uuid, $mode, @forcedCredentials) = @_;
    my $resource = '/v2/subscriptions/subscribe/';
    my $query = { name => $name, subscription_uuid => $uuid, mode=> $mode};

    my $restClient;
    if (not @forcedCredentials) {
        $restClient = $self->_restClientWithUserCredentials();
    } else {
        $restClient = $self->_restClient(@forcedCredentials);
    }


    my $res = $restClient->POST($resource, query => $query);
    return $res->data();
}

# FIXME: Missing doc
sub unsubscribeServer
{
    my ($self, @forcedCredentials) = @_;
    my $resource = '/v2/subscriptions/unsubscribe/';

    my $restClient;
    if (not @forcedCredentials) {
        $restClient = $self->_restClientWithServerCredentials();
    } else {
        $restClient = $self->_restClient(@forcedCredentials);
    }

    $restClient->POST($resource);
}

# FIXME: Missing doc
sub list
{
    my ($self) = @_;
    my $res = $self->_restClientWithUserCredentials()->GET('/v2/subscriptions/list/');
    return $res->data();
}

# FIXME: Missing doc
sub subscriptionInfo
{
    my ($self) = @_;
    my $resource = '/v2/subscriptions/info/';

    my $res = $self->_restClientWithServerCredentials()->GET('/v2/subscriptions/info/');
    return $res->data();
}

1;
