use strict;
use warnings;

use lib '../../..';

use EBox::MailFilter::ClamAV::Test;

EBox::MailFilter::ClamAV::Test->runtests;

1;
