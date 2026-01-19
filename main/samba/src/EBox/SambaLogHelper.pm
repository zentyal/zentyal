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
#   This function will be run every time a new line is received in
#   the associated file. You must parse the line, and generate
#   the messages which will be logged to ebox through an object
#   implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#   file - file name
#   line - string containing the log line
#   dbengine- An instance of class implementing AbstractDBEngine interface
#
sub processLine
{
    my ($self, $file, $line, $dbengine) = @_;

    # Only smbd_audit
    return unless $line =~ /smbd_audit:/;

    utf8::decode($line);

    # Get timestamp ISO-8601 and message
    my ($ts, $message) = $line =~
        m/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\.\d+\+\d{2}:\d{2}\s+\S+\s+smbd_audit:\s*(.+)$/;

    return unless $ts and $message;

    # Ignore "message repeated X times"
    return if $message =~ /^message repeated \d+ times:/;

    $ts =~ s/T/ /;
    my $timestamp = $self->_convertTimestamp($ts, '%Y-%m-%d %T');

    my %dataToInsert = (
        timestamp => $timestamp,
    );

    my @fields = split(/\|/, $message);
    return unless @fields > 3;

    $dataToInsert{username} = $fields[0];
    $dataToInsert{client}   = $fields[1];

    # TODO: Log failures (fail (msg))
    return unless $fields[3] eq 'ok';

    my $type = $fields[2];
    $dataToInsert{event} = $type;

    if (
        ($type eq 'connect') or
        ($type eq 'disconnect') or
        ($type eq 'pread_send') or
        ($type eq 'pwrite_send') or
        ($type eq 'unlinkat') or
        ($type eq 'mkdirat')
    ) {
        $dataToInsert{resource} = $fields[4];

    } elsif ($type eq 'renameat') {
        my $orig = $fields[4];
        my $dest = $fields[5];
        $orig =~ s/\s+$//;
        $dest =~ s/\s+$//;
        $dataToInsert{resource} = "$orig -> $dest";

    } elsif (
        ($type eq 'create_file') and
        ($fields[5] eq 'file') and
        ($fields[6] =~ /^(open|create|open_if)$/)
    ) {
        $dataToInsert{resource} = $fields[7];

    } else {
        # Not implemented
        return;
    }

    if (defined $dataToInsert{resource}) {
        $dataToInsert{resource} =~ s/\s+$//;
        return if $dataToInsert{resource} eq 'IPC$';

        if (length($dataToInsert{resource}) > RESOURCE_FIELD_MAX_LENGTH) {
            my $abbr = '(..) ' .
                substr($dataToInsert{resource},
                       -(RESOURCE_FIELD_MAX_LENGTH - 5));
            $dataToInsert{resource} = $abbr;
        }
    }

    $dbengine->insert('samba_access', \%dataToInsert);
}

1;
