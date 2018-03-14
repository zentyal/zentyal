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

