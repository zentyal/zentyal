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

package EBox::FirewallLogHelper::Test;

use base 'Test::Class';

use Test::More tests => 16;
use Test::MockObject;
use Test::Exception;
use Test::Differences;
use POSIX qw/strftime/;

sub setUpDBEngine : Test(startup)
{
    my ($self) = @_;
    my $dbEngine = Test::MockObject->new();
    $dbEngine->{lastInsert} = undef;
    $dbEngine->mock('insert' => sub { my ($self, $table, $data) = @_;
                                      $self->{table} = $table;
                                      $self->{lastInsert} = $data;
                                  });
    $dbEngine->mock('_tmLastInsert' => sub { my ($self) = @_;
                                             return $self->{lastInsert};
                                         });
    $dbEngine->mock('_tmLastInsertTable' => sub { my ($self) = @_;
                                                  return $self->{table};
                                              });
    $dbEngine->mock('_tmClearLastInsert' => sub { my ($self) = @_;
                                              $self->{lastInsert} = undef;
                                              $self->{table}      = undef;
                                          });

    $self->{dbEngine} = $dbEngine;

}


sub test_log_helper_use_ok : Test(startup => 1)
{
    use_ok('EBox::FirewallLogHelper') or die;
}

sub setUpLogHelper : Test(setup)
{
    my ($self) = @_;

    $self->{logHelper} = EBox::FirewallLogHelper->new();
    $self->{year} = strftime('%Y', localtime());
}

sub test_drop : Test(6)
{
    my ($self) = @_;

    my @cases = (
        {
            line =>
              'Jan 25 11:14:44 macostaserver kernel: [2470652.110434] zentyal-firewall drop IN=eth1 OUT= MAC=ff:ff:ff:ff:ff:ff:40:4a:03:82:33:14:08:00 SRC=192.168.1.254 DST=192.168.1.255 LEN=72 TOS=0x00 PREC=0x00 TTL=1 ID=25998 PROTO=UDP SPT=520 DPT=520 LEN=52 MARK=0x1',
            expected => {
                timestamp => $self->{year}.'-01-25 11:14:44',
                event => 'drop',
                fw_in => 'eth1',
                fw_out => undef,
                fw_proto => 'UDP',
                fw_src => '192.168.1.254',
                fw_spt => 520,
                fw_dst => '192.168.1.255',
                fw_dpt => 520,
            },
            file => '/var/log/syslog',
        },
        {
            line =>
              'Jan 25 11:14:52 macostaserver kernel: [2470659.768645] zentyal-firewall drop IN=tap0 OUT= MAC= SRC=192.168.160.1 DST=192.168.160.255 LEN=271 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=UDP SPT=631 DPT=631 LEN=251 MARK=0x1',
            expected => {
                timestamp => $self->{year}.'-01-25 11:14:52',
                event => 'drop',
                fw_in => 'tap0',
                fw_out => undef,
                fw_proto => 'UDP',
                fw_src => '192.168.160.1',
                fw_spt => 631,
                fw_dst => '192.168.160.255',
                fw_dpt => 631,
            },
            file => '/var/log/syslog',
        }
       );
    $self->_testCases(\@cases);
}

sub test_redirect : Test(6)
{
    my ($self) = @_;

    my @cases = (
        {
            line => 'Sep 10 17:54:12 macostaserver kernel: [913784.855409] zentyal-firewall redirect IN=eth0 OUT=eth2 MAC=aa:ed:fc:ec:88:41:00:20:6f:1f:c0:41:08:00 SRC=77.163.8.2 DST=172.31.3.1 LEN=64 TOS=0x00 PREC=0x00 TTL=56 ID=13836 DF PROTO=TCP SPT=54669 DPT=443 WINDOW=65535 RES=0x00 SYN URGP=0 MARK=0x1',
            expected => {
                timestamp => $self->{year}.'-09-10 17:54:12',
                event     => 'redirect',
                fw_in     => 'eth0',
                fw_out    => 'eth2',
                fw_proto  => 'TCP',
                fw_src    => '77.163.8.2',
                fw_spt    => 54669,
                fw_dst    => '172.31.3.1',
                fw_dpt    => 443,
            },
            file => '/var/log/syslog',
        },
        {
            line => 'Sep 10 17:56:48 macostaserver kernel: [913940.939865] zentyal-firewall redirect IN=eth0 OUT=eth1 MAC=ad:ac:ef:ed:98:42:00:10:6f:1f:c0:41:08:00 SRC=77.74.9.6 DST=172.16.21.42 LEN=60 TOS=0x00 PREC=0x00 TTL=54 ID=26544 DF PROTO=TCP SPT=34571 DPT=80 WINDOW=5840 RES=0x00 SYN URGP=0 MARK=0x1',
            expected => {
                timestamp => $self->{year}.'-09-10 17:56:48',
                event     => 'redirect',
                fw_in     => 'eth0',
                fw_out    => 'eth1',
                fw_proto  => 'TCP',
                fw_src    => '77.74.9.6',
                fw_spt    => 34571,
                fw_dst    => '172.16.21.42',
                fw_dpt    => 80,
            },
            file => '/var/log/syslog',
        },

       );
    $self->_testCases(\@cases);
}

sub test_log : Test(3)
{
    my ($self) = @_;

    my @cases = (
        {
            line => 'Sep 12 16:25:11 macostaserver kernel: [ 1661.128397] zentyal-firewall log IN=eth1 OUT= MAC=08:00:27:ee:e4:79:0a:00:27:00:00:00:08:00 SRC=192.168.56.1 DST=192.168.56.101 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=63662 DF PROTO=TCP SPT=38115 DPT=22 WINDOW=14600 RES=0x00 SYN URGP=0 MARK=0x10001',
            expected => {
                timestamp => $self->{year}.'-09-12 16:25:11',
                event     => 'log',
                fw_in     => 'eth1',
                fw_out    => undef,
                fw_proto  => 'TCP',
                fw_src    => '192.168.56.1',
                fw_spt    => 38115,
                fw_dst    => '192.168.56.101',
                fw_dpt    => 22,
            },
            file => '/var/log/syslog',
        },
       );
    $self->_testCases(\@cases);
}

sub _testCases
{
    my ($self, $cases) =  @_;

    foreach my $case (@{$cases}) {
        my $line = $case->{line};
        my $msg = "Test for line $line";
        $self->{dbEngine}->_tmClearLastInsert();

        lives_ok {
            local $SIG{__WARN__} = sub { die @_ };  # die on warnings we don't want
                                                # bad interpolation when parsing lines
            $self->{logHelper}->processLine($case->{file}, $line, $self->{dbEngine});
        } $msg;
        if ($@) {
            is($self->{dbEngine}->{lastInsert}, undef, 'Check that not data was inserted on failure');
            skip(1, "No need to check last table for insertion");
        } else {
            is($self->{dbEngine}->_tmLastInsertTable, 'firewall', 'Check last insert table');
            eq_or_diff($self->{dbEngine}->_tmLastInsert(), $case->{expected}, 'Check inserted data');
        }
    }
}


1;

END {
    EBox::FirewallLogHelper::Test->runtests();
}

