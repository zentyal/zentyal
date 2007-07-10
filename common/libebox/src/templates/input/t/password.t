use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 3;


my @cases = (
	     [ name => 'passwordEnabled'],
	     [ name => 'passwordEnabledAndFilled', value => 'passwordValue'],
	     [ name => 'hiidenDisabled', value => 'passwordValue', disabled => 'disabled'],
	    );

TestHelper::testComponent('password.mas', \@cases);

1;
