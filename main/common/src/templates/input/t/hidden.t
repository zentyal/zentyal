use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 2;




my @cases = (
	     [ name => 'hiddenEnabled', value => 'hiddenValue'],
	     [ name => 'hiidenDisabled', value => 'hiddenValue', disabled => 'disabled'],
	    );

TestHelper::testComponent('hidden.mas', \@cases);

1;
