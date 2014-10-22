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

package EBox::RemoteServices::CGI::SubscribeServer;
use base qw(EBox::CGI::ClientRawBase);

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Html;
use EBox::RemoteServices::Subscription::Validate;

use TryCatch::Lite;

sub new
{
    my ($class, @params) = @_;
    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json} = {success => 0 };

    foreach my $param (qw(username password name)) {
        if (not $self->param($param)) {
            $self->{json}->{msg} = __x('Missing parameter: {par}', par => $param);
            return;
        }
    }

    my $username = $self->param('username');
    my $password = $self->param('password');
    my $name     = $self->param('name');

    EBox::RemoteServices::Subscription::Validate::validateServerName($name);

    my $remoteServices = EBox::Global->getInstance()->modInstance('remoteservices');
    $remoteServices->setUsername($username);

    my $subscriptions = $remoteServices->subscriptionsResource($password);

    try {
        my $auth = $remoteServices->authResource($password)->auth();
        if (not exists $auth->{username}) {
            $self->{json}->{error} = __('Invalid credentials');
            return;
        }
    } catch($ex) {
        $self->{json}->{error} = "$ex";
        return;
    }

    my $subscriptionsList;
    try {
        $subscriptionsList = $subscriptions->list();
        if ((not $subscriptionsList) or (@{$subscriptionsList} == 0)) {
            $self->{json}->{error} = __('No subscriptions available for your account');
            return;
        }
    } catch ($ex) {
        $self->{json}->{error} = "$ex";
        return;
    }
    my $subscriptionsHtml = EBox::Html::makeHtml('/remoteservices/subscriptionSlotsTbody.mas',
                                                 serverName => $name,
                                                 password   => $password,
                                                 subscriptions => $subscriptionsList,
                                                );

    $self->{json}->{success} = 1;
    $self->{json}->{subscriptions} = $subscriptionsHtml;
    $self->{json}->{name} = $name;
    $self->{json}->{msg} = __x('Subscribing server as name {name}', name => $name);
}

1;
