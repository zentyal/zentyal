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

package EBox::Util::Lock::Test;

use base 'Test::Class';

use EBox::Config::TestStub;
use EBox::Global::TestStub;
use Test::Exception;
use Test::More;
use Test::SharedFork;

sub setUpConfiguration : Test(startup)
{
    EBox::Global::TestStub::fake();
    EBox::Config::TestStub::fake(tmp => '/tmp/');
}

sub advlock_use_ok : Test(startup => 1)
{
    use_ok('EBox::Util::Lock') or die;
}

sub test_non_blocking_lock_one : Test(3)
{
    lives_ok {
        EBox::Util::Lock::lock('foobar');
    } 'Non-blocking lock';

    lives_ok {
        EBox::Util::Lock::unlock('foobar');
    } 'Non-blocking unlock';

    lives_ok {
        EBox::Util::Lock::unlock('foobar');
    } 'Unlock something that does not exist more';
}

sub test_blocking_lock_one : Test(2)
{
    lives_ok {
        EBox::Util::Lock::lock('foobar', 1);
    } 'Non-blocking lock';

    lives_ok {
        EBox::Util::Lock::unlock('foobar');
    } 'Non-blocking unlock';
}

sub test_non_blocking_lock_two : Test(2)
{
    my $pid = fork();
    if ($pid == 0) {
        # Child code
        sleep(1);
        throws_ok {
            EBox::Util::Lock::lock('nonblock');  # It dies
        } 'EBox::Exceptions::Lock', 'Locked by parent';
        exit(0);
    }

    lives_ok {
        EBox::Util::Lock::lock('nonblock');
    } 'Non-blocking lock got by parent';
    waitpid($pid, 0);
    EBox::Util::Lock::unlock('nonblock');
}

sub test_blocking_without_time : Test(3)
{
    my $pid = fork();
    if ($pid == 0) {
        # Child code
        sleep(1);
        my $time = time();
        EBox::Util::Lock::lock('block', 1); # Blocked
        cmp_ok(time - $time, '>=', 1, 'Blocked by at least 1 sec');
        EBox::Util::Lock::unlock('block');
        exit(0);
    }

    lives_ok {
        EBox::Util::Lock::lock('block', 1);
    } 'Blocking lock got by parent';
    sleep(2);
    EBox::Util::Lock::unlock('block');
    waitpid($pid, 0);
    ok((!$?), 'Child acquired the lock in the end');
}

sub test_wait_lock : Test(3)
{
    my $pid = fork();
    if ($pid == 0) {
        # Child code
        sleep(1);
        my $time = time();
        throws_ok {
            EBox::Util::Lock::lock('block', 1, 1); # Blocked
        } 'EBox::Exceptions::Lock', 'Locked by 1s';
        cmp_ok(time - $time, '>=', 1, 'Locked by 1s');
        exit(0);
    }

    EBox::Util::Lock::lock('block');
    sleep(3);
    EBox::Util::Lock::unlock('block');
    waitpid($pid, 0);
    ok((!$?), 'Child was unabled to get the lock');
}


1;

END {
    EBox::Util::Lock::Test->runtests();
}

