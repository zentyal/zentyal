use strict;
use warnings;

use Test::Deep::NoTest;

# make sure we didn't load Test::Builder

my $ok = not exists( ${Test::Builder::}{"new"});
print "1..1\n";
print $ok ? "" : "not ";
print "ok 1\n";
