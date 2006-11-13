package EBox::Sudo::TestStub;
# Description:
# 
use strict;
use warnings;

use EBox::Sudo;
use File::Temp qw(tempfile);
# XXX there are unclear situation with comamnds containig ';' but this is also de case of EBox::Sudo


use Readonly;
Readonly::Scalar our $GOOD_SUDO_PATH => $EBox::Sudo::SUDO_PATH;
Readonly::Scalar our $FAKE_SUDO_PATH => '';

Readonly::Scalar our $GOOD_STDERR_FILE => $EBox::Sudo::STDERR_FILE;

my ($fh,$tmpfile) = tempfile();
close $fh;

Readonly::Scalar  our $FAKE_STDERR_FILE => $tmpfile;



sub fake
{
  *EBox::Sudo::SUDO_PATH = \$FAKE_SUDO_PATH;
  *EBox::Sudo::STDERR_FILE = \$FAKE_STDERR_FILE;
}


sub unfake
{
   *EBox::Sudo::SUDO_PATH = \$GOOD_SUDO_PATH;
   *EBox::Sudo::STDERR_FILE = \$GOOD_STDERR_FILE;
}

sub isFaked
{
  return $EBox::Sudo::SUDO_PATH ne $GOOD_SUDO_PATH;
}


1;
