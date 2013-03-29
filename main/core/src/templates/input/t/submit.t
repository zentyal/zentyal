use strict;
use warnings;

use EBox::Test::Mason;

use lib '../..';

use Test::More tests => 2;

my @cases = (
	     [ name => 'submitEnabledWithTitle', value => 'Submit Title'],
	     [ name => 'submitDisabled', value => 'Disabled submit', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent('input/submit.mas', \@cases);

1;
