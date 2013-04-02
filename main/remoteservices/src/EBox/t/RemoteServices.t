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

use EBox::Global::TestStub;
use Test::Exception;
use Test::More tests => 3;
use POSIX;

# use lib '../../..';

EBox::Global::TestStub::fake();

use_ok('EBox::RemoteServices') or die;

my $rsMod = EBox::Global->modInstance('remoteservices');
isa_ok($rsMod, 'EBox::RemoteServices');

# Security updates last time tests
subtest 'security updates time' => sub {
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
};

1;
