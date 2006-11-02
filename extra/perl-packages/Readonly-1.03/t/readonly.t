#!perl -I..

# Test the Readonly function

use strict;
use Test::More tests => 19;

# Find the module (1 test)
BEGIN {use_ok('Readonly'); }

my $expected = qr/Modification of a read-only value attempted at \(eval \d+\),? line 1/;

SKIP:
{
	skip 'Readonly \\ syntax is for perls earlier than 5.8', 9  if $] >= 5.008;

	eval q{Readonly \my $ros => 45};
	is $@ => '', 'Create scalar';

	eval q{Readonly \my $ros2 => 45;  $ros2 = 45};
	like $@ => $expected, 'Modify scalar';

	eval q{Readonly \my @roa => (1, 2, 3, 4)};
	is $@ => '', 'Create array';

	eval q{Readonly \my @roa2 => (1, 2, 3, 4); $roa2[2] = 3};
	like $@ => $expected, 'Modify array';

	eval q{Readonly \my %roh => (key1 => "value", key2 => "value2")};
	is $@ => '', 'Create hash (list)';

	eval q{Readonly \my %roh => (key1 => "value", "key2")};
	like $@ => qr/odd number of values/, 'Odd number of values';

	eval q{Readonly \my %roh2 => (key1 => "value", key2 => "value2"); $roh2{key1}="value"};
	like $@ => $expected, 'Modify hash';

	eval q{Readonly \my %roh => {key1 => "value", key2 => "value2"}};
	is $@ => '', 'Create hash (hashref)';

	eval q{Readonly \my %roh2 => {key1 => "value", key2 => "value2"}; $roh2{key1}="value"};
	like $@ => $expected, 'Modify hash';
};

SKIP:
{
	skip 'Readonly $@% syntax is for perl 5.8 or later', 9  unless $] >= 5.008;

	eval q{Readonly my $ros => 45};
	is $@ => '', 'Create scalar';

	eval q{Readonly my $ros2 => 45;  $ros2 = 45};
	like $@ => $expected, 'Modify scalar';

	eval q{Readonly my @roa => (1, 2, 3, 4)};
	is $@ => '', 'Create array';

	eval q{Readonly my @roa2 => (1, 2, 3, 4); $roa2[2] = 3};
	like $@ => $expected, 'Modify array';

	eval q{Readonly my %roh => (key1 => "value", key2 => "value2")};
	is $@ => '', 'Create hash (list)';

	eval q{Readonly my %roh => (key1 => "value", "key2")};
	like $@ => qr/odd number of values/, 'Odd number of values';

	eval q{Readonly my %roh2 => (key1 => "value", key2 => "value2"); $roh2{key1}="value"};
	like $@ => $expected, 'Modify hash';

	eval q{Readonly my %roh => {key1 => "value", key2 => "value2"}};
	is $@ => '', 'Create hash (hashref)';

	eval q{Readonly my %roh2 => {key1 => "value", key2 => "value2"}; $roh2{key1}="value"};
	like $@ => $expected, 'Modify hash';
};
