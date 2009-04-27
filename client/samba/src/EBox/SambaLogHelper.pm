# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::SambaLogHelper;

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant SAMBA_LOGFILE => '/var/log/syslog';

sub new
{
        my $class = shift;
        my $self = {};
        bless($self, $class);
        return $self;
}

sub domain {
        return 'ebox-samba';
}


# Method: logFiles
#
#	This function must return the file or files to be read from.
#
# Returns:
#
#	array ref - containing the whole paths
#
sub logFiles
{
	return [SAMBA_LOGFILE];
}

# Method: processLine
#
#	This fucntion will be run every time a new line is recieved in
#	the associated file. You must parse the line, and generate
#	the messages which will be logged to ebox through an object
#	implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#	file - file name
#	line - string containing the log line
#	dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;

    return if ($self->_skipLine());

    unless ($line =~ /^(\w+\s+\d+ \d\d:\d\d:\d\d) .*smbd_audit.*?: (.+)/) {
        return;
    }
    my $date = $1;
    my $message = $2;


    my %dataToInsert;

    my $timestamp = $date . ' ' . (${[localtime(time)]}[5] + 1900);
    $dataToInsert{timestamp} = $timestamp;

    if ($message =~ /^ALERT - Scan result: '(.*?)' infected with virus '(.*?)', client: '(.*?)'$/) {
        $dataToInsert{event} = 'virus';
        $dataToInsert{filename} = $1;
        $dataToInsert{virus} = $2;
        $dataToInsert{client} = $3;
    } elsif ($message =~ /^INFO: quarantining file '(.*?)' to '(.*?)' was successful$/) {
        $dataToInsert{event} = 'quarantine';
        $dataToInsert{filename} = $1;
        $dataToInsert{qfilename} = $2;
    } else {
        my @fields = split(/\|/, $message);
        unless (@fields > 2) {
            return;
        }
        $dataToInsert{username} = $fields[0];
        $dataToInsert{client} = $fields[1];
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
            $dataToInsert{resource} =~ s/\s+$//;
        } elsif ($type eq 'open') {
            if ($fields[4] eq 'r') {
                $dataToInsert{event} = 'readfile';
            } else {
                $dataToInsert{event} = 'writefile';
            }
            $dataToInsert{resource} = $fields[5];
            $dataToInsert{resource} =~ s/\s+$//;
        } elsif ($type eq 'rename') {
            my $orig = $fields[4];
            my $dest = $fields[5];
            $orig =~ s/\s+$//;
            $dest =~ s/\s+$//;
            $dataToInsert{resource} = $orig . " -> " . $dest;
        }
    }
    if (defined($dataToInsert{resource}) and ($dataToInsert{resource} eq 'IPC$')) {
        return;
    }

    if ($dataToInsert{event} eq 'virus') {
        $dbengine->insert('samba_virus', \%dataToInsert);
    } elsif ($dataToInsert{event} eq 'quarantine') {
        $dbengine->insert('samba_quarantine', \%dataToInsert);
    } else {
        $dbengine->insert('samba_access', \%dataToInsert);
    }
}


# Method: _skipLine
#
#       Above method "processLine" is called 3 times, because
#       our 3 loggers are watching the same file.
#
#       To avoid inserting the same log line 3 times, we keep track
#       of the times we have been called.
#
sub _skipLine
{
        my ($self) = @_;

        my $skip = $self->{skip};
        unless (defined($skip)) {
                $self->{skip} = 0;
                return 0;
        }

        if ($skip == 2) {
                $self->{skip} = 0;
                return 0;
        } else {
                $self->{skip}++;
                return 1;
        }
}


1;
