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

package EBox::Reporter::Base::Test;

use base 'Test::Class';

use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;
use Test::MockModule;
use Test::MockObject;
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


sub set_up_mocks : Test(startup)
{
    my ($self) = @_;
    $self->{mod} = new Test::MockModule('EBox::DBEngineFactory');
    my $mockDB = new Test::MockObject();
    $mockDB->set_true('setTimezone');
    $self->{mod}->mock('DBEngine', $mockDB);

    $self->{sender} = new Test::MockModule('EBox::RemoteServices::Report');
    my $mockSender = new Test::MockObject();
    $self->{sender}->mock('new', $mockSender);
}

sub set_up_instance : Test(setup)
{
    my ($self) = @_;

    $self->{instance} = new EBox::Reporter::Base();
}

sub use_reporter_base_ok : Test(startup => 1)
{
    use_ok('EBox::Reporter::Base') or die;
}

sub test_isa_ok : Test
{
    my ($self) = @_;
    isa_ok($self->{instance}, 'EBox::Reporter::Base');
}

sub test_consolidate : Test(2)
{
    my ($self) = @_;

    my $reporter = new Test::MockObject::Extends($self->{instance});
    $reporter->set_always('_beginTime', time());
    my $isAnyToSend = $reporter->consolidate();
    ok( (not $isAnyToSend), 'Not data to send given the granularity');

    $reporter->set_always('_beginTime', time() - $reporter->_granularity());
    $reporter->set_false('_consolidate');
    ok($reporter->consolidate(), 'Data to send as the granularity is set');
}

sub test_granularity : Test
{
    my ($self) = @_;

    # Make sure the default granularity is always higher than reporterd interval
    cmp_ok($self->{instance}->_granularity(), '>=', 5 * 60);
}

1;

END {
    EBox::Reporter::Base::Test->runtests();
}
