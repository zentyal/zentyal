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

package EBox::Squid::Test;

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

sub squid_use_ok : Test(startup => 1)
{
    use_ok('EBox::Squid') or die;
}

sub setUpInstance : Test(setup)
{
    my ($self) = @_;
    my $redis = EBox::Test::RedisMock->new();
    $self->{mod} = EBox::Squid->_create(redis => $redis);
}

sub test_isa_ok : Test
{
    my ($self) = @_;
    isa_ok($self->{mod}, 'EBox::Squid');
}

sub test_proxy_transparent_filter_https : Test(4)
{
    my ($self) = @_;

    cmp_ok($self->{mod}->_proxy_transparent_filter_https(), '==', 1, 'default value is true');
    {
        my $fakedConfig = new Test::MockModule('EBox::Config');
        $fakedConfig->mock('configkey', 'tralala');
        cmp_ok($self->{mod}->_proxy_transparent_filter_https(), '==', 1, 'invalid conf key, use default true');
        $fakedConfig->mock('configkey', 'yes');
        cmp_ok($self->{mod}->_proxy_transparent_filter_https(), '==', 1, 'valid conf key');
        $fakedConfig->mock('configkey', 'no');
        cmp_ok($self->{mod}->_proxy_transparent_filter_https(), '==', 0, 'valid conf key');
    }

}

1;

END {
    EBox::Squid::Test->runtests();
}
