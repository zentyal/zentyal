#!perl -I..

# Test the Readonly function

use strict;
use Test::More tests => 4;

sub expected
{
    my $line = shift;
    $@ =~ s/\.$//;   # difference between croak and die
    return "Invalid tie at " . __FILE__ . " line $line\n";
}

# Find the module (1 test)
BEGIN {use_ok('Readonly'); }

eval {tie my $s, 'Readonly::Scalar', 1};
is $@ => expected(__LINE__-1), "Direct scalar tie";

eval {tie my @a, 'Readonly::Array', 2, 3, 4};
is $@ => expected(__LINE__-1), "Direct array tie";

eval {tie my %h, 'Readonly::Hash', five => 5, six => 6};
is $@ => expected(__LINE__-1), "Direct hash tie";
