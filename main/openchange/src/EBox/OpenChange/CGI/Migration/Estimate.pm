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

package EBox::OpenChange::CGI::Migration::Estimate;

# Class: EBox::OpenChange::CGI::Migration::Estimate
#
#   CGI which returns in a JSON structure the estimation of users
#   after receiving the usernames as JSON POST parameter
#

use base 'EBox::CGI::Base';

use feature qw(switch);

use EBox::OpenChange::MigrationRPCClient;
use TryCatch::Lite;
use JSON::XS;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);
    return $self;
}

# Group: Protected methods

sub _process
{
    my ($self) = @_;

    my $postRawData = $self->unsafeParam('POSTDATA');
    my $postData = JSON::XS->new()->decode($postRawData);
    my $users = $postData->{users};
    try {
        my $rpc = new EBox::OpenChange::MigrationRPCClient();
        # Get status
        my $request = { command => EBox::OpenChange::MigrationRPCClient->RPC_COMMAND_STATUS() };
        my $response = $rpc->send_command($request);
        if ($response->{code} != 0) {
            $self->{json}->{error} = __('Invalid RPC server state');
            return;
        }

        EBox::info("The daemon is in state: " . $response->{state});
        given ($response->{state}) {
            when([
                EBox::OpenChange::MigrationRPCClient->RPC_STATE_IDLE(),
                EBox::OpenChange::MigrationRPCClient->RPC_STATE_IMPORTED()]) {
                # Idle, start estimation
                my $u = [];
                foreach my $elem (@{$users}) {
                    push (@{$u}, { name => $elem });
                }
                EBox::info("The daemon is idle, launch estimating");
                my $request = {
                    command => EBox::OpenChange::MigrationRPCClient->RPC_COMMAND_ESTIMATE(),
                    users => $u,
                };
                $rpc->dump($request);
                my $response = $rpc->send_command($request);
                if ($response->{code} != 0) {
                    $self->{json}->{success} = 0;
                    $self->{json}->{error} = $response->{error};
                } else {
                    $self->{json}->{success} = 1;
                    my $oc = EBox::Global->modInstance('openchange');
                    my $state = $oc->get_state();
                    $state->{migration_users} = $u;
                    $oc->set_state($state);
                }
            }
            when ([
                EBox::OpenChange::MigrationRPCClient->RPC_STATE_ESTIMATING(),
                EBox::OpenChange::MigrationRPCClient->RPC_STATE_ESTIMATED()]) {
                my $state = $_;
                # 1 - Estimation on progress
                # 2 - Estimated done. Enable migrate button
                my $seconds = ($response->{totalBytes} * 8 ) / (100 * 1024 * 1024);
                # Estimating, update
                $self->{json} = {
                    result => {
                        'data'     => { 'value' => $response->{totalBytes},       'type' => 'bytes' },
                        'mails'    => { 'value' => $response->{emailItems},       'type' => 'int' },
                        'contacts' => { 'value' => $response->{contactItems},     'type' => 'int' },
                        'calendar' => { 'value' => $response->{appointmentItems}, 'type' => 'int' },
                        'time'     => { 'value' => $seconds, 'type' => 'timediff' },
                    },
                    'state' => ($state == EBox::OpenChange::MigrationRPCClient->RPC_STATE_ESTIMATING() ? 'ongoing' : 'done'),
                }
            }
        }
    } catch ($error) {
        $self->{json}->{error} = $error;
    }
}

1;
