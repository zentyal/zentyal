# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::Util::BugReport;

use strict;
use warnings;

use JSON::RPC::Client;
use MIME::Base64;
use File::Slurp;

use constant RPC_URL => 'http://trac.zentyal.org/jsonrpc';
use constant MILESTONE => '2.2';

#
# Method: send
#
# Send a bug report to Zentyal trac. It will also attach
# a generated log
#
# Params:
#   - author_email - Reporter's email
#   - description - Text describing what the user was doing
#
# Returns:
#   Assigned ticket number on trac
#
# Throws EBox::Exceptions::Internal if something goes wrong
#
sub send
{
    my ($author_email, $description) = @_;

    my $client = new JSON::RPC::Client;

    my $title = 'Bug report from Zentyal Server';
    my $callobj = {
        method  => 'ticket.create',
        params  => [
            $title,                          # summary
            $description,                    # description
            {
                reporter => $author_email,   # author
                milestone => MILESTONE,      # milestone
            },
            'true',                          # notify
        ],
    };

    my $res = $client->call(RPC_URL, $callobj);
    if ($res) {
        unless ($res->is_success) {
            throw EBox::Exceptions::Internal('Error creating a new ticket in trac: ' . $res->error_message->{message});
            return;
        }

        # Get ticket number and upload log
        my $ticket = $res->result;
        EBox::info('Created trac ticket #' . $ticket);

        my $log = encode_base64(EBox::Util::BugReport::dumpLog());
        my $callobj = {
            method  => 'ticket.putAttachment',
            params  => [
                $ticket,                                # ticket
                'zentyal.log',                          # filename
                'zentyal.log',                          # description
                {__jsonclass__ => [ 'binary', $log ]},  # file (base64 format)
                'true',                                 # replace
            ],
        };

        my $res = $client->call(RPC_URL, $callobj);
        if ($res) {
            unless ($res->is_success) {
                throw EBox::Exceptions::Internal("Error attaching log to #$ticket: " . $res->error_message->{message});
                return;
            }

            EBox::info('Attached log to #' . $ticket);
        }

        return $ticket;
    } else {
        throw EBox::Exceptions::Internal("Couldn't add the ticket, probably this is a connectivity issue");
    }
}


#
# Method: dumpLog
#
# Returns a summary log for the server. It contains installed
# zentyal packages and last 1000 lines from zentyal.log
#
sub dumpLog
{
    my @log = read_file(EBox::Config::logfile()) or
        throw EBox::Exceptions::Internal("Error opening zentyal.log: $!");

    my $res;
    $res .= "Installed packages\n";
    $res .= "------------------\n\n";
    my $output = EBox::Sudo::root("dpkg -l | grep zentyal | awk '{ print " . '$1 " " $2 ": " $3 ' . "}'");
    $res .= join('', @{ $output });
    $res .= "\n\n";

    $res .= "/var/log/zentyal/zentyal.log\n";
    $res .= "----------------------------\n\n";

    if (scalar (@log) <= 1000) {
        $res .= join('', @log);
    } else {
        $res .= join('', @log[-1000..-1]);
    }

    return $res;
}


1;
