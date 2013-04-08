use strict;
use warnings;

use Test::More tests => 2;
use Dir::Self;

use lib '../..';
use EBox::Test::Mason;


my $compRoot = __DIR__ . '/../..';
my $compFile = $compRoot . '/input/submit.mas';

my @cases = (
    [ name => 'submitEnabledWithTitle', value => 'Submit Title'],
    [ name => 'submitDisabled', value => 'Disabled submit', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent($compFile, \@cases, compRoot => $compRoot);

1;
