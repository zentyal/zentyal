#!/usr/bin/perl -w

# Copyright (C) 2012-2013 eBox Technologies S.L.
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
use Test::More qw(no_plan);

BEGIN {
    diag('A unit test for EBox::RemoteServices::Subscription::Check');
    use_ok('EBox::RemoteServices::Subscription::Check')
      or die;
}

EBox::Global::TestStub::fake();

my $checker = new EBox::RemoteServices::Subscription::Check();
isa_ok($checker, 'EBox::RemoteServices::Subscription::Check');

# TODO: Test: Mail module enabled
cmp_ok($checker->check('sb', 0), '==', 0, 'Mail module cannot be enabled with SB');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('sb', 1),
   'Mail module can be enabled with SB edition with Communications add-on');
is($checker->lastError(), undef, 'There is nothing in last error');

ok($checker->check('enterprise'),
   'Mail module can be enabled with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# TODO: Test: Nusers > 25 in master mode
cmp_ok($checker->check('sb', 0), '==', 0, 'SB edition cannot have more than 25 users in master mode');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

cmp_ok($checker->check('sb', 1), '==', 0, 'SB edition cannot have more than 25 users in master mode even with Communications Add-On');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('enterprise'),
   '> 25 users in master mode with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# TODO: Test: Nusers > 25 in zentyal slave mode
cmp_ok($checker->check('sb', 0), '==', 0, 'SB edition cannot have more than 25 users in Zentyal Cloud slave mode');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

cmp_ok($checker->check('sb', 1), '==', 0, 'SB edition cannot have more than 25 users in Zentyal Cloud slave mode even with Communications Add-On');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('enterprise'),
   '> 25 users in Zentyal Cloud with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# TODO: Test: Nusers > 25 in zentyal slave mode
ok($checker->check('sb', 0), 'SB edition can have more than 25 users in Zentyal slave mode');
is($checker->lastError(), undef, 'There is nothing in last error');

ok($checker->check('enterprise'),
   '> 25 users in Zentyal slave mode with Enterprise edition');
is($checker->lastError(), undef, 'There is nothing in last error');

# TODO: Test: n slaves > 0
cmp_ok($checker->check('sb', 0), '==', 0, 'Not capable for SB edition');
ok($checker->lastError(), 'There is something in last error: ' . $checker->lastError() );

ok($checker->check('enterprise'),
   'Enterprise edition can have slaves');
is($checker->lastError(), undef, 'There is nothing in last error');

1;
