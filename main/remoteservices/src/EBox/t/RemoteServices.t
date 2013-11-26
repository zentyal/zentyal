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

package EBox::RemoteServices::Test;

use base 'Test::Class';

use EBox::Config::TestStub;
use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use EBox::Test::RedisMock;
use Test::Exception;
use Test::MockObject::Extends;
use Test::More tests => 29;
use POSIX;

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
    $self->{rsMod} = EBox::RemoteServices->_create(redis => $redis);
}

sub use_remoteservices_ok : Test(startup => 1)
{
    use_ok('EBox::RemoteServices') or die;
}

sub test_use_ok : Test
{
    my ($self) = @_;

    isa_ok($self->{rsMod}, 'EBox::RemoteServices');
}

sub test_security_updates_time : Test(5)
{
    my ($self) = @_;

    my $rsMod = $self->{rsMod};
    cmp_ok($rsMod->latestSecurityUpdates(), 'eq', 'unknown');

    lives_ok {
        $rsMod->setSecurityUpdatesLastTime();
    } 'Set default security updates last time';
    cmp_ok($rsMod->latestSecurityUpdates(), 'eq', POSIX::strftime("%c", localtime()));

    my $when = time();
    lives_ok {
        $rsMod->setSecurityUpdatesLastTime($when);
    } 'Set custom security updates last time';
    cmp_ok($rsMod->latestSecurityUpdates(), 'eq', POSIX::strftime("%c", localtime($when)));
}

sub test_ensure_runnerd_running : Test(7)
{
    my ($self) = @_;

    my $rsMod = $self->{rsMod};
    ok((not $rsMod->runRunnerd()), 'Runnerd is not meant to be run without being registered');

    lives_ok {
        $rsMod->ensureRunnerdRunning(1);
    } 'Ensure runnerd daemon is running';

    ok($rsMod->runRunnerd(), 'Runnerd is meant to be run');

    lives_ok {
        $rsMod->ensureRunnerdRunning(0);
    } 'Ensure runnerd daemon is not running';

    ok((not $rsMod->runRunnerd()), 'Runnerd is not meant to be run without being registered');
    ok($rsMod->changed(), 'RS module has changed');

    my $mockedRSMod = new Test::MockObject::Extends($rsMod);
    $mockedRSMod->set_true('eBoxSubscribed');

    ok($mockedRSMod->runRunnerd(), 'Runnerd is always meant to be run being registered');
}

sub test_control_panel_url : Test(3)
{
    my ($self) = @_;

    my $rsMod = $self->{rsMod};
    cmp_ok($self->{rsMod}->controlPanelURL(), 'eq', 'https://remote.zentyal.com/',
           'Default value when not registered');

    my $mockedRSMod = new Test::MockObject::Extends($rsMod);
    $mockedRSMod->set_series('cloudDomain', 'foobar.org', 'cloud.zentyal.com');
    cmp_ok($mockedRSMod->controlPanelURL(), 'eq', 'https://www.foobar.org/',
           'Non-current production one');
    cmp_ok($mockedRSMod->controlPanelURL(), 'eq', 'https://remote.zentyal.com/',
           'Current production one');
}

sub test_ad_messages : Test(11)
{
    # It tests everything related to ad messages methods
    my ($self) = @_;

    my $rsMod = $self->{rsMod};
    is($rsMod->popAdMessage('tais-toi'), undef, 'No message with this name');
    cmp_ok($rsMod->adMessages()->{text}, 'eq', "", 'No ad messages');
    cmp_ok($rsMod->adMessages()->{name}, 'eq', 'remoteservices', 'The ad-message name');

    lives_ok { $rsMod->pushAdMessage('gas', 'drummers') } 'Pushing an ad message';
    lives_ok { $rsMod->pushAdMessage('miss', 'caffeina') } 'Pushing another message';
    like($rsMod->adMessages()->{text}, qr{drummers}, 'Ad messages');

    cmp_ok($rsMod->popAdMessage('gas'), 'eq', 'drummers', 'Pop a valid ad message');
    is($rsMod->popAdMessage('gas'), undef, 'You can only pop out once');

    lives_ok { $rsMod->pushAdMessage('back-to', 'decandence') } 'Pushing an ad message';
    lives_ok { $rsMod->pushAdMessage('back-to', 'uprising') } 'Overwritting an ad message';
    cmp_ok($rsMod->popAdMessage('back-to'), 'eq', 'uprising', 'Last one were updated');
}

sub test_check_ad_messages : Test
{
    my ($self) = @_;

    my $rsMod = $self->{rsMod};
    my $mockedRSMod = new Test::MockObject::Extends($rsMod);
    $mockedRSMod->set_true('eBoxSubscribed');
    $mockedRSMod->mock('addOnDetails', sub { {'max' => 232}});
    lives_ok { $mockedRSMod->checkAdMessages(); } 'Check ad messages';
}

1;

END {
    EBox::RemoteServices::Test->runtests();
}
