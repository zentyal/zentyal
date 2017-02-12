# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Util::BugReport;

use EBox::Config;
use EBox::Exceptions::Internal;
use JSON::RPC::Legacy::Client;
use MIME::Base64;
use File::Slurp;
use TryCatch;

# Milestone must be in format 'x.y[.z]'. The first two version numbers as
# separated by dots are used to create the issue in the bug tracker.
# Version MUST exist in bug tracker database AND zentyal-bug-interface service!
use constant RPC_URL => 'http://bugreport.zentyal.org/bugreport/v1';

use constant SOFTWARE_LOG => EBox::Config::log() . 'software.log';

# Method: send
#
# Send a bug report to Zentyal automatic bug report interface.
# It will also attach a generated log
#
# Params:
#   - author_email - Reporter's email
#   - description - Text describing what the user was doing
#   - software - Include also software.log
#
# Returns:
#   Assigned ticket number on trac
#
# Throws EBox::Exceptions::Internal if something goes wrong
#
sub send
{
    my ($author_email, $description) = @_;

    my $version = `dpkg -s zentyal-core|grep ^Version:`;
    ($version) = $version =~ /^Version: (\d+\.\d+)/;

    my $client = new JSON::RPC::Legacy::Client;

    my $title = 'Bug report from Zentyal Server';
    my $callobj = {
        method  => 'ticket.create',
        params  => [
            $title,                          # summary
            $description,                    # description
            {
                reporter => $author_email,   # author
                milestone => $version,       # milestone
            },
            'true',                          # notify
        ],
    };

    my $res = $client->call(RPC_URL, $callobj);
    if ($res) {
        unless ($res->is_success) {
            throw EBox::Exceptions::Internal('Error creating a new ticket in bug tracker: ' . $res->error_message->{message});
            return;
        }

        # Get ticket number and upload log
        my $ticket = $res->result;
        EBox::info('Created bug tracker ticket #' . $ticket);

        _attach($client, $ticket, 'zentyal.log', EBox::Util::BugReport::dumpLog());

        if (-f SOFTWARE_LOG) {
            my @brokenPackages = brokenPackagesList();
            if (@brokenPackages) {
                _attach($client, $ticket, 'software.log', EBox::Util::BugReport::dumpSoftwareLog(@brokenPackages));
            }
        }

        return $ticket;
    } else {
        throw EBox::Exceptions::Internal("Couldn't add the ticket, probably this is a connectivity issue");
    }
}

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

    $res .= "/etc/resolv.conf\n";
    $res .= "----------------\n\n";
    my $resolv = read_file('/etc/resolv.conf');
    $res .= $resolv;
    $res .= "\n\n";

    $res .= "/var/log/zentyal/zentyal.log\n";
    $res .= "----------------------------\n\n";
    $res .= _joinLastLines(1000, @log);

    # mask plaintext passwords in log errors
    $res =~ s/password', '([^']*)'/password', '*****'/g;

    return $res;
}

sub brokenPackagesList
{
    my $output = EBox::Sudo::root("dpkg -l | tail -n +6 | grep -v ^ii | grep -v ^rc | awk '{ print " . '$1 " " $2 ": " $3 ' . "}'");
    return @{ $output };
}

# Method: dumpSoftwareLog
#
# Returns a summary log for the installation. It contains some system
# and broken packages info and last 5000 lines from software.log
#
sub dumpSoftwareLog
{
    my (@brokenPackages) = @_;

    my @log = read_file(SOFTWARE_LOG) or
        throw EBox::Exceptions::Internal("Error opening software.log: $!");

    my $res;
    $res .= "System info\n";
    $res .= "-----------\n";
    $res .= `cat /etc/lsb-release`;
    $res .= `uname -rsmv`;
    $res .= "\n\n";

    if (@brokenPackages) {
        $res .= "Broken packages\n";
        $res .= "---------------\n";
        $res .= "@brokenPackages\n\n";
    }

    $res .= "/var/log/zentyal/software.log\n";
    $res .= "----------------------------\n\n";
    $res .= _joinLastLines(5000, @log);

    return $res;
}

sub _joinLastLines
{
    my ($num, @lines) = @_;

    if (scalar (@lines) <= $num) {
        return join('', @lines);
    } else {
        return join('', @lines[-$num..-1]);
    }
}

sub _attach
{
    my ($client, $ticket, $filename, $content) = @_;

    my $log = encode_base64($content);
    my $callobj = {
        method  => 'ticket.putAttachment',
        params  => [
            $ticket,                                # ticket
            $filename,                              # filename
            $filename,                              # description
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

        EBox::info("Attached $filename to #$ticket");
    }
}

1;
