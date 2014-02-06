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
use Test::MockObject::Extends;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
    EBox::Config::TestStub::fake();
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
    # Mocking some methods :/ (no purist)
    $self->{mod} = new Test::MockObject::Extends($self->{mod});
    $self->{mod}->set_true('_createStoreAuthFile');
}

sub mock_file_slurp : Test(setup)
{
    my ($self) = @_;

    $self->{mock_file_slurp} = new Test::MockModule('File::Slurp');
    $self->{mock_file_slurp}->mock('read_file', 'bytes');
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
                             localNode => 1, nodeid => 1}],
                'auth'  => 'bytes',
               },
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
                    'nodes' => [{'name' => 'local', 'addr' => '10.1.1.0', 'webAdminPort' => 443, localNode => 1, nodeid => 1}],
                    'auth'  => 'bytes',
                   },
                   'Multicast configuration');
    }
}

sub test_update_cluster_configuration : Test(14)
{
    my ($self) = @_;

    my $mod = new Test::MockObject::Extends($self->{mod});
    $mod->set_true('_corosyncSetConf', 'saveConfig');
    $mod->set_false('_isDaemonRunning');

    $mod->set_false('clusterBootstraped');
    throws_ok {
        $mod->updateClusterConfiguration();
    } 'EBox::Exceptions::Internal', 'Update a non-bootstraped cluster';
    $mod->set_true('clusterBootstraped');

    # Test warns and name change
    {
        my ($called, $icalled) = (0, 0);
        my $fakedEBox = new Test::MockModule('EBox');
        $fakedEBox->mock('warn' => sub { $called++ },
                         'info' => sub { $icalled++ });
        $mod->set_state({cluster_conf => {transport => 'udpu', multicast => undef, nodes => {}}});
        lives_ok {
            $mod->updateClusterConfiguration(undef,
                                             {name => 'foo',
                                              transport => 'udp',
                                              multicastConf => {addr => '1.1.1.1'},
                                              nodes => []});
        } 'Updating cluster configuration';
        cmp_ok($called, '==', 1, 'Warning launched');
        cmp_ok($icalled, '==', 2, 'Info changing the names + params');
        lives_ok {
            $mod->updateClusterConfiguration(undef,
                                             {name => 'foobar',
                                              transport => 'udpu',
                                              multicastConf => {addr => '1.1.1.1'},
                                              nodes => []});
        } 'Updating cluster transport';
        cmp_ok($called, '==', 2, 'Warning launched');
        cmp_ok($mod->model('Cluster')->nameValue(), 'eq', 'foobar', 'Cluster name updated');
    }

    lives_ok {
        $mod->updateClusterConfiguration(undef,
                                         {name => 'foo',
                                          transport => 'udpu',
                                          multicastConf => {},
                                          nodes => [
                                              {addr => '1.1.1.1', name => 'new', nodeid => 1, webAdminPort => 443}
                                             ]});
    } 'Add a new node';
    cmp_deeply($mod->clusterConfiguration()->{nodes}, [{addr => '1.1.1.1', name => 'new', nodeid => 1,
                                                        webAdminPort => 443, localNode => 0}]);
    lives_ok {
        $mod->updateClusterConfiguration(undef,
                                         {name => 'foo',
                                          transport => 'udpu',
                                          multicastConf => {},
                                          nodes => [
                                              {addr => '1.1.1.1', name => 'new', nodeid => 1, webAdminPort => 443},
                                              {addr => '1.1.1.2', name => 'new2', nodeid => 2, webAdminPort => 443}

                                             ]});
    } 'Add another node';
    cmp_ok(scalar(@{$mod->clusterConfiguration()->{nodes}}), '==', 2);
    lives_ok {
        $mod->updateClusterConfiguration(undef,
                                         {name => 'foo',
                                          transport => 'udpu',
                                          multicastConf => {},
                                          nodes => [
                                              {addr => '1.1.1.3', name => 'new', nodeid => 1, webAdminPort => 443},
                                              {addr => '1.1.1.2', name => 'new2', nodeid => 2, webAdminPort => 443}

                                             ]});
    } 'Update a node';

    lives_ok {
        $mod->updateClusterConfiguration(undef,
                                         {name => 'foo',
                                          transport => 'udpu',
                                          multicastConf => {},
                                          nodes => [
                                              {addr => '1.1.1.3', name => 'new', nodeid => 1, webAdminPort => 443},

                                             ]});
    } 'Remove a node';
    cmp_deeply($mod->clusterConfiguration()->{nodes}, [{addr => '1.1.1.3', name => 'new', nodeid => 1,
                                                        webAdminPort => 443, localNode => 0}]);

}

sub test_add_node : Test(7)
{
    my ($self) = @_;

    my $mod = $self->{mod};

    throws_ok {
        $mod->addNode();
    } 'EBox::Exceptions::MissingArgument', 'Missing arguments to add a node';

    throws_ok {
        $mod->addNode({name => 'foo', addr => '1.1.1.1'});
    } 'EBox::Exceptions::MissingArgument', 'Missing webAdminPort argument to add a node';

    throws_ok {
        $mod->addNode({name => '-foo', addr => '1.1.1.1', webAdminPort => 332});
    } 'EBox::Exceptions::InvalidData', 'Invalid node name';

    throws_ok {
        $mod->addNode({name => 'foo', addr => 'ad', webAdminPort => 332});
    } 'EBox::Exceptions::InvalidData', 'Invalid node addr';

    throws_ok {
        $mod->addNode({name => 'foo', addr => '1.1.1.1', webAdminPort => 'a'});
    } 'EBox::Exceptions::InvalidData', 'Invalid node webadmin port';

    # Mocking to test real environment
    $mod->set_false('_corosyncSetConf', '_isDaemonRunning', '_notifyClusterConfChange', '_setNoQuorumPolicy');
    lives_ok {
        $mod->addNode({name => 'foo', addr => '1.1.1.1', webAdminPort => 443});
    } 'Adding a node';

    ok(scalar(grep { $_->{name} eq 'foo' } @{$mod->nodes()}), 'The node was added');

    $mod->unmock('_corosyncSetConf', '_isDaemonRunning', '_notifyClusterConfChange', '_setNoQuorumPolicy');
}

1;

END {
    EBox::HA::Test->runtests();
}
