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

use EBox::Radius::LogHelper;

use Test::More qw(no_plan);
use Test::MockObject;
use Test::Exception;

#use EBox::TestStubs;

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

sub checkInsert
{
    my ($dbengine, $expectedData) = @_;

    my $data = delete $dbengine->{rows};
    if ($dumpInsertedData) {
        diag "Inserted Data:\n" . Dumper $data;
    }

    is_deeply $data, $expectedData, 'checking if inserted data is correct';
}

my @cases = (
             {
              name => 'login incorrect: user not found',
              file  => '/var/log/radius.log',
              lines => [
'Thu Oct 17 16:34:14 2013 : Auth: Login incorrect (  [ldap] User not found): [mateo] (from client 192.168.100.49/32 port 0 via TLS tunnel)',
'Thu Oct 17 16:34:14 2013 : Auth: Login incorrect: [mateo] (from client 192.168.100.49/32 port 37 cli a00bbae3beb8)',
                       ],
              expectedData =>  [
                                {
                                    'client' => '192.168.100.49/32',
                                    'timestamp' => '2013-10-17 16:34:14',
                                    '_table' => 'radius_auth',
                                    'mac' => '',
                                    'port' => '37',
                                    'event' => 'Login incorrect',
                                    'login' => 'mateo'
                                     },
                               ],
             },

             {
              name => 'login incorrect: unknown CA',
              file  => '/var/log/radius.log',
              lines => [
'Thu Oct 17 16:41:15 2013 : Error: TLS Alert read:fatal:unknown CA',
'Thu Oct 17 16:41:15 2013 : Error:     TLS_accept: failed in SSLv3 read client certificate A',
'Thu Oct 17 16:41:15 2013 : Error: rlm_eap: SSL error error:14094418:SSL routines:SSL3_READ_BYTES:tlsv1 alert unknown ca',
'Thu Oct 17 16:41:15 2013 : Error: SSL: SSL_read failed inside of TLS (-1), TLS session fails.',
'Thu Oct 17 16:41:15 2013 : Auth: Login incorrect (TLS Alert read:fatal:unknown CA): [mburillo] (from client 192.168.100.49/32 port 30 cli cc52af5db132)',
                       ],
              expectedData =>  [
                                {
                                    'client' => '192.168.100.49/32',
                                    'timestamp' => '2013-10-17 16:41:15',
                                    '_table' => 'radius_auth',
                                    'mac' => '',
                                    'port' => '30',
                                    'event' => 'Login incorrect',
                                    'login' => 'mburillo'
                                   }
                               ],

             },

             {
              name => 'bad password',
              file  => '/var/log/radius.log',
              lines => [
'Thu Oct 17 17:04:43 2013 : Auth: Login incorrect (  [ldap] Bind as user failed): [jjgarcia] (from client 192.168.100.49/32 port 0 via TLS tunnel)',
'Thu Oct 17 17:04:43 2013 : Auth: Login incorrect: [jjgarcia] (from client 192.168.100.49/32 port 2 cli c485085865bf)',
                       ],
              expectedData =>  [
                                {
                                    'client' => '192.168.100.49/32',
                                    'timestamp' => '2013-10-17 17:04:43',
                                    '_table' => 'radius_auth',
                                    'mac' => '',
                                    'port' => '2',
                                    'event' => 'Login incorrect',
                                    'login' => 'jjgarcia'
                                   },
                               ],
             },

             {
              name => 'login OK',
              file  => '/var/log/radius.log',
              lines => [
'Thu Oct 17 17:03:27 2013 : Auth: Login OK: [jjgarcia] (from client 192.168.100.49/32 port 0 via TLS tunnel)',
'Thu Oct 17 17:03:27 2013 : Auth: Login OK: [jjgarcia] (from client 192.168.100.49/32 port 2 cli c485085865bf)',
                       ],
              expectedData =>  [
                                {
                                    'client' => '192.168.100.49/32',
                                    'timestamp' => '2013-10-17 17:03:27',
                                    '_table' => 'radius_auth',
                                    'mac' => '',
                                    'port' => '2',
                                    'event' => 'Login OK',
                                    'login' => 'jjgarcia'
                                },
                               ],
             },


            );


my $logHelper = new EBox::Radius::LogHelper();

foreach my $case (@cases) {
    diag $case->{name};

    my @lines = @{ $case->{lines} };

    my $dbEngine = newFakeDBEngine();
    lives_ok {
        foreach my $line (@lines) {
            $logHelper->processLine($case->{file}, $line, $dbEngine);
        }
    } "processing lines for case " . $case->{name};

    checkInsert($dbEngine, $case->{expectedData});
}

1;
