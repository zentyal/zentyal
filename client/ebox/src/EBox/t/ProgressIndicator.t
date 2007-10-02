use strict;
use warnings;

use lib '../..';

use EBox::ProgressIndicator::Test;

use English qw(-no_match_vars);

if ($EUID == 0 or $UID == 0) {
  die "This test can not be runned by the root user";
}

EBox::ProgressIndicator::Test->runtests;

1;
