# Copyright (C) 2013 Zentyal S.L.
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

package EBox::OpenChange::CGI::Migration::ConnectToServer;

use base 'EBox::CGI::Base';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::OpenChange::MigrationRPCClient;
use TryCatch::Lite;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => 'none',
                                  'template' => 'none',
                                  @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    try {
        $self->{json}->{success} = 0;

        $self->_requireParam('server', __('Server'));
        my $server = $self->unsafeParam('server');

        $self->_requireParam('username-origin', __('Origin user name'));
        my $usernameOrigin = $self->unsafeParam('username-origin');

        $self->_requireParam('password-origin', __('Origin password'));
        my $passwordOrigin = $self->unsafeParam('password-origin');

        $self->_requireParam('username-local', __('Local user name'));
        my $usernameLocal = $self->unsafeParam('username-local');

        $self->_requireParam('password-local', __('Local password'));
        my $passwordLocal = $self->unsafeParam('password-local');

        my $rpc = new EBox::OpenChange::MigrationRPCClient();
        my $request = {
            command => EBox::OpenChange::MigrationRPCClient->RPC_COMMAND_CONNECT(),
            remote => {
                address  => $server,
                username => $usernameOrigin,
                password => $passwordOrigin
            },
            local => {
                address => '127.0.0.1',
                username => $usernameLocal,
                password => $passwordLocal
            }
        };
        my $response = $rpc->send_command($request);
        if ($response->{code} == 0) {
            $self->{json}->{success} = 1;
        } else {
            $self->{json}->{success} = 0;
            $self->{json}->{error} = $response->{error};
        }
    } catch ($error) {
        $self->{json}->{success} = 0;
        $self->{json}->{error} = qq{$error};
    }
}

1;
