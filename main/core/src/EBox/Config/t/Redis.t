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

use strict;
use warnings;

use Test::More tests => 8;

use lib '../../..';

use EBox::TestStub;
use EBox::Config::Redis;
use EBox::Test::RedisMock;

EBox::TestStub::fake();
my $redisMock = EBox::Test::RedisMock->new();

$redisMock->set('foo', 5);
$redisMock->set('bar', 'this is a string');
is ($redisMock->get('foo'), 5);
is ($redisMock->get('bar'), 'this is a string');

my $redis = EBox::Config::Redis->instance(customRedis => $redisMock);

$redis->{redis}->__send_command('set', 'raw-foo', 'rawvalue');
$redis->{redis}->__send_command('get', 'raw-foo');
is ($redis->{redis}->__read_response(), 'rawvalue');

$redis->_redis_call('set', 'raw-bar', 666);
is ($redis->_redis_call('get', 'raw-bar'), 666);

is ($redis->get('unexistent'), undef);

$redis->set('foo', 5);

$redis->set('bar', 'this is a string');

is ($redis->get('foo'), 5);

$redis->unset('foo');

is ($redis->get('foo'), undef);
is ($redis->get('bar'), 'this is a string');

1;
