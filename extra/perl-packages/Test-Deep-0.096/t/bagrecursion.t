use strict;
use warnings;

use t::std;

# just want to make sure this doesn't go into an infitite recursion

my @methods=(methods(hello=>'world'),methods(goodbye=>'world'));
my $bag_o_methods=bag(@methods);

ok(1, "no inifinite recursion");
