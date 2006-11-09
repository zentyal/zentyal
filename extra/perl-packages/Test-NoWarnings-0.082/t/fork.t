use strict;

use Test::More tests => 2;

use Test::NoWarnings;

pass("just testing");

# if it's working properly, only the parent will conduct a warnings test
my $pid = fork;
die "Forked failed, $!" unless defined $pid;
