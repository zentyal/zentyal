package EBox::Sudo::TestStub;
# Description:
# 
use strict;
use warnings;

use EBox::Sudo;

# XXX there are unclear situation with comamnds containig ';' but this is also de case of EBox::Sudo


use Readonly;
Readonly::Scalar our $GOOD_SUDO_PATH => $EBox::Sudo::SUDO_PATH;
Readonly::Scalar our $FAKE_SUDO_PATH => '';

sub fake
{
  *EBox::Sudo::SUDO_PATH = \$FAKE_SUDO_PATH;
}


sub unfake
{
   *EBox::Sudo::SUDO_PATH = \$GOOD_SUDO_PATH;
}

sub isFaked
{
  return $EBox::Sudo::SUDO_PATH ne $GOOD_SUDO_PATH;
}


1;
