use strict;
use warnings;

use EBox::Test::Mason;
use Dir::Self;

use lib '../..';

use Test::More tests => 2;

my $compRoot = __DIR__ . '/../..';
my $compFile = $compRoot . '/input/hidden.mas';

my @cases = (
    [ name => 'hiddenEnabled', value => 'hiddenValue'],
    [ name => 'hiddenDisabled', value => 'hiddenValue', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent($compFile, \@cases, compRoot => $compRoot);

1;
