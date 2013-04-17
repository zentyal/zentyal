use strict;
use warnings;

use Dir::Self;

use lib '../..';

use EBox::Test::Mason;
use Test::More tests => 5;

my $compRoot = __DIR__ . '/../..';
my $compFile = $compRoot . '/input/select.mas';

my @options = (
    { value => 'baboon' },
    { value => 'mandrill', printableValue => 'mandrill printable value'},
    { value => 'gibon', printableValue => 'gibon printable value'},
);

my @nameAndValue = (name => 'monkeys', value => 'mandrill');

my @cases = (
    [ name => 'monos' ],  # minimal case
    [@nameAndValue],
    [@nameAndValue, options => \@options],
    [@nameAndValue, options => \@options,  disabled => 'disabled'],
    [@nameAndValue, options => \@options,  multiple => 'multiple'],
);

EBox::Test::Mason::testComponent($compFile, \@cases, compRoot => $compRoot);

1;
