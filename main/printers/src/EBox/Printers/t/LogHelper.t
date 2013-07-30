# Copyright (C) 2010-2013 Zentyal S.L.
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

use lib '../../..';

use EBox::Printers::LogHelper;

use Test::More qw(no_plan);
use Test::MockObject;
use Test::Exception;

use EBox::TestStubs;

use Data::Dumper;

my $dumpInsertedData = 0;

use constant JOB_TABLE => "printers_jobs";
use constant PAGES_TABLE => "printers_pages";

sub newFakeDBEngine
{
    my $dbengine = Test::MockObject->new();

    $dbengine->mock('insert' => sub {
                        my ($self, $table, $data) = @_;
                        if (not exists $self->{rows}) {
                            $self->{rows} = [];
                        }

                        my $row = $data;
                        $row->{'_table'} = $table;

                        push @{ $self->{rows} }, $row;
                    }
    );

    $dbengine->mock('clear' => sub {
                        my ($self) = @_;
                        $self->{rows} = [];
                    }
     );

    return $dbengine;
}

sub _currentYear
{
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
    $year += 1900;
    return $year;
}

sub checkInsert
{
    my ($dbengine, $expectedData) = @_;

    my $data = delete $dbengine->{rows};
    if ($dumpInsertedData) {
        diag "Inserted Data:\n" . Dumper $data;
    }

    is_deeply $data, $expectedData, 'checking if inserted data is correct';
}

my $year = _currentYear();
my @cases = (
             {
              name => 'page_log file',
              file  => '/var/log/cups/page_log',
              lines => [
'hpqueue 3 root [15/Jul/2010:17:12:17 +0200] 1 1DEBUG: - localhost tmpvRaUM0 na_letter_8.5x11in -',
'hpqueue 3 root [15/Jul/2010:17:13:30 +0200] 2 1DEBUG: - localhost tmpvRaUM0 na_letter_8.5x11in -',
'hpqueue 3 root [15/Jul/2010:17:14:06 +0200] 3 1DEBUG: - localhost tmpvRaUM0 na_letter_8.5x11in -',
'epsonqueue 4 user [15/Jul/2010:17:36:57 +0200] 1 1STATE: - localhost (stdin) na_letter_8.5x11in -',
'hpqueue 3 root [15/Jul/2010:17:14:42 +0200] 4 1DEBUG: - localhost tmpvRaUM0 na_letter_8.5x11in -',
'epsonqueue 4 user [15/Jul/2010:17:38:14 +0200] 2 1DEBUG: - localhost (stdin) na_letter_8.5x11in -',
'epsonqueue 4 user [15/Jul/2010:17:38:50 +0200] 3 1DEBUG: - localhost (stdin) na_letter_8.5x11in -',
'epsonqueue 4 user [15/Jul/2010:17:39:38 +0200] 4 2STATE: - localhost (stdin) na_letter_8.5x11in -',

                       ],
              expectedData =>  [
                                {
                                 '_table' => 'printers_pages',
                                 'timestamp' => '15/Jul/2010 17:12:17 +0200',
                                 'printer' => 'hpqueue',
                                 'job' => 3,
                                 'pages' => 1
                                },
                                {
                                 '_table' => 'printers_pages',
                                 'timestamp' => '15/Jul/2010 17:13:30 +0200',
                                 'printer' => 'hpqueue',
                                 'job' => 3,
                                 'pages' => 1
                                },
                                {
                                 '_table' => 'printers_pages',
                                 'timestamp' => '15/Jul/2010 17:14:06 +0200',
                                 'printer' => 'hpqueue',
                                 'job' => 3,
                                 'pages' => 1
                                },
                                {
                                 '_table' => 'printers_pages',
                                 'timestamp' => '15/Jul/2010 17:36:57 +0200',
                                 'printer' => 'epsonqueue',
                                 'job' => 4,
                                 'pages' => 1
                                },
                                {
                                 '_table' => 'printers_pages',
                                 'timestamp' => '15/Jul/2010 17:14:42 +0200',
                                 'printer' => 'hpqueue',
                                 'job' => 3,
                                 'pages' => 1
                                },

                                {
                                 '_table' => 'printers_pages',
                                 'printer' => 'epsonqueue',
                                 'timestamp' => '15/Jul/2010 17:38:14 +0200',
                                 'job' => 4,
                                 'pages' => 1
                                },
                                {
                                 '_table' => 'printers_pages',
                                 'timestamp' => '15/Jul/2010 17:38:50 +0200',
                                 'printer' => 'epsonqueue',
                                 'job' => 4,
                                 'pages' => 1
                                },
                                {
                                 '_table' => 'printers_pages',
                                 'timestamp' => '15/Jul/2010 17:39:38 +0200',
                                 'printer' => 'epsonqueue',
                                 'job' => 4,
                                 'pages' => 2
                                },
                               ],

             },


             {
              name => 'error_log file',
              file  => '/var/log/cups/error_log',
              lines => [
'I [15/Jul/2010:18:03:59 +0200] Listening to 0.0.0.0:631 (IPv4)',
'I [15/Jul/2010:18:03:59 +0200] Listening to :::631 (IPv6)',
'I [15/Jul/2010:18:03:59 +0200] Listening to /var/run/cups/cups.sock (Domain)',
q{W [15/Jul/2010:18:03:59 +0200] No limit for CUPS-Get-Document defined in policy default - using Send-Document's policy},
'I [15/Jul/2010:18:03:59 +0200] Remote access is enabled.',
'I [15/Jul/2010:18:03:59 +0200] Loaded configuration file "/etc/cups/cupsd.conf"',
'I [15/Jul/2010:18:03:59 +0200] Using default TempDir of /var/spool/cups/tmp...',
'I [15/Jul/2010:18:03:59 +0200] Configured for up to 100 clients.',
'I [15/Jul/2010:18:03:59 +0200] Allowing up to 100 client connections per host.',
'I [15/Jul/2010:18:03:59 +0200] Using policy "default" as the default!',
'I [15/Jul/2010:18:03:59 +0200] Full reload is required.',
'I [15/Jul/2010:18:03:59 +0200] Loaded MIME database from "/usr/share/cups/mime" and "/etc/cups": 37 types, 74 filters...',
'I [15/Jul/2010:18:03:59 +0200] Loading job cache file "/var/cache/cups/job.cache"...',
'I [15/Jul/2010:18:03:59 +0200] Full reload complete.',
'I [15/Jul/2010:18:03:59 +0200] Cleaning out old temporary files in "/var/spool/cups/tmp"...',
'E [15/Jul/2010:18:03:59 +0200] Unable to bind socket for address 0.0.0.0:631 - Address already in use.',
'I [15/Jul/2010:18:16:21 +0200] [Job 9] Queued on "hpqueue" by "user".',
'I [15/Jul/2010:18:17:29 +0200] [Job 9] Canceled by "user".',
'D [15/Jul/2010:18:36:21 +0200] add_job: requesting-user-name="user"',
'I [15/Jul/2010:18:36:21 +0200] [Job 11] Adding start banner page "none".',
'D [15/Jul/2010:18:36:21 +0200] Discarding unused job-created event...',
'I [15/Jul/2010:18:36:21 +0200] [Job 11] Queued on "hpqueue" by "user".',
'I [15/Jul/2010:18:38:54 +0200] [Job 11] ready to print',
'D [15/Jul/2010:18:38:54 +0200] Discarding unused printer-state-changed event...',
'D [15/Jul/2010:18:38:54 +0200] Discarding unused job-progress event...',
'D [15/Jul/2010:18:38:54 +0200] PID 8018 (/usr/lib/cups/backend/hp) exited with no errors.',
'D [15/Jul/2010:18:38:54 +0200] Discarding unused job-completed event...',
'I [15/Jul/2010:18:38:54 +0200] [Job 11] Job completed.',

                       ],
              expectedData =>  [
                                {
                                 '_table' => 'printers_jobs',
                                 timestamp => '15/Jul/2010 18:16:21 +0200',
                                 job      => 9,
                                 printer => 'hpqueue',
                                 username => 'user',
                                 event => 'queued',

                                },

                                {
                                 '_table' => 'printers_jobs',
                                 timestamp => '15/Jul/2010 18:17:29 +0200',
                                 job      => 9,
                                 printer => 'hpqueue',
                                 username => 'user',
                                 event => 'canceled',

                                },

                                {
                                 '_table' => 'printers_jobs',
                                 timestamp => '15/Jul/2010 18:36:21 +0200',
                                 job      => 11,
                                 printer => 'hpqueue',
                                 username => 'user',
                                 event => 'queued',

                                },

                               {
                                 '_table' => 'printers_jobs',
                                 timestamp => '15/Jul/2010 18:38:54 +0200',
                                 job      => 11,
                                 printer => 'hpqueue',
                                 username => 'user',
                                 event => 'completed',

                                },


                               ],

             },

            );


my $logHelper = new EBox::Printers::LogHelper();

foreach my $case (@cases) {
    diag $case->{name};

    my @lines = @{ $case->{lines} };

    my $dbEngine = newFakeDBEngine();
    lives_ok {
        foreach my $line (@lines) {
            $logHelper->processLine($case->{file}, $line, $dbEngine);
        }
    } 'processing lines';

    checkInsert($dbEngine,$case->{expectedData});
}

1;
