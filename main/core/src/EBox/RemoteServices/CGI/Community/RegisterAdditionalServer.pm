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

package EBox::RemoteServices::CGI::Community::RegisterAdditionalServer;
use base qw(EBox::CGI::ClientRawBase);

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Html;

use TryCatch::Lite;


sub _process
{
    my ($self) = @_;
    $self->{json} = {success => 0 };

    my $username  = $self->unsafeParam('username');
    if (not $username) {
        $self->{json}->{error} = __('Missing registration mail address');
        return;
    }

    my $password = $self->unsafeParam('password');
    if (not $password) {
        $self->{json}->{error} = __('Missing registration password');
        return;
    }

    my $servername = $self->unsafeParam('servername');
    if (not $servername) {
        $self->{json}->{error} = __('Missing server name');
        return;
    }

    my $credentials;
    try {
        my $remoteservices = EBox::Global->getInstance()->modInstance('remoteservices');
        $remoteservices->registerAdditionalCommunityServer($username, $password, $servername);
    } catch ($ex) {
        $self->{json}->{error} = "$ex";
        return;
    }

    $self->{json}->{success} = 1;
    $self->{json}->{msg} = __x('You can now use backups for server {name}', name => $credentials->{name});
}

1;
