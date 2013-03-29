use strict;
use warnings;

use EBox::Test::Mason;

use lib '../..';


use Test::More tests => 2;

my @cases = (
	     [ name => 'fileInput', ],
	     [ name => 'fileInputDisabled',  disabled => 'disabled'],
);

EBox::Test::Mason::testComponent('input/file.mas', \@cases);

1;
