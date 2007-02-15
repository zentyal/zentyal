use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 2;


my @cases = (
	     [ name => 'submitEnabledWithTitle', value => 'Submit Title'],
	     [ name => 'submitDisabled', value => 'Disabled submit', extraParams => [disabled => 'disabled']],
	    );

TestHelper::testComponent('submit.mas', \@cases);

1;
