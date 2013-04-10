use strict;
use warnings;

use EBox::Test::Mason;
use Dir::Self;

use lib '../..';

use Test::More tests => 3;

my $compRoot = __DIR__ . '/../..';
my $compFile = $compRoot . '/input/password.mas';

my @cases = (
    [ name => 'passwordEnabled'],
    [ name => 'passwordEnabledAndFilled', value => 'passwordValue'],
    [ name => 'hiddenDisabled', value => 'passwordValue', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent($compFile, \@cases, compRoot => $compRoot);

1;
