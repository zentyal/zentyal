# Copyright (C) 2011-2012 Zentyal S.L.
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

package EBox::RadiusLogHelper;
use base 'EBox::LogHelper';

use EBox;

use constant LOGFILE => '/var/log/freeradius/radius.log';

# Group: Public methods

# Constructor: new
#
#       Create the new Log helper.
#
# Returns:
#
#       <EBox::RadiusLogHelper> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = {};

    bless($self, $class);

    return $self;
}

# Method: logFiles
#
#       This function must return the file or files to be read from.
#
# Returns:
#
#       array ref - containing the whole paths.
#
sub logFiles
{
    return [LOGFILE];
}

# Method: processLine
#
#       This function will be run every time a new line is received in
#       the associated file. You must parse the line, and generate
#       the messages which will be logged to ebox through an object
#       implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#       file - file name
#       line - string containing the log line
#       dbengine- An instance of class implemeting AbstractDBEngine interface
#
# Example lines:
#     Thu Sep 27 18:06:29 2012 : Auth: Login OK: [user1] (from client 127.0.0.1/32 port 1)

sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;

    chomp($line);

    my ($date, $type, $event, $clientInfo) = split /\s*:\s+/, $line, 4;
    unless (defined $type and ($type eq 'Auth') and defined $event) {
        return;
    }


    # date is like 'Mon Nov 8 19:03:14 2004'. rmeove first day
    my $format = '%a %b %e %H:%M:%S %Y';
    my $timestamp = $self->_convertTimestamp($date, $format);

    if ($event =~ /User not found/) {
        $event = 'User not found';
    } elsif ($event =~ /Bind as user failed/) {
        $event = 'Login incorrect';
    }

    my ($port, $client, $mac, $login);
    if ($clientInfo=~ m/^\s*\[(.*?)\]/) {
        $login = $1;
    } else {
        $login = '';
    }
    if ($clientInfo =~ m/from client (.*?) port (\d+)/) {
        $client = $1;
        $port = $2;
        $mac   = $3;
    } else {
        $client = $port = '';
    }
    if ($clientInfo =~ m/via (.*?)/) {
        $mac = $1;
        if ($mac =~ /cli (\w+)/) {
            $mac = $1;
            my $s1 = substr($mac, 0, 2);
            my $s2 = substr($mac, 2, 2);
            my $s3 = substr($mac, 4, 2);
            my $s4 = substr($mac, 6, 2);
            my $s5 = substr($mac, 8, 2);
            my $s6 = substr($mac, 10, 2);
            $mac = sprintf("%s:%s:%s:%s:%s:%s", $s1, $s2, $s3, $s4, $s5, $s6);
        } elsif ($mac =~ /TLS tunnel/) {
            $mac = 'TLS tunnel';
        } else {
            $mac = '';
        }
    } else {
        $mac = '';
    }

    my $data = {
        'timestamp' => $timestamp,
        'event' => $event,
        'login' => $login,
        'client' => $client,
        'port' => $port,
        'mac' => $mac,
    };

    $dbengine->insert('radius_auth', $data);
}

1;
