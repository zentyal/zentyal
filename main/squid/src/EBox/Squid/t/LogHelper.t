# Copyright (C) 2013-2014 Zentyal S.L.
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

use EBox;
use EBox::Squid;
use EBox::Global::TestStub;
use base 'Test::Class';

use Test::Differences;
use Test::Exception;
use Test::MockModule;
use Test::MockObject;
use Test::More;

sub setUpEnviroment : Test(startup)
{
    EBox::Global::TestStub::fake();
    *EBox::Squid::filterNeeded = sub { return 1;};
}

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

sub test_domain_name : Test(5)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'Test domain name (external)',
            file => '/var/log/squid/external-access.log',
            line => '1372580242.251      0 192.168.100.3 TCP_MEM_HIT/200 1516 GET http://db.local.clamav.net/daily-17404.cdiff - NONE/- text/plain',
            expected => undef,
        },
        {
            name => 'Test domain name (dansguardian)',
            file => '/var/log/dansguardian/access.log',
            line => '1372580242.251      0 192.168.100.3 TCP_MEM_HIT/200 1516 GET http://db.local.clamav.net/daily-17404.cdiff - NONE/- text/plain',
            expected => undef,
        },
        {
            name => 'Test domain name (internal)',
            file => '/var/log/squid/access.log',
            line => '1372580242.651      0 192.168.100.3 TCP_MEM_HIT/200 1516 GET http://db.local.clamav.net/daily-17404.cdiff - FIRST_UP_PARENT/localhost text/plain',
            expected => {
                bytes  => 1516,  code      => 'TCP_MEM_HIT/200',     elapsed    => 0, event => 'accepted',
                method => 'GET', mimetype  => 'text/plain',          remotehost => '192.168.100.3',
                rfc931 => '-',   timestamp => '2013-06-30 10:17:22', peer => 'NONE/-',
                url    => 'http://db.local.clamav.net/daily-17404.cdiff',
                domain => 'local.clamav.net',
            },
        },
       );
    $self->_testCases(\@cases);
}


sub test_ip_addr_domain : Test(10)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'IPv4 domain (internal)',
            file => '/var/log/squid/access.log',
            line => '1372578572.975    233 192.168.100.3 TCP_MISS/304 398 GET http://131.12.32.1/ubuntu/dists/precise/Release - FIRST_UP_PARENT/localhost -',
            expected => undef,
        },
        {
            name => 'IPv4 domain (dansguardian)',
            file => '/var/log/dansguardian/access.log',
            line => '1372578572.975    233 192.168.100.3 TCP_MISS/304 398 GET http://131.12.32.1/ubuntu/dists/precise/Release - FIRST_UP_PARENT/localhost -',
            expected => undef,
        },
        {
            name => 'IPv4 domain (external)',
            file => '/var/log/squid/external-access.log',
            line => '1372578573.235    233 192.168.100.3 TCP_MISS/304 398 GET http://131.12.32.1/ubuntu/dists/precise/Release - DIRECT/91.189.91.15 -',
            expected => {
                bytes  => 398,   code      => 'TCP_MISS/304',        elapsed    => 233, event => 'accepted',
                method => 'GET', mimetype  => '-',                   remotehost => '192.168.100.3',
                rfc931 => '-',   timestamp => '2013-06-30 09:49:32', peer => 'FIRST_UP_PARENT/localhost',
                url    => 'http://131.12.32.1/ubuntu/dists/precise/Release',
                domain => '131.12.32.1',
            },
        },
        {
            name => 'IPv6 domain (external)',
            file => '/var/log/squid/external-access.log',
            line => '1372580239.517    108 192.168.100.21 TCP_MISS/200 427 GET http://[2001:db8:85a3::8a2e:370:7334]/nic/checkip - DIRECT/194.245.148.135 text/html',
            expected => undef,
        },
        {
            name => 'IPv6 domain (dansguardian)',
            file => '/var/log/dansguardian/access.log',
            line => '1372580239.517    108 192.168.100.21 TCP_MISS/200 427 GET http://[2001:db8:85a3::8a2e:370:7334]/nic/checkip - DIRECT/194.245.148.135 text/html',
            expected => undef,
        },
        {
            name => 'IPv6 domain (internal)',
            file => '/var/log/squid/access.log',
            line => '1372580239.947    108 192.168.100.21 TCP_MISS/200 427 GET http://[2001:db8:85a3::8a2e:370:7334]/nic/checkip user1 FIRST_UP_PARENT/localhost text/html',
            expected => {
                bytes  => 427,     code      => 'TCP_MISS/200',        elapsed    => 108, event => 'accepted',
                method => 'GET',   mimetype  => 'text/html',           remotehost => '192.168.100.21',
                rfc931 => 'user1', timestamp => '2013-06-30 10:17:19', peer => 'DIRECT/194.245.148.135',
                url    => 'http://[2001:db8:85a3::8a2e:370:7334]/nic/checkip',
                domain => '2001:db8:85a3::8a2e:370:7334',
            },
        },
       );
    $self->_testCases(\@cases);
}

sub tests_denied_by_internal : Test(6)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'Internal',
            file => '/var/log/squid/access.log',
            line => '1372578572.975    233 192.168.100.3 TCP_DENIED/403 398 GET http://foo.bar/foo user1 FIRST_UP_PARENT/localhost -',
            expected => {
                bytes  => 398,     code      => 'TCP_DENIED/403',      elapsed    => 233, event => 'denied',
                method => 'GET',   mimetype  => '-',                   remotehost => '192.168.100.3',
                rfc931 => 'user1', timestamp => '2013-06-30 09:49:32', peer => 'FIRST_UP_PARENT/localhost',
                url    => 'http://foo.bar/foo',
                domain => 'foo.bar',
            },
        },
        {
            name => 'Internal denied and aborted by client',
            file => '/var/log/squid/access.log',
            line => '1393495749.121     65 192.168.2.2 TCP_DENIED_ABORTED/403 16613 GET http://white.town.com/ - HIER_NONE/- text/html',
            expected => {
                bytes  => 16613,   code      => 'TCP_DENIED_ABORTED/403', elapsed    => 65, event => 'denied',
                method => 'GET',   mimetype  => 'text/html',              remotehost => '192.168.2.2',
                rfc931 => '-',     timestamp => '2014-02-27 11:09:09',    peer => 'HIER_NONE/-',
                url    => 'http://white.town.com/',
                domain => 'town.com',
            },
        },

    );
    $self->_testCases(\@cases);
}

sub tests_denied_by_auth : Test
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'Ignore auth required log entries',
            file => '/var/log/squid/access.log',
            line => '1379459436.444    235 10.0.2.15 TCP_DENIED/407 23342 GET http://www.foobar.com/ - NONE/- text/html',
            expected => undef,
        },
    );
    $self->_testCases(\@cases);
}


sub tests_filtered_by_dg : Test(10)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'Dansguardian (internal)',
            file => '/var/log/squid/access.log',
            line => '1372578572.575    233 192.168.100.3 TCP_MISS/200 398 GET http://foo.bar/foo - DEFAULT_PARENT/127.0.0.1 -',
            expected => undef,
        },
        {
            name => 'Dansguardian (external)',
            file => '/var/log/squid/external-access.log',
            line => '1372578572.575    233 192.168.100.3 TCP_MISS/200 398 GET http://foo.bar/foo - DEFAULT_PARENT/127.0.0.1 -',
            expected => undef,
        },
        {
            name => 'Dansguardian',
            file => '/var/log/dansguardian/access.log',
            line => '1372578572.575    233 192.168.100.3 TCP_DENIED/403 398 GET http://foo.bar/foo - DEFAULT_PARENT/127.0.0.1 -',
            expected => {
                bytes  => 398,   code      => 'TCP_DENIED/403',      elapsed    => 233, event => 'filtered',
                method => 'GET', mimetype  => '-',                   remotehost => '192.168.100.3',
                rfc931 => '-',   timestamp => '2013-06-30 09:49:32', peer => 'DEFAULT_PARENT/127.0.0.1',
                url    => 'http://foo.bar/foo',
                domain => 'foo.bar',
            },
        },
        {
            name => 'Dansguardian porn domain (external)',
            file => '/var/log/squid/external-access.log',
            line => '1379459436.795    217 10.0.2.15 TCP_MISS/200 10795 GET http://www.pornsite.com/ - DIRECT/88.208.24.43 text/html',
            expected => undef,
        },
        {
            name => 'Dansguardian porn domain (internal)',
            file => '/var/log/squid/access.log',
            line => '1379459436.823    375 10.0.2.15 TCP_MISS/200 23350 GET http://www.pornsite.com/ embrace@ZENTYAL-DOMAIN.LAN FIRST_UP_PARENT/localhost text/html',
            expected => undef,
        },
        {
            name => 'Dansguardian porn domain',
            file => '/var/log/dansguardian/access.log',
            line => '1379459436.811    234 10.0.2.15 TCP_DENIED/403 48740 GET http://www.pornsite.com embrace@zentyal-domain.lan DEFAULT_PARENT/127.0.0.1 text/html',
            expected => {
                bytes  => 10795,   code      => 'TCP_DENIED/403',      elapsed    => 234,
                event => 'filtered',
                method => 'GET', mimetype  => 'text/html',           remotehost => '10.0.2.15',
                rfc931 => 'embrace@ZENTYAL-DOMAIN.LAN',
                timestamp => '2013-09-18 01:10:36', peer => 'DEFAULT_PARENT/127.0.0.1',
                url    => 'http://www.pornsite.com/',
                domain => 'pornsite.com',
            },
        },
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
