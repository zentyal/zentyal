use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 3;


my @cases = (
	     [ name => 'textEnabled'],
	     [ name => 'textEnabledAndFilled', value => 'textValue'],
	     [ name => 'hiidenDisabled', value => 'textValue', extraParams => [disabled => 'disabled']],
	    );

TestHelper::testComponent('text.mas', \@cases);

1;
