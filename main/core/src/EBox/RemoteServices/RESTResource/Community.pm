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

# Class: EBox::RemoteServices::Community
#
#       Class for community subscriptions REST resource
#
package EBox::RemoteServices::RESTResource::Community;
use base 'EBox::RemoteServices::RESTResource';

use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Validate;
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
sub subscribeFirstTime
{
    my ($self, $user, $name, $newsletter) = @_;
    $self->_checkUser($user);
    $newsletter = $newsletter ? 1 : 0;

    my $resource = '/v2/community/register-and-subscribe/';
    my $query = { email => $user, newsletter => $newsletter, name => $name};

    my $restClient = $self->restClientNoCredentials();
    my $res = $restClient->POST($resource, query => $query);
    return $res->data();

}

# FIXME: Missing doc
sub subscribeAdditionalTime
{
    my ($self, $name) = @_;

    my $resource = '/v2/community/subscribe/';
    my $query = { name => $name};


    my $restClient = $self->restClientWithUserCredentials();
    my $res = $restClient->POST($resource, query => $query);
    return $res->data();
}

sub _checkUser
{
    my ($self, $user) = @_;
    EBox::Validate::checkEmailAddress($user, __('mail address'));
}

1;
