use strict;
use warnings;

use EBox::Test::Mason;

use lib '../..';

use Test::More tests => 2;
use Dir::Self;

my $compRoot = __DIR__ . '/../..';
my $compFile = $compRoot . '/input/file.mas';

my @cases = (
    [ name => 'fileInput', ],
    [ name => 'fileInputDisabled',  disabled => 'disabled'],
);

EBox::Test::Mason::testComponent($compFile, \@cases, compRoot => $compRoot);

1;
