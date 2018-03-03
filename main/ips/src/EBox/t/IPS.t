#!/usr/bin/perl -w
#
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

use warnings;
use strict;

package EBox::IPS::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use Test::Deep;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;
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

sub ips_use_ok : Test(startup => 1)
{
    use_ok('EBox::IPS') or die;
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    $self->{mod} = EBox::IPS->_create(redis => $redis);

}

sub test_isa_ok  : Test
{
    my ($self) = @_;
    isa_ok($self->{mod}, 'EBox::IPS');
}

sub test_notify_update : Test(10)
{
    my ($self) = @_;

    # Mock ips to run tests we need
    my $ips = new Test::MockObject::Extends($self->{mod});
    $ips->set_true( 'isEnabled', '_sendFailureEvent' );
    # Mock DB engine
    my $module = new Test::MockModule('EBox::DBEngineFactory');
    my $mockDB = new Test::MockObject();
    $mockDB->set_true('unbufferedInsert');
    $module->mock('DBEngine', $mockDB);

    # Notified failure on restarting
    $ips->set_false('isRunning');
    $ips->notifyUpdate();
    $ips->called_ok('_sendFailureEvent');
    $ips->clear();
    my ($name, $args) = $mockDB->next_call();
    $mockDB->clear();
    like($args->[2]->{failure_reason}, qr/changelog/, 'Expected this failure reason');
    cmp_ok($args->[2]->{event}, 'eq', 'failure', 'failure on running');

    # Notified success
    $ips->set_series('isRunning', [ 0, 0, 1 ]);
    $ips->notifyUpdate();
    ok( not($ips->called('_sentFailureEvent')), 'Not failure after 2 not running');
    $ips->clear(); # For next calls
    ($name, $args) = $mockDB->next_call();
    $mockDB->clear();
    cmp_ok($args->[2]->{event}, 'eq', 'success', 'success after 2 not running');
    cmp_ok($args->[2]->{failure_reason}, 'eq', '', 'No failure reason on success');

    # Notify a known failure
    $ips->notifyUpdate('reason');
    $ips->called_ok('_sendFailureEvent');
    ($name, $args) = $ips->next_call(2); # Skip isEnabled
    cmp_ok($args->[1], 'eq', 'reason', 'Failure event is sent using passed message');
    $ips->clear();
    ($name, $args) = $mockDB->next_call();
    $mockDB->clear();
    cmp_ok($args->[2]->{event}, 'eq', 'failure', 'Failure in known failure' );
    cmp_ok($args->[2]->{failure_reason}, 'eq', 'reason', 'Failure reason from arg');

}

sub test_rule_set : Test(6)
{
    my ($self) = @_;

    my $ips = $self->{mod};
    eq_deeply($ips->ASURuleSet(), []);
    lives_ok {
        $ips->setASURuleSet( [qw(aereogramme wood)]);
    } 'Setting ASU rule set';

    eq_deeply($ips->ASURuleSet(), [qw(aereogramme wood)]);
    cmp_ok($ips->usingASU(), '==', 1, 'Using ASU with this rule set');

    lives_ok {
        $ips->setASURuleSet([]);
    } 'Setting empty ASU rule set';
    cmp_ok($ips->usingASU(), '==', 0, 'Not using ASU anymore');

    lives_ok {
        $ips->setASURuleSet();
    } 'Setting undef ASU rule set';
    cmp_ok($ips->usingASU(), '==', 0, 'Not using ASU anymore with undef');
}

sub test_using_ASU : Test(5)
{
    my ($self) = @_;

    cmp_ok($self->{mod}->usingASU(), '==', 0, 'By default, not using ASU');
    lives_ok { $self->{mod}->usingASU(1) } 'Setting using ASU';
    cmp_ok($self->{mod}->usingASU(), '==', 1, 'Now using ASU');
    lives_ok { $self->{mod}->usingASU(0) } 'Unsetting using ASU';
    cmp_ok($self->{mod}->usingASU(), '==', 0, 'Not using ASU anymore');
}

sub test_fw_position : Test(4)
{
    my ($self) = @_;

    cmp_ok($self->{mod}->fwPosition(), 'eq', 'behind', 'default position is behind');
    {
        my $fakedConfig = new Test::MockModule('EBox::Config');
        $fakedConfig->mock('configkey', 'tralala');
        cmp_ok($self->{mod}->fwPosition(), 'eq', 'behind', 'invalid conf key, use default behind');
        $fakedConfig->mock('configkey', 'front');
        cmp_ok($self->{mod}->fwPosition(), 'eq', 'front', 'valid conf key');
        $fakedConfig->mock('configkey', 'behind');
        cmp_ok($self->{mod}->fwPosition(), 'eq', 'behind', 'valid conf key');
    }

}

1;


END {
    EBox::IPS::Test->runtests();
}

