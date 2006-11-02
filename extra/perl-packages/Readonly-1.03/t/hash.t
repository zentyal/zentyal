#!perl -I..

# Readonly hash tests

use strict;
use Test::More tests => 20;

# Find the module (1 test)
BEGIN {use_ok('Readonly'); }

sub expected
{
    my $line = shift;
    $@ =~ s/\.$//;   # difference between croak and die
    return "Modification of a read-only value attempted at " . __FILE__ . " line $line\n";
}

use vars qw/%h1/;
my (%mh1, %mh2);

# creation (3 tests)
eval {Readonly::Hash %h1 => (a=>"A", b=>"B", c=>"C", d=>"D")};
is $@ => '', 'Create global hash';
eval {Readonly::Hash %mh1 => (one=>1, two=>2, three=>3, 4)};
like $@ => qr/odd number of values/, "Odd number of values";
eval {Readonly::Hash %mh1 => {one=>1, two=>2, three=>3, four=>4}};
is $@ => '', 'Create lexical hash';

# fetch (3 tests)
is $h1{a} => 'A', 'Fetch global';
ok !defined $h1{'q'}, 'Nonexistent element undefined';
is $mh1{two} => 2, 'Fetch lexical';

# store (1 test)
eval {$h1{a} = 'Z'};
is $@ => expected(__LINE__-1), 'Store';

# delete (1 test)
eval {delete $h1{c}};
is $@ => expected(__LINE__-1), 'Delete';

# clear (1 test)
eval {%h1 = ()};
is $@ => expected(__LINE__-1), 'Clear';

# exists (3 tests)
ok exists $h1{a}, 'Exists';
eval {ok !exists $h1{x}, "Doesn't exist"};
is $@ => '', "Doesn't exist (no error)";

# keys, values (4 tests)
my @a = sort keys %h1;
is $a[0], 'a', 'Keys a';
is $a[1], 'b', 'Keys b';
@a = sort values %h1;
is $a[0], 'A', 'Values A';
is $a[1], 'B', 'Values B';

# each (2 tests)
my ($k,$v);
while ( ($k,$v) = each %h1)
	{
	$mh2{$k} = $v;
	}
is $mh2{c} => 'C', 'Each C';
is $mh2{d} => 'D', 'Each D';

# untie (1 test)
SKIP: {
	skip "Can't catch untie until Perl 5.6", 1  if $] < 5.006;
	eval {untie %h1};
	is $@ => expected(__LINE__-1), 'Untie';
	}
