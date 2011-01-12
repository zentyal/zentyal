use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 2;




my @cases = (
	     [ name => 'fileInput', ],
	     [ name => 'fileInputDisabled',  disabled => 'disabled'],
	    );

TestHelper::testComponent('file.mas', \@cases);

1;
