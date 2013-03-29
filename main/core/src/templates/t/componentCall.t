use strict;
use warnings;

use EBox::Test::Mason;
use Test::More tests => 3;

my @cases  = (
	      [ ],
	      [ 'msg.mas', msg => 'single call to msg.mas' ],
	      [
	       ['msg.mas', msg => 'Multiple calls: first call to msg.mas'],
	       ['msg.mas', msg => 'Multiple calls: second call to msg.mas'],
	      ],
);

EBox::Test::Mason::testComponent('componentCall.mas', \@cases);

1;
