use strict;
use warnings;

use EBox::Test::Mason;

use lib '../..';

use Test::More tests => 3;

my @cases = (
	     [ name => 'passwordEnabled'],
	     [ name => 'passwordEnabledAndFilled', value => 'passwordValue'],
	     [ name => 'hiddenDisabled', value => 'passwordValue', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent('input/password.mas', \@cases);

1;
