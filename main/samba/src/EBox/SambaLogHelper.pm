# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::SambaLogHelper;

use base 'EBox::LogHelper';

use EBox::Gettext;

use constant SAMBA_LOGFILE => '/var/log/syslog';
use constant RESOURCE_FIELD_MAX_LENGTH => 240; # this must be the same length of
                                               # the db samba_Access.resource
                                               # field

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: logFiles
#
#   This function must return the file or files to be read from.
#
# Returns:
#
#   array ref - containing the whole paths
#
sub logFiles
{
    return [SAMBA_LOGFILE];
}

# Method: processLine
#
#   This fucntion will be run every time a new line is recieved in
#   the associated file. You must parse the line, and generate
#   the messages which will be logged to ebox through an object
#   implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#   file - file name
#   line - string containing the log line
#   dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;

    my %dataToInsert;

    unless ($line =~ m/smbd/) {
        return;
    }
    utf8::decode($line);
    unless ($line =~ /^(\w+\s+\d+ \d\d:\d\d:\d\d) .*smbd.*?: (.+)/) {
        return;
    }

    my $date = $1 . ' ' . (${[localtime(time)]}[5] + 1900);
    my $message = $2;

    my $timestamp = $self->_convertTimestamp($date, '%b %e %H:%M:%S %Y');
    $dataToInsert{timestamp} = $timestamp;

    my @fields = split(/\|/, $message);
    unless (@fields > 2) {
        return;
    }
    $dataToInsert{username} = $fields[0];
    $dataToInsert{client} = $fields[1];
    unless (@fields > 3) {
        return;
    }

    unless ($fields[3] eq 'ok') {
        # TODO: Log failures (fail (msg))
        return;
    }

    my $type = $fields[2];
    $dataToInsert{event} = $type;
    if (
        ($type eq 'connect') or
        ($type eq 'opendir') or
        ($type eq 'disconnect') or
        ($type eq 'unlink') or
        ($type eq 'mkdir') or
        ($type eq 'rmdir')
    ) {
        $dataToInsert{resource} = $fields[4];
    } elsif ($type eq 'open') {
        if ($fields[4] eq 'r') {
            $dataToInsert{event} = 'readfile';
        } else {
            $dataToInsert{event} = 'writefile';
        }
        $dataToInsert{resource} = $fields[5];
    } elsif ($type eq 'rename') {
        my $orig = $fields[4];
        my $dest = $fields[5];
        $orig =~ s/\s+$//;
        $dest =~ s/\s+$//;
        $dataToInsert{resource} = $orig . " -> " . $dest;
    } else {
        # Not implemented
        return;
    }

    if (exists $dataToInsert{resource} and defined $dataToInsert{resource}) {
        $dataToInsert{resource} =~ s/\s+$//;
        if ($dataToInsert{resource} eq 'IPC$') {
            return;
        }

        if (length ($dataToInsert{resource}) > RESOURCE_FIELD_MAX_LENGTH) {
            my $abbreviateRes =  '(..) ';
            $abbreviateRes .= substr ($dataToInsert{resource}, - (RESOURCE_FIELD_MAX_LENGTH - 5));
            $dataToInsert{resource} = $abbreviateRes;
        }
    }

    $dbengine->insert('samba_access', \%dataToInsert);
}

1;
