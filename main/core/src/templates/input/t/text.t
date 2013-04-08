use strict;
use warnings;

use Test::More tests => 3;
use Dir::Self;

use lib '../..';
use EBox::Test::Mason;

my $compRoot = __DIR__ . '/../..';
my $compFile = $compRoot . '/input/text.mas';

my @cases = (
    [ name => 'textEnabled'],
    [ name => 'textEnabledAndFilled', value => 'textValue'],
    [ name => 'hiidenDisabled', value => 'textValue', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent($compFile, \@cases, compRoot => $compRoot);

1;
