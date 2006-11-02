#!perl -I..

# Readonly scalar tests

use strict;
use Test::More tests => 12;

# Find the module (1 test)
BEGIN {use_ok('Readonly'); }

sub expected
{
    my $line = shift;
    $@ =~ s/\.$//;   # difference between croak and die
    return "Modification of a read-only value attempted at " . __FILE__ . " line $line\n";
}

use vars qw/$s1 $s2/;
my ($ms1, $ms2);

# creation (4 tests)
eval {Readonly::Scalar $s1 => 13};
is $@ => '', 'Create a global scalar';
eval {Readonly::Scalar $ms1 => 31};
is $@ => '', 'Create a lexical scalar';
eval {Readonly::Scalar $s2 => undef};
is $@ => '', 'Create an undef global scalar';
eval 'Readonly::Scalar $ms2';    # must be eval string because it's a compile-time error
like $@ => qr/^Not enough arguments for Readonly::Scalar/, 'Try w/o args';

# fetching (4 tests)
is $s1  => 13, 'Fetch global';
is $ms1 => 31, 'Fetch lexical';
ok !defined $s2, 'Fetch undef global';
ok !defined $ms2, 'Fetch undef lexical';

# storing (2 tests)
eval {$s1 = 7};
is $@ => expected(__LINE__-1), 'Error setting global';
is $s1 => 13, 'Readonly global value unchanged';

# untie (1 test)
SKIP:{
	skip "Can't catch 'untie' until perl 5.6", 1 if $] < 5.006;
    skip "Scalars not tied: XS in use", 1 if $Readonly::XSokay;
	eval {untie $ms1};
	is $@ => expected(__LINE__-1), 'Untie';
	}
