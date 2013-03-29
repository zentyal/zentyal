use strict;
use warnings;

use EBox::Test::Mason;

use lib '../..';

use Test::More tests => 3;

my @cases = (
	     [ name => 'textEnabled'],
	     [ name => 'textEnabledAndFilled', value => 'textValue'],
	     [ name => 'hiidenDisabled', value => 'textValue', disabled => 'disabled'],
);

EBox::Test::Mason::testComponent('input/text.mas', \@cases);

1;
