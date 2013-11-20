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

package EBox::OpenChange::CGI::Migration::MailboxesList;

# Class: EBox::OpenChange::CGI::Migration::MailboxesList
#
#    Return in a JSON the mailboxes list to migrate from the origin server
#

use base 'EBox::CGI::ClientRawBase';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::OpenChange::MigrationRPCClient;
use TryCatch::Lite;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(
        template => '/openchange/migration/mailboxes_table.mas',
        @_);
    bless ($self, $class);
    return $self;
}

# Group: Protected methods

# Method: masonParameters
#
#    Get the mailbox list from the origin server
#
# Overrides:
#
#    <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;

    my $params = [];
    my $mailboxes = [];
    try {
        EBox::info("Querying mailboxes list");
        my $rpc = new EBox::OpenChange::MigrationRPCClient();
        my $command = {
            command => 5
        };
        my $response = $rpc->send_command($command);
        if ($response->{code} != 0) {
            push(@{$params}, error => "RPC error");
            return $params;
        }

        foreach my $entry (@{$response->{entries}}) {
            my $mailbox = {
                name => $entry->{name},
                username => $entry->{account},
                status => '---',
                date => '---',
            };
            push (@{$mailboxes}, $mailbox);
        }
    } catch {
        # If something goes wrong put this in mason
        my ($error) = @_;
        push(@{$params}, error => $error);
    }

    push (@{$params}, mailboxes => $mailboxes);
    return $params;
}

1;
