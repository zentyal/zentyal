#!/usr/bin/perl -w
#
# Copyright (C) 2014 Zentyal S.L.
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

use warnings;
use strict;

package EBox::HA::Test;

use base 'Test::Class';

use EBox::Config::TestStub;
use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use Test::Deep;
use Test::Exception;
use Test::MockModule;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(shutdown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub get_module : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    $self->{mod} = EBox::HA->_create(redis => $redis);
}

sub test_use_ok : Test(startup => 1)
{
    use_ok('EBox::HA') or die;
}

sub test_isa_ok : Test
{
    my ($self) = @_;

    isa_ok($self->{mod}, 'EBox::HA');
}

sub test_cluster_configuration : Test(5)
{
    my ($self) = @_;

    my $mod = $self->{mod};
    is_deeply($mod->clusterConfiguration(), {}, 'No configuration at startup');
    # Default unicast conf
    lives_ok {
        $mod->_bootstrap('10.1.1.0', 'local');
    } 'Bootstraping the cluster';
    cmp_deeply($mod->clusterConfiguration(),
               {'name' => 'my cluster',
                'transport' => 'udpu',
                'multicastConf' => {},
                'nodes' => [{'name' => 'local', 'addr' => '10.1.1.0', 'webAdminPort' => 443,
                             localNode => 1, nodeid => 1}]},
               'Default unicast configuration');

    {
        my $fakedConfig = new Test::MockModule('EBox::Config');
        $fakedConfig->mock('configkey', sub { if ($_[0] eq 'ha_multicast_addr') { '239.255.1.1' } elsif ($_[0] eq 'ha_multicast_port') { 5405 }});
        lives_ok {
            $mod->_bootstrap('10.1.1.0', 'local');
        } 'Bootstraping the cluster using multicast';
        cmp_deeply($mod->clusterConfiguration(),
                   {'name' => 'my cluster',
                    'transport' => 'udp',
                    'multicastConf' => { addr => '239.255.1.1', port => 5405, expected_votes => 1 },
                    'nodes' => [{'name' => 'local', 'addr' => '10.1.1.0', 'webAdminPort' => 443, localNode => 1, nodeid => 1}]},
                   'Multicast configuration');
    }
}

1;

END {
    EBox::HA::Test->runtests();
}
