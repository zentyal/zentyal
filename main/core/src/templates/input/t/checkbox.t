use strict;
use warnings;

use EBox::Test::Mason;

use lib '../..';

use Test::More tests => 3;

my @cases = (
	     [ name => 'checkedBox', value => 1],
	     [ name => 'noCheckedBox', value => 0],
	     [ name => 'checkedBoxDisabled', value => 1, disabled => 'disabled'],
);

EBox::Test::Mason::testComponent('input/checkbox.mas', \@cases);

1;
