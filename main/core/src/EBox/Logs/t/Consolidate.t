use strict;
use warnings;

use lib '../../..';

use Test::More skip_all => 'FIXME';

use EBox::Logs::Consolidate::Test;

EBox::Logs::Consolidate::Test->runtests;

1;
