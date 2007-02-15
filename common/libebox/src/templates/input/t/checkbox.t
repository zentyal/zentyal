use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 3;


my @cases = (
	     [ name => 'checkedBox', value => 1],
	     [ name => 'noCheckedBox', value => 0],
	     [ name => 'checkedBoxDisabled', value => 1, extraParams => [disabled => 'disabled']],
	    );

TestHelper::testComponent('checkbox.mas', \@cases);

1;
