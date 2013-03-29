use strict;
use warnings;

use EBox::Test::Mason;

use lib '../..';

use Test::More tests => 2;

my @cases = (
	     [ name => 'hiddenEnabled', value => 'hiddenValue'],
	     [ name => 'hiddenDisabled', value => 'hiddenValue', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent('input/hidden.mas', \@cases);

1;
