# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Printers::LogHelper;

use base 'EBox::LogHelper';

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant CUPS_MAIN_LOG => '/var/log/cups/error_log';
use constant CUPS_PAGES_LOG => '/var/log/cups/page_log';
use constant TS_FORMAT  => '%d/%b/%Y:%T %z';

my %usernameByJob;
my %printerByJob;

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
#       array ref - containing the whole paths
#
sub logFiles
{
    return [CUPS_MAIN_LOG, CUPS_PAGES_LOG];
}

# Method: processLine
#
#       This function will be run every time a new line is recieved in
#       the associated file. You must parse the line, and generate
#       the messages which will be logged to ebox through an object
#       implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#       file - file name
#       line - string containing the log line
#       dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine, $event) = @_;

    my $log;

    if ($file eq CUPS_MAIN_LOG) {
        _processMainLog(@_);
    } elsif ($file eq CUPS_PAGES_LOG) {
        _processPagesLog(@_);
    }
}

sub _processMainLog
{
    my ($self, $file, $line, $dbengine) = @_;
    if ($line =~ m{
                 ^\w\s+ # message type (EDI)
                  \[(.*?)\]\s+ # date
                  \[Job\s+(\d+)\]\s+ # job id block (not always present,
                                   # but present in 'our' lines )
                  (.*?)           # log message
                   $
                  }msx) {
        my $timestamp = $1;
        my $job  = $2;
        my $msg  = $3;
        my $printer = undef;
        my $event   = undef;
        my $username   = undef;
        my $deleteJob = 0;

        if ($msg =~ m/Queued on "(.*?)" by "(.*?)"/) {
            $event = 'queued';
            $printer = $1;
            $username   = $2;
            $usernameByJob{$job} = $username;
            $printerByJob{$job} = $printer;
        } elsif ($msg =~ m/Job completed/) {
            $event = 'completed';
            $username = $usernameByJob{$job};
            $printer  = $printerByJob{$job};
            $deleteJob = 1;

        } elsif ($msg =~ m/Canceled by "(.*?)"/) {
            $event = 'canceled';
            $username = $1;
            $printer  = $printerByJob{$job};
            $deleteJob = 1;
        } else {
            # no event to be logged
            return;
        }

        if ($deleteJob) {
            delete $usernameByJob{$job};
            delete $printerByJob{$job};
        }

        # normalize timestamp
        $timestamp = $self->_convertTimestamp($timestamp, TS_FORMAT);

        my $log = {
            timestamp => $timestamp,
            job => $job,
            printer => $printer,
            username   => $username,
            event => $event
           };
        $dbengine->insert('printers_jobs', $log);

    }
}

sub _processPagesLog
{
    my ($self, $file, $line, $dbengine) = @_;
    EBox::debug("pages log $line");

    my ($printer, $job, $user, $timestamp, $copies) =  $line =~ m/^(.*?)\s+(.*?)\s+(.*?)\s+\[(.*?)\]\s+(\d+)/;
    if (not $copies) {
        return;
    }

    $timestamp = $self->_convertTimestamp($timestamp,  TS_FORMAT);
    $dbengine->insert('printers_pages',
                      {
                       timestamp => $timestamp,
                       printer => $printer,
                       job     => $job,
                       pages   => $copies,
                      }

                     );
}

1;
__DATA__
error_log example:
I [15/Jul/2010:18:17:27 +0200] [Job 8] Canceled by "user".
E [15/Jul/2010:15:01:07 +0200] [cups-driverd] Bad driver information file "/usr/share/cups/drv/sample.drv"!
I [15/Jul/2010:18:36:21 +0200] [Job 11] Queued on "hpqueue" by "user".

I [15/Jul/2010:18:38:54 +0200] [Job 11] Job completed.

page_log example:
hpqueue 13 user [15/Jul/2010:18:48:23 +0200] 4 1DEBUG: - localhost (stdin) na_letter_8.5x11in -

