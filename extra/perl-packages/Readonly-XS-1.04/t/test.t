#!perl

# Test suite for Readonly::XS.

use strict;
use warnings;
package Readonly;
use Test::More tests => 10;

use vars qw/$x $y/;

# Find the module (2 tests)
BEGIN
{
    eval 'use Readonly::XS';
    $@ =~ s/ at .*// if $@;
    is substr($@,0,71) => "Readonly::XS is not a standalone module. You should not use it directly", 'Unauthorized use';

    $Readonly::XS::MAGIC_COOKIE = "Do NOT use or require Readonly::XS unless you're me.";
    delete $INC{'Readonly/XS.pm'};
    eval 'use Readonly::XS';
    is $@ => '', 'Authorized use';
}

# Functions loaded?  (2 tests)
ok defined &is_sv_readonly,   'is_sv_readonly loaded';
ok defined &make_sv_readonly, 'make_sv_readonly loaded';

# is_sv_readonly (4 tests)
ok is_sv_readonly("hello"), 'constant string is readonly';
ok is_sv_readonly(7),       'constant number is readonly';
*x = \42;
ok is_sv_readonly($x),      'constant typeglob thingy is readonly';
$y = 'r/w';
ok !is_sv_readonly($y),     'inconstant variable is not readonly';

# make_sv_readonly (2 tests)
make_sv_readonly($y);
ok is_sv_readonly($y),      'status changed to readonly';
eval {$y = 75};
$@ =~ s/ at .*// if $@;
is $@ => "Modification of a read-only value attempted\n", 'verify readonly-ness';
