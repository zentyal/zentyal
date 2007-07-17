use strict;
use warnings;

use lib '../../..';

use EBox::MailFilter::SpamAssassin::Test;

EBox::MailFilter::SpamAssassin::Test->runtests;

1;
