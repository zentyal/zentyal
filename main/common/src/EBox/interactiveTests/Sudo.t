# Description:
use strict;
use warnings;

use Test::More tests => 1;
use Test::Exception;
use Error qw(:try);

use lib  '../..';

use EBox::Sudo::TestStub;
use EBox::TestStub;

EBox::TestStub::fake(); # to covert log in logfiel to msg into stderr
exceptionTest();

sub exceptionTest
{
  diag "The following check assummes that the current user is not in the sudoers file";
    throws_ok {  EBox::Sudo::root("/bin/ls /")  } 'EBox::Exceptions::Sudo::Wrapper', "Checking that Wrapper exception is raised when sudo itself failed";
}


1;
