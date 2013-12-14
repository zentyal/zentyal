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

package EBox::OpenChange::CGI::Migration::SelectMailBoxes;

use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;
use EBox::OpenChange::MigrationRPCClient;
use EBox::Validate;
use TryCatch::Lite;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(title    => __('Mailbox Migration'),
                                  template => 'openchange/migration/select_mailboxes.mas',
                                  @_);
    bless ($self, $class);
    return $self;
}

# Method: masonParameters
#
#     Return the list of mason parameters
#
# Returns:
#
#     Array ref - consists of names and values for the mason template
#
sub masonParameters
{
    my ($self) = @_;

    my $params = [];
    try {
        my $request = {
                command => EBox::OpenChange::MigrationRPCClient->RPC_COMMAND_STATUS(),
        };
        my $rpc = new EBox::OpenChange::MigrationRPCClient();
        my $response = $rpc->send_command($request);
        if ($response->{code} == 0) {
            my $server = $response->{remote};
            my $serverIP = $server;
            if (EBox::Validate::checkIP($server)) {
                $server = 'Exchange server';
            }
            push (@{$params}, server => $server);
            push (@{$params}, serverIP => $serverIP);
        } else {
            # TODO Broken connection
            push (@{$params}, server => '---');
            push (@{$params}, serverIP => 'xxx.xxx.xxx.xxx');
        }
    } catch {
        # TODO Broken connection
        push (@{$params}, server => '---');
        push (@{$params}, serverIP => 'xxx.xxx.xxx.xxx');
    }

    return $params;
}

1;
