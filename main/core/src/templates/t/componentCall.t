use strict;
use warnings;

use TestHelper;
use Test::More tests => 3;



my @cases  = (
	      [ ],
	      [ 'msg.mas', msg => 'single call to msg.mas' ],
	      [
	       
	       ['msg.mas', msg => 'Multiple calls: first call to msg.mas'],
	       ['msg.mas', msg => 'Multiple calls: second call to msg.mas'],
	      ],
	     );


TestHelper::testComponent('componentCall.mas', \@cases);

1;
