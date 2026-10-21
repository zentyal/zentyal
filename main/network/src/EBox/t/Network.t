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

package EBox::Network::Test;

use base 'Test::Class';

use EBox::Test::RedisMock;
use EBox::Network::Model::GatewayTable;
use EBox::Network::FailoverChecker;

use Test::Exception;
use Test::More;

sub test_use_ok : Test(startup => 1)
{
    use_ok('EBox::Network') or die;
}

sub get_module : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    $self->{mod} = EBox::Network->_create(redis => $redis);
}

sub test_flag_if_up : Test(8)
{
    my ($self) = @_;

    my $mod = $self->{mod};

    is($mod->flagIfUp(), undef, 'No flag at init');
    lives_ok { $mod->unsetFlagIfUp() } 'No problem at not deleting the flag';
    lives_ok { $mod->_flagIfUp([]) } 'No ifaces to set up';
    is($mod->flagIfUp(), undef, 'No flag yet');
    lives_ok { $mod->_flagIfUp(['eth0']) } 'eth0 to set up';
    is_deeply($mod->flagIfUp(), ['eth0'], 'Flag is set correctly');
    lives_ok { $mod->unsetFlagIfUp() } 'No problem at deleting the flag';
    is($mod->flagIfUp(), undef, 'Flag has been unset correctly');
}

sub test_bond_mode : Test(6)
{
    my ($self) = @_;

    my $mod = $self->{mod};

    is(EBox::Network::DEFAULT_BOND_MODE(), 'balance-rr',
       'The default bonding mode is the kernel default');

    # A newly created bond always has a mode, so it can be written to netplan
    lives_ok { $mod->_createBond(0) } 'Creating a bond lives';
    is($mod->bondMode('bond0'), 'balance-rr',
       'A new bond gets the default bonding mode');

    lives_ok { $mod->setIfaceBondMode('bond0', '802.3ad') }
        'Setting a valid bonding mode lives';
    is($mod->bondMode('bond0'), '802.3ad', 'The bonding mode has been updated');

    throws_ok { $mod->setIfaceBondMode('bond0', 'not-a-mode') }
        'EBox::Exceptions::InvalidData', 'An invalid bonding mode is rejected';
}

sub test_failover_disabled_flag : Test(9)
{
    my ($self) = @_;

    my $mod = $self->{mod};

    is($mod->failoverDisabledGateway('gtw1'), undef, 'No flag at init');
    is($mod->failoverDisabledInitialized(), undef, 'Flags not initialized at init');
    lives_ok { $mod->setFailoverDisabledGateway('gtw1', 1) } 'Marking a gateway as failover disabled lives';
    is($mod->failoverDisabledGateway('gtw1'), 1, 'Gateway marked as failover disabled');
    is($mod->failoverDisabledGateway('gtw2'), undef, 'Other gateways are not marked');
    lives_ok { $mod->setFailoverDisabledInitialized() } 'Marking the flags as initialized lives';
    is($mod->failoverDisabledInitialized(), 1, 'Flags marked as initialized');
    lives_ok { $mod->setFailoverDisabledGateway('gtw1', 0) } 'Clearing the flag lives';
    ok(! $mod->failoverDisabledGateway('gtw1'), 'Flag has been cleared correctly');
}

sub test_gateway_marks : Test(8)
{
    my ($self) = @_;

    # stored marks are kept, even if the table order changes
    my $marks = EBox::Network::Model::GatewayTable::_marksForIds(
        { gtw26 => 1, gtw27 => 2, gtw30 => 3 },
        [qw(gtw30 gtw26 gtw27)]);
    is_deeply($marks, { gtw30 => 3, gtw26 => 1, gtw27 => 2 },
              'Stored marks do not change with the table order');

    # new gateways get the lowest free mark
    $marks = EBox::Network::Model::GatewayTable::_marksForIds(
        { gtw26 => 1, gtw27 => 2, gtw30 => 3 },
        [qw(gtw26 gtw27 gtw30 gtw31)]);
    is($marks->{gtw31}, 4, 'New gateway gets the next free mark');

    # marks of removed gateways are reused
    $marks = EBox::Network::Model::GatewayTable::_marksForIds(
        { gtw26 => 1, gtw30 => 3 },
        [qw(gtw26 gtw30 gtw31)]);
    is($marks->{gtw31}, 2, 'Freed marks are reused');

    # gateways without a stored mark (upgrade) get the lowest free marks
    $marks = EBox::Network::Model::GatewayTable::_marksForIds(
        {}, [qw(gtw26 gtw27)]);
    is_deeply($marks, { gtw26 => 1, gtw27 => 2 },
              'Gateways without a stored mark get the lowest free marks');

    # duplicated or out of range stored marks are reassigned
    $marks = EBox::Network::Model::GatewayTable::_marksForIds(
        { gtw26 => 2, gtw27 => 2, gtw30 => 300 },
        [qw(gtw26 gtw27 gtw30)]);
    is_deeply($marks, { gtw26 => 2, gtw27 => 1, gtw30 => 3 },
              'Duplicated and out of range marks are reassigned');

    is(EBox::Network::Model::GatewayTable::_lowestFreeMark({}), 1,
       'The lowest free mark is 1');
    is(EBox::Network::Model::GatewayTable::_lowestFreeMark({ 1 => 1, 2 => 1 }), 3,
       'The lowest free mark skips the used ones');
    my %allUsed = map { $_ => 1 } (1 .. 0xFF);
    throws_ok { EBox::Network::Model::GatewayTable::_lowestFreeMark(\%allUsed) }
        'EBox::Exceptions::External',
        'An error is thrown when there are no free marks';
}

sub test_failover_decisions : Test(9)
{
    my ($self) = @_;

    # gateway enablement
    is(EBox::Network::FailoverChecker::gatewayEnablement(1, 1, 0, 1), 0,
       'A gateway whose tests fail is disabled');
    is(EBox::Network::FailoverChecker::gatewayEnablement(0, 0, 1, 1), 1,
       'A recovered gateway disabled by the failover is enabled back');
    is(EBox::Network::FailoverChecker::gatewayEnablement(0, 0, 0, 1), 0,
       'A gateway disabled by the user stays disabled');
    is(EBox::Network::FailoverChecker::gatewayEnablement(0, 0, 0, 0), 1,
       'Disabled gateways are enabled back when the flags are not initialized');
    is(EBox::Network::FailoverChecker::gatewayEnablement(1, undef, 0, 1), 1,
       'A gateway without tests keeps its state');

    # test failure ratio
    ok(EBox::Network::FailoverChecker::testFailure(6, 6, 0.4),
       'All probes failed');
    ok(! EBox::Network::FailoverChecker::testFailure(1, 6, 0.4),
       'One failure out of six is below the required ratio');

    # route problems
    my ($problem) = EBox::Network::FailoverChecker::routeProblem('eth0', 0, 101, [], '');
    is($problem, 'interface eth0 is down',
       'A down interface is a route problem');
    ($problem) = EBox::Network::FailoverChecker::routeProblem('eth0', 1, 101, [], '');
    is($problem, 'there is no policy route for the gateway in table 101',
       'A missing policy route is a route problem');
}

1;

END {
    EBox::Network::Test->runtests();
}
