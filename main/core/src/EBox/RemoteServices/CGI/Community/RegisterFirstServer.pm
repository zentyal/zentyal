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

package EBox::RemoteServices::CGI::Community::RegisterFirstServer;
use base qw(EBox::CGI::ClientRawBase);

# CGI to register the user

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::RemoteServices::Subscription::Validate;
use EBox::RemoteServices::Track;
use EBox::Validate;

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

    my $username  = $self->unsafeParam('username');
    my $username2 = $self->unsafeParam('username2');
    if (not $username) {
        $self->{json}->{error} = __('Missing registration mail address');
        return;
    } elsif (not $username2) {
        $self->{json}->{error} = __('Missing confirmation of mail address');
        return;
    } elsif ($username ne $username2) {
        $self->{json}->{error} = __('Registation mail address does not match with its confirmation');
        return;
    }

    my $servername = $self->unsafeParam('servername');
    if (not $servername) {
        $self->{json}->{error} = __('Missing server name');
        return;
    }

    if (not $self->param('confirm_privacy')) {
        $self->{json}->{error} = __('You must accept the privacy policy to register your server');
        return;
    }

    my $newsletter = $self->param('newsletter');
    if ($newsletter) {
        $newsletter = 1;  # Cast to boolean
        $self->{json}->{newsletter} = 1;
    }

    try {
        my $remoteservices = EBox::Global->getInstance()->modInstance('remoteservices');
        $remoteservices->registerFirstCommunityServer($username, $servername, $newsletter);
    } catch (EBox::Exceptions::RESTRequest $ex) {
        if ($ex->code == 409) {
            $self->{json}->{duplicate} = 1;
            $self->{json}->{username}  = $username;
            $self->{error} = __('This email is already registered, please use your password to add this server to your account');
        } else {
            $self->{json}->{duplicate} = 0;
            $self->{json}->{error} = "$ex";
        }
        return;
    } catch ($ex) {
        $self->{json}->{duplicate} = 0;
        $self->{json}->{error} = "$ex";
        return;
    }

    if ($self->param('wizard')) {
        $self->{json}->{trackURI} = EBox::RemoteServices::Track::trackURL($username, $newsletter);
    }

    $self->{json}->{success} = 1;
    $self->{json}->{msg} = __x('You can now use backups for server {name}', name => $servername);
}

1;
