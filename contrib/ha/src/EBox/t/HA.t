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

use parent 'Test::Class';

use Data::Dumper;

use EBox::Config::TestStub;
use EBox::Global::TestStub;
use EBox::HA::NodeList;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use EBox::TestStubs;

use Test::Deep;
use Test::Exception;
use Test::MockModule;
use Test::MockObject::Extends;
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
    # Mocking some methods :/ (no purist)
    $self->{mod} = new Test::MockObject::Extends($self->{mod});
    $self->{mod}->set_true('_createStoreAuthFile');
    $self->{global} = EBox::Global->getInstance();
    # This is very nasty
    $self->{global}->{mod_instances_rw}->{ha} = $self->{mod};
}

sub mock_file_slurp : Test(setup)
{
    my ($self) = @_;

    $self->{mock_file_slurp} = new Test::MockModule('File::Slurp');
    $self->{mock_file_slurp}->mock('read_file', 'bytes');
}

sub mock_webadmin : Test(setup)
{
    my ($self) = @_;

    my $webAdminMod = $self->{global}->modInstance('webadmin');
    $webAdminMod = new Test::MockObject::Extends($webAdminMod);
    $webAdminMod->mock('listeningPort', sub { 443; });
    # This is very nasty
    $self->{global}->{mod_instances_rw}->{webadmin} = $webAdminMod;
}

sub mock_objects : Test(setup)
{
    my ($self) = @_;

    my $objectsMod = $self->{global}->modInstance('objects');
    $objectsMod = new Test::MockObject::Extends($objectsMod);
    $self->{objectsMod} = $objectsMod;
    $self->{global}->{mod_instances_rw}->{objects} = $objectsMod;
}

sub mock_firewall : Test(setup)
{
    my ($self) = @_;

    my $firewallMod = $self->{global}->modInstance('firewall');
    $firewallMod = new Test::MockObject::Extends($firewallMod);
    $self->{firewallMod} = $firewallMod;
    $self->{global}->{mod_instances_rw}->{firewall} = $firewallMod;
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

sub test_cluster_configuration : Test(6)
{
    my ($self) = @_;

    my $mod = $self->{mod};
    is_deeply($mod->clusterConfiguration(), {}, 'No configuration at startup');
    # Default unicast conf
    lives_ok {
        $mod->_bootstrap('10.1.1.0', 'local');
    } 'Bootstraping the cluster';


    # Testing firewall integration
    ok($self->{objectsMod}->objectExists('haNodes'), 'HA network objects created properly');

    # FIXME:
    #ok($mod->_firewallRuleCreated(), 'HA firewall rule created');

    cmp_deeply($mod->clusterConfiguration(),
               {'name' => 'my cluster',
                'transport' => 'udpu',
                'multicastConf' => {},
                'nodes' => [{'name' => 'local', 'addr' => '10.1.1.0', 'port' => 443,
                             localNode => 1, nodeid => 1}],
                'auth'  => 'Ynl0ZXM=',
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
                    'nodes' => [{'name' => 'local', 'addr' => '10.1.1.0', 'port' => 443, localNode => 1, nodeid => 1}],
                    'auth'  => 'Ynl0ZXM=',
                   },
                   'Multicast configuration');
    }
}

sub test_update_cluster_configuration : Test(20)
{
    my ($self) = @_;

    my $mod = $self->{mod};
    $mod->set_true('_corosyncSetConf', 'saveConfig');
    $mod->set_false('_isDaemonRunning');

    $mod->set_false('clusterBootstraped');
    throws_ok {
        $mod->updateClusterConfiguration();
    } 'EBox::Exceptions::Internal', 'Update a non-bootstraped cluster';
    $mod->set_true('clusterBootstraped');

    throws_ok { $mod->updateClusterConfiguration() } 'EBox::Exceptions::MissingArgument';
    throws_ok { $mod->updateClusterConfiguration(undef, {name => 'foo'}); } 'EBox::Exceptions::MissingArgument';
    throws_ok {
        $mod->updateClusterConfiguration(undef, {name => 'foo', transport => 'udp'});
    } 'EBox::Exceptions::MissingArgument';
    throws_ok {
        $mod->updateClusterConfiguration(undef, {name => 'foo', transport => 'udp', 'multicastConf' => undef});
    } 'EBox::Exceptions::MissingArgument';

    throws_ok {
        $mod->updateClusterConfiguration(undef, {name => 'ffo', transport => 'xcf', 'multicastConf' => undef, nodes => []});
    } 'EBox::Exceptions::InvalidData', 'Invalid transport parameter';


    my $localNode = {'name' => 'local', 'localNode' => 1, addr => '127.0.0.1', port => 443, nodeid => 1};
    $mod->set_state({cluster_conf => {transport => 'udpu', multicast => undef,
                                      nodes => { 'local' => $localNode }}});
    cmp_deeply($mod->get_state(), {cluster_conf => {transport => 'udpu', multicast => undef,
                                                    nodes => { 'local' => $localNode}}},
               'Sanity check');

    # Test warns and name change
    {
        my ($called, $icalled) = (0, 0);
        my $fakedEBox = new Test::MockModule('EBox');
        $fakedEBox->mock('warn'  => sub { $called++ },
                         'info'  => sub { $icalled++ });
        lives_ok {
            $mod->updateClusterConfiguration(undef,
                                             {name => 'foo',
                                              transport => 'udp',
                                              multicastConf => {addr => '1.1.1.1'},
                                              nodes => [$localNode]});
        } 'Updating cluster configuration';
        cmp_ok($called, '==', 1, 'Warning launched');
        cmp_ok($icalled, '==', 2, 'Info changing the names + params');
        lives_ok {
            $mod->updateClusterConfiguration(undef,
                                             {name => 'foobar',
                                              transport => 'udpu',
                                              multicastConf => {addr => '1.1.1.1'},
                                              nodes => [$localNode]});
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
                                              $localNode,
                                              {addr => '1.1.1.1', name => 'new', nodeid => 2, port => 443}
                                             ]});
    } 'Add a new node';

    cmp_bag($mod->clusterConfiguration()->{nodes},
            [$localNode,
             {addr => '1.1.1.1', name => 'new', nodeid => 2, port => 443, localNode => 0}]);
    lives_ok {
        $mod->updateClusterConfiguration(undef,
                                         {name => 'foo',
                                          transport => 'udpu',
                                          multicastConf => {},
                                          nodes => [
                                              $localNode,
                                              {addr => '1.1.1.1', name => 'new', nodeid => 2, port => 443},
                                              {addr => '1.1.1.2', name => 'new2', nodeid => 3, port => 443}

                                             ]});
    } 'Add another node';
    cmp_ok(scalar(@{$mod->clusterConfiguration()->{nodes}}), '==', 3);
    lives_ok {
        $mod->updateClusterConfiguration(undef,
                                         {name => 'foo',
                                          transport => 'udpu',
                                          multicastConf => {},
                                          nodes => [
                                              $localNode,
                                              {addr => '1.1.1.3', name => 'new', nodeid => 2, port => 443},
                                              {addr => '1.1.1.2', name => 'new2', nodeid => 3, port => 443}

                                             ]});
    } 'Update a node';

    lives_ok {
        $mod->updateClusterConfiguration(undef,
                                         {name => 'foo',
                                          transport => 'udpu',
                                          multicastConf => {},
                                          nodes => [
                                              $localNode,
                                              {addr => '1.1.1.3', name => 'new', nodeid => 2, port => 443},
                                             ]});
    } 'Remove a node';
    cmp_bag($mod->clusterConfiguration()->{nodes},
            [{addr => '1.1.1.3', name => 'new', nodeid => 2, port => 443, localNode => 0},
             $localNode]);

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
    } 'EBox::Exceptions::MissingArgument', 'Missing port argument to add a node';

    throws_ok {
        $mod->addNode({name => '-foo', addr => '1.1.1.1', port => 332});
    } 'EBox::Exceptions::InvalidData', 'Invalid node name';

    throws_ok {
        $mod->addNode({name => 'foo', addr => 'ad', port => 332});
    } 'EBox::Exceptions::InvalidData', 'Invalid node addr';

    throws_ok {
        $mod->addNode({name => 'foo', addr => '1.1.1.1', port => 'a'});
    } 'EBox::Exceptions::InvalidData', 'Invalid node webadmin port';

    # Mocking to test real environment
    $mod->set_false('_corosyncSetConf', '_isDaemonRunning', '_notifyClusterConfChange', '_setNoQuorumPolicy');
    lives_ok {
        $mod->addNode({name => 'foo', addr => '1.1.1.1', port => 443});
    } 'Adding a node';

    ok(scalar(grep { $_->{name} eq 'foo' } @{$mod->nodes()}), 'The node was added');

    $mod->unmock('_corosyncSetConf', '_isDaemonRunning', '_notifyClusterConfChange', '_setNoQuorumPolicy');
}

sub test_delete_node : Test(4)
{
    my ($self) = @_;
    my $mod = $self->{mod};

    throws_ok { $mod->deleteNode(); } 'EBox::Exceptions::MissingArgument';

    lives_ok { $mod->deleteNode({name => 'node'}); } 'Delete a non-existing node';

    # Mocking to test real environment
    $mod->set_false('_corosyncSetConf', '_isDaemonRunning', '_notifyClusterConfChange', '_setNoQuorumPolicy');
    lives_ok {
        $mod->addNode({name => 'foo', addr => '1.1.1.1', port => 443});
        $mod->deleteNode({name => 'foo'});
    } 'Adding and removing a node';

    cmp_ok(scalar(grep { $_->{name} eq 'foo' } @{$mod->nodes()}), '==', 0, 'The node was deleted');

    $mod->unmock('_corosyncSetConf', '_isDaemonRunning', '_notifyClusterConfChange', '_setNoQuorumPolicy');
}

sub test_admin_port_changed : Test(3)
{
    my ($self) = @_;
    my $mod = $self->{mod};

    $mod->set_true('isEnabled');
    $mod->set_false('_notifyClusterConfChange');
    # Set local node
    my $list = new EBox::HA::NodeList($mod);
    $list->set(localNode => 1, name => 'local', port => 443, addr => '1.1.1.1');

    lives_ok {
        $mod->adminPortChanged(443);
    } 'Do nothing if we are not changing the port';

    lives_ok {
        $mod->adminPortChanged(3443);
    } 'Change the admin port';
    cmp_deeply($list->localNode(),
               {'localNode' => 1, name => 'local', port => 3443, addr => '1.1.1.1', nodeid => 2},
               'The change is effective');

    $list->empty();
}

sub test_restart_required : Test(9)
{
    my ($self) = @_;

    my $mod = $self->{mod};
    $mod->set_true('isEnabled', 'isRunning');
    ok(not($mod->_restartRequired()), 'By default, restart is not required');

    $mod->{restart_required} = 1;
    ok($mod->_restartRequired(), 'Set restart required');
    ok(not(exists $mod->{restart_required}), 'Flag unset');

    ok($mod->_restartRequired(restartModules => 1), 'Restart from CLI');
    ok($mod->_restartRequired(restartUI => 1), 'Restart from GUI');

    my $state = $mod->get_state();
    $state->{replicating} = 1;
    $mod->set_state($state);
    ok(not($mod->_restartRequired()), 'Do not restart when replicating');
    delete $state->{replicating};

    $mod->set_false('enabled', 'isRunning');
    ok($mod->_restartRequired(), 'Restart required when the module is disabled');
    $mod->set_true('enabled');
    ok($mod->_restartRequired(), 'Restart required when the module is enabled and not running');
    $mod->set_true('isRunning');

    ok(not($mod->_restartRequired()), 'At the end, restart is not required');
}

1;

END {
    EBox::HA::Test->runtests();
}
