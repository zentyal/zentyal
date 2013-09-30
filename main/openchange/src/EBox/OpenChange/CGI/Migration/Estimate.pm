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

use Error qw( :try );
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
        my $request = { command => 0 };
        my $response = $rpc->send_command($request);
        if ($response->{code} != 0) {
            $self->{json}->{error} = 'error msg';
            return;
        }

        EBox::info("The daemon is in state: " . $response->{state});
        if ($response->{state} == 0) {
            # Idle, start estimation
            my $u = [];
            foreach my $elem (@{$users}) {
                push (@{$u}, { name => $elem });
            }
            EBox::info("The daemon is idle, launch estimating");
            my $request = {
                command => 2,
                users => $u,
            };
            $rpc->dump($request);
            my $response = $rpc->send_command($request);
            if ($response->{code} != 0) {
                $self->{json}->{error} = 'error msg';
            }
        } elsif ($response->{state} == 1) {
            my $seconds = ($response->{totalBytes} * 8 ) / 100;
            # Estimating, update
            $self->{json} = {
                'data' => $response->{totalBytes},
                'mails'  => $response->{totalMails},
                'contacts' => $response->{totalContacts},
                'calendar' =>  $response->{totalCalentars},
                'time' => "$seconds seconds",
            }
        } elsif ($response->{state} == 2) {
            # Estimated done. Enable migrate button
        }
    } otherwise {
        my ($error) = @_;

        $self->{json}->{error} = $error;
    }
}

1;
