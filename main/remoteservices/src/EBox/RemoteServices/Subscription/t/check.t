#!/usr/bin/perl -w

# Copyright (C) 2012-2013 Zentyal S.L.
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

# A module to test the <EBox::RemoteServices::Subscription::Check> class

use strict;
use warnings;

use EBox::Global::TestStub;
use EBox::TestStubs;
use Test::More tests => 36;

BEGIN {
    diag('A unit test for EBox::RemoteServices::Subscription::Check');
    use_ok('EBox::RemoteServices::Subscription::Check')
      or die;
}

EBox::Global::TestStub::fake();

my $checker = new EBox::RemoteServices::Subscription::Check();
isa_ok($checker, 'EBox::RemoteServices::Subscription::Check');

# Test: Mail module enabled
# Fake mail module
EBox::TestStubs::fakeModule(
    name => 'mail',
    subs => [ 'isEnabled' => sub { return 1; } ]);

cmp_ok($checker->check('sb', 0), '==', 0, 'Mail module cannot be enabled with SB');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('sb', 1),
   'Mail module can be enabled with SB edition with Communications add-on');
is($checker->lastError(), undef, 'There is nothing in last error');

ok($checker->check('enterprise'),
   'Mail module can be enabled with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# Un-fake mail module
EBox::TestStubs::fakeModule(
    name => 'mail',
    subs => [ 'isEnabled' => sub { return 0; } ]);

# Test: Nusers > 25 in master mode
EBox::TestStubs::fakeModule(
    name => 'users',
    subs => [ 'isEnabled' => sub { return 1; },
              'master'    => sub { return 'none' },
              'realUsers' => sub { return [ ('user') x 26 ]; } ]);

cmp_ok($checker->check('sb', 0), '==', 0, 'SB edition cannot have more than 25 users in master mode');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

cmp_ok($checker->check('sb', 1), '==', 0, 'SB edition cannot have more than 25 users in master mode even with Communications Add-On');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('enterprise'),
   '> 25 users in master mode with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# Test: Nusers > 25 in zentyal cloud slave mode
EBox::TestStubs::fakeModule(
    name => 'users',
    subs => [ 'isEnabled' => sub { return 1; },
              'master'    => sub { return 'cloud' },
              'realUsers' => sub { return [ ('user') x 26 ]; } ]);
cmp_ok($checker->check('sb', 0), '==', 0, 'SB edition cannot have more than 25 users in Zentyal Cloud slave mode');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

cmp_ok($checker->check('sb', 1), '==', 0, 'SB edition cannot have more than 25 users in Zentyal Cloud slave mode even with Communications Add-On');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('enterprise'),
   '> 25 users in Zentyal Cloud with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# Test: Nusers > 25 in zentyal slave mode
EBox::TestStubs::fakeModule(
    name => 'users',
    subs => [ 'isEnabled' => sub { return 1; },
              'master'    => sub { return 'zentyal' },
              'realUsers' => sub { return [ ('user') x 26 ]; } ]);
ok($checker->check('sb', 0), 'SB edition can have more than 25 users in Zentyal slave mode');
is($checker->lastError(), undef, 'There is nothing in last error');

ok($checker->check('enterprise'),
   '> 25 users in Zentyal slave mode with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# Test: n slaves > 0 without master
EBox::TestStubs::fakeModule(
    name => 'users',
    subs => [ 'isEnabled' => sub { return 1; },
              'master'    => sub { return 'none' },
              'realUsers' => sub { return [ ('user') x 20 ]; },
              'slaves'    => sub { return [ 'slave1', 'slave2' ] }]);
cmp_ok($checker->check('sb', 0), '==', 0, 'SB edition cannot have Zentyal slaves without master');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('enterprise'),
   'Enterprise edition can have slaves');
is($checker->lastError(), undef, 'There is nothing in last error');

# Test: n slaves > 0 with Zentyal Cloud as slave
EBox::TestStubs::fakeModule(
    name => 'users',
    subs => [ 'isEnabled' => sub { return 1; },
              'master'    => sub { return 'cloud' },
              'realUsers' => sub { return [ ('user') x 20 ]; },
              'slaves'    => sub { return [ 'cloud-slave1' ] } ]);
ok($checker->check('sb', 0), 'SB edition can have Zentyal Cloud as slave');
is($checker->lastError(), undef, 'There is nothing in last error');

ok($checker->check('enterprise'),
   'Enterprise edition can have slaves');
is($checker->lastError(), undef, 'There is nothing in last error');

EBox::TestStubs::fakeModule(
    name => 'users',
    subs => [ 'isEnabled' => sub { return 1; },
              'master'    => sub { return 'cloud' },
              'realUsers' => sub { return [ ('user') x 20 ]; },
              'slaves'    => sub { return [ 'cloud-slave1', 'slave1' ] } ]);
cmp_ok($checker->check('sb', 0), '==', 0, 'SB edition cannot have Zentyal slaves having cloud as master');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('enterprise'),
   'Enterprise edition can have slaves');
is($checker->lastError(), undef, 'There is nothing in last error');

1;
