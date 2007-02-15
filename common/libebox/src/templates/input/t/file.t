use strict;
use warnings;

use TestHelper;

use lib '../..';


use Test::More tests => 2;




my @cases = (
	     [ name => 'fileInput', ],
	     [ name => 'fileInputDisabled',  extraParams => [disabled => 'disabled']],
	    );

TestHelper::testComponent('file.mas', \@cases);

1;
