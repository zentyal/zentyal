#! /usr/bin/perl 

use Test::MockTime();
use Test::More(tests => 18);
use Time::Local();
use strict;
use warnings;

my ($mock, $real);

# determine the correct epoch value for our test time
my $TRUE = Time::Local::timegm(19, 25, 3, 30, 6, 2006);

# set_absolute_time with a defaulted date spec
Test::MockTime::set_absolute_time('2006-07-30T03:25:19Z');
$mock = time;
ok(($mock >= $TRUE) && ($mock <= $TRUE+1), "Absolute time works");
sleep 2;
$mock = time;
ok(($mock >= $TRUE+2) && ($mock <= $TRUE+3), "Absolute time is still in sync after two seconds sleep:$mock");
$mock = Time::Local::timelocal(localtime);
$real = Time::Local::timelocal(CORE::localtime);
ok($mock <= $real, "localtime seems ok");

# set_absolute_time with an explicit date spec
Test::MockTime::set_absolute_time('03:25:19 07/30/2006', '%H:%M:%S %m/%d/%Y');
$mock = time;
ok(($mock >= $TRUE) && ($mock <= $TRUE+1), "Absolute time with explicit date specworks");
sleep 2;
$mock = time;
ok(($mock >= $TRUE+2) && ($mock <= $TRUE+3), "Absolute time is still in sync after two seconds sleep:$mock");
$real = Time::Local::timelocal(CORE::localtime);
ok($mock <= $real, "localtime seems ok");

# try set_fixed_time with a defaulted date spec
Test::MockTime::set_fixed_time('2006-07-30T03:25:19Z');
$real = time;
sleep 2;
$mock = time;
cmp_ok($mock, '==', $real, "time is fixed");
cmp_ok($mock, '==', $TRUE, "time is fixed correctly");
Test::MockTime::set_fixed_time('2006-07-30T03:25:19Z');
$mock = Time::Local::timelocal(localtime());
sleep 2;
$real = Time::Local::timelocal(localtime);
cmp_ok($mock, '==', $real, "localtime is fixed");
cmp_ok($mock, '==', $TRUE, "localtime is fixed correctly");
Test::MockTime::set_fixed_time('2006-07-30T03:25:19Z');
$mock = Time::Local::timegm(gmtime);
sleep 2;
$real = Time::Local::timegm(gmtime);
cmp_ok($mock, '==', $real, "gmtime is fixed");
cmp_ok($mock, '==', $TRUE, "gmtime is fixed correctly");

# try set_fixed_time with an explicit date spec
Test::MockTime::set_fixed_time('03:25:19 07/30/2006', '%H:%M:%S %m/%d/%Y');
$real = time;
sleep 2;
$mock = time;
cmp_ok($mock, '==', $real, "time is fixed with explicit date spec");
cmp_ok($mock, '==', $TRUE, "time is fixed correctly");
Test::MockTime::set_fixed_time('03:25:19 07/30/2006', '%H:%M:%S %m/%d/%Y');
$mock = Time::Local::timelocal(localtime());
sleep 2;
$real = Time::Local::timelocal(localtime);
cmp_ok($mock, '==', $real, "localtime is fixed");
cmp_ok($mock, '==', $TRUE, "localtime is fixed correctly");
Test::MockTime::set_fixed_time('03:25:19 07/30/2006', '%H:%M:%S %m/%d/%Y');
$mock = Time::Local::timegm(gmtime);
sleep 2;
$real = Time::Local::timegm(gmtime);
cmp_ok($mock, '==', $real, "gmtime is fixed");
cmp_ok($mock, '==', $TRUE, "gmtime is fixed correctly");
