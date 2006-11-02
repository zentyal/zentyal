#!perl -I..

# Readonly array tests

use strict;
use Test::More tests => 23;

# Find the module (1 test)
BEGIN {use_ok('Readonly'); }

sub expected
{
    my $line = shift;
    $@ =~ s/\.$//;   # difference between croak and die
    return "Modification of a read-only value attempted at " . __FILE__ . " line $line\n";
}

use vars qw/@a1 @a2/;
my @ma1;

# creation (3 tests)
eval 'Readonly::Array @a1;';
is $@ =>'', 'Create empty global array';
eval 'Readonly::Array @ma1 => ();';
is $@ => '', 'Create empty lexical array';
eval 'Readonly::Array @a2 => (1,2,3,4,5);';
is $@ => '', 'Create global array';

# fetching (3 tests)
ok !defined($a1[0]), 'Fetch global';
is $a2[0]  => 1, 'Fetch global';
is $a2[-1] => 5, 'Fetch global';

# fetch size (3 tests)
is scalar(@a1)  => 0, 'Global size (zero)';
is scalar(@ma1) => 0, 'Lexical size (zero)';
is $#a2 => 4, 'Global last element (nonzero)';

# store (2 tests)
eval {$ma1[0] = 5;};
is $@ => expected(__LINE__-1), 'Lexical store';
eval {$a2[3] = 4;};
is $@ => expected(__LINE__-1), 'Global store';

# storesize (1 test)
eval {$#a1 = 15;};
is $@ => expected(__LINE__-1), 'Change size';

# extend (1 test)
eval {$a1[77] = 88;};
is $@ => expected(__LINE__-1), 'Extend';

# exists (2 tests)
SKIP: {
	skip "Can't do exists on array until Perl 5.6", 2  if $] < 5.006;

	eval 'ok(exists $a2[4], "Global exists")';
	eval 'ok(!exists $ma1[4], "Lexical exists")';
	}

# clear (1 test)
eval {@a1 = ();};
is $@ => expected(__LINE__-1), 'Clear';

# push (1 test)
eval {push @ma1, -1;};
is $@ => expected(__LINE__-1), 'Push';

# unshift (1 test)
eval {unshift @a2, -1;};
is $@ => expected(__LINE__-1), 'Unshift';

# pop (1 test)
eval {pop (@a2);};
is $@ => expected(__LINE__-1), 'Pop';

# shift (1 test)
eval {shift (@a2);};
is $@ => expected(__LINE__-1), 'shift';

# splice (1 test)
eval {splice @a2, 0, 1;};
is $@ => expected(__LINE__-1), 'Splice';

# untie (1 test)
SKIP: {
	skip "Can't catch untie until Perl 5.6", 1  if $] <= 5.006;
	eval {untie @a2;};
	is $@ => expected(__LINE__-1), 'Untie';
	}
