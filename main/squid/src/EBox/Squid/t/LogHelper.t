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

package EBox::Squid::LogHelper::Test;

use base 'Test::Class';

use Test::Differences;
use Test::Exception;
use Test::MockObject;
use Test::More;

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
    use_ok('EBox::Squid::LogHelper') or die;
}

sub setUpLogHelper : Test(setup)
{
    my ($self) = @_;

    $self->{logHelper} = new EBox::Squid::LogHelper();
}

sub test_domain_name : Test(4)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'Test domain name',
            file => '/var/log/squid3/external-access.log',
            line => '1372580242.251      0 192.168.100.3 TCP_MEM_HIT/200 1516 GET http://db.local.clamav.net/daily-17404.cdiff - NONE/- text/plain',
            expected => undef,
        },
        {
            name => 'Test domain name',
            file => '/var/log/squid3/access.log',
            line => '1372580242.651      0 192.168.100.3 TCP_MEM_HIT/200 1516 GET http://db.local.clamav.net/daily-17404.cdiff - FIRST_UP_PARENT/localhost text/plain',
            expected => {
                bytes  => 1516,  code      => 'TCP_MEM_HIT/200',     elapsed     => 0, event => 'accepted',
                method => 'GET', mimetype  => 'text/plain',          remotehost  => '192.168.100.3',
                rfc931 => '-',   timestamp => '2013-06-30 10:17:22', peer => 'NONE/-',
                url    => 'http://db.local.clamav.net/daily-17404.cdiff',
                domain => 'local.clamav.net',
            },
        },
       );
    $self->_testCases(\@cases);
}


sub test_ip_addr_domain : Test(8)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'IPv4 domain',
            file => '/var/log/squid3/access.log',
            line => '1372578572.975    233 192.168.100.3 TCP_MISS/304 398 GET http://131.12.32.1/ubuntu/dists/precise/Release - FIRST_UP_PARENT/localhost -',
            expected => undef,
        },
        {
            name => 'IPv4 domain',
            file => '/var/log/squid3/external-access.log',
            line => '1372578573.235    233 192.168.100.3 TCP_MISS/304 398 GET http://131.12.32.1/ubuntu/dists/precise/Release - DIRECT/91.189.91.15 -',
            expected => {
                bytes  => 398,   code      => 'TCP_MISS/304', elapsed     => 233, event => 'accepted',
                method => 'GET', mimetype  => '-',            remotehost  => '192.168.100.3',
                rfc931 => '-',   timestamp => '2013-06-30 09:49:33', peer => 'DIRECT/91.189.91.15',
                url    => 'http://131.12.32.1/ubuntu/dists/precise/Release',
                domain => '131.12.32.1',
            },
        },
        {
            name => 'IPv6 domain',
            file => '/var/log/squid3/external-access.log',
            line => '1372580239.517    108 192.168.100.21 TCP_MISS/200 427 GET http://[2001:db8:85a3::8a2e:370:7334]/nic/checkip - DIRECT/194.245.148.135 text/html',
            expected => undef,
        },
        {
            name => 'IPv6 domain',
            file => '/var/log/squid3/access.log',
            line => '1372580239.947    108 192.168.100.21 TCP_MISS/200 427 GET http://[2001:db8:85a3::8a2e:370:7334]/nic/checkip user1 FIRST_UP_PARENT/localhost text/html',
            expected => {
                bytes  => 427,   code      => 'TCP_MISS/200', elapsed     => 108, event => 'accepted',
                method => 'GET', mimetype  => 'text/html',    remotehost  => '192.168.100.21',
                rfc931 => 'user1',   timestamp => '2013-06-30 10:17:19', peer => 'DIRECT/194.245.148.135',
                url    => 'http://[2001:db8:85a3::8a2e:370:7334]/nic/checkip',
                domain => '2001:db8:85a3::8a2e:370:7334',
            },
        },
       );
    $self->_testCases(\@cases);
}

sub tests_denied_by_internal : Test(8)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'Internal first',
            file => '/var/log/squid3/access.log',
            line => '1372578572.975    233 192.168.100.3 DENIED/XXX 398 GET http://foo.bar/foo user1 FIRST_UP_PARENT/localhost -',
            expected => undef,
        },
        {
            name => 'Internal first',
            file => '/var/log/squid3/external-access.log',
            line => '1372578572.575    233 192.168.100.3 TCP_MISS/304 398 GET http://foo.bar/foo - DIRECT/91.189.91.15 -',
            expected => {
                bytes  => 398,   code      => 'DENIED/XXX', elapsed     => 233, event => 'denied',
                method => 'GET', mimetype  => '-',            remotehost  => '192.168.100.3',
                rfc931 => 'user1',   timestamp => '2013-06-30 09:49:32', peer => 'DIRECT/91.189.91.15',
                url    => 'http://foo.bar/foo',
                domain => 'foo.bar',
            },
        },
        {
            name => 'External first',
            file => '/var/log/squid3/external-access.log',
            line => '1372578572.575    233 192.168.100.3 TCP_MISS/304 398 GET http://foo.bar/foo - DIRECT/91.189.91.15 -',
            expected => undef,
        },
        {
            name => 'External first',
            file => '/var/log/squid3/access.log',
            line => '1372578572.975    233 192.168.100.3 DENIED/XXX 398 GET http://foo.bar/foo user1 FIRST_UP_PARENT/localhost -',
            expected => {
                bytes  => 398,   code      => 'DENIED/XXX', elapsed     => 233, event => 'denied',
                method => 'GET', mimetype  => '-',            remotehost  => '192.168.100.3',
                rfc931 => 'user1',   timestamp => '2013-06-30 09:49:32', peer => 'DIRECT/91.189.91.15',
                url    => 'http://foo.bar/foo',
                domain => 'foo.bar',
            },
        }
    );
    $self->_testCases(\@cases);
}

sub _testCases
{
    my ($self, $cases) = @_;

    foreach my $case (@{$cases}) {
        $self->{dbEngine}->_tmClearLastInsert();
        lives_ok {
            $self->{logHelper}->processLine($case->{file}, $case->{line}, $self->{dbEngine});
        } $case->{name};
        if (defined($case->{expected})) {
            is($self->{dbEngine}->_tmLastInsertTable(), 'squid_access', 'Check last insert target table');
            eq_or_diff($self->{dbEngine}->_tmLastInsert(),
                       $case->{expected},
                       'Check the last inserted data is the expected one');
        }
    }
}

1;

END {
    EBox::Squid::LogHelper::Test->runtests();
}
