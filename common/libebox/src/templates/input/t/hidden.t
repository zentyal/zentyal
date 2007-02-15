use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 2;




my @cases = (
	     [ name => 'hiddenEnabled', value => 'hiddenValue'],
	     [ name => 'hiidenDisabled', value => 'hiddenValue', extraParams => [disabled => 'disabled']],
	    );

TestHelper::testComponent('hidden.mas', \@cases);

1;
