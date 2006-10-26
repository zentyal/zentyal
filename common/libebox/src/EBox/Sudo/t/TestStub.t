use strict;
use warnings;


use Test::More tests =>6 ;

use lib '../../..';

use EBox::Sudo;
use EBox::Sudo::TestStub;


my $GOOD_SUDO_PATH = '/usr/bin/sudo';

diag "EBox::Sudo untouched";
ok not EBox::Sudo::TestStub::isFaked();
is $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;

diag "EBox::Sudo faked";
EBox::Sudo::TestStub::fake();
ok  EBox::Sudo::TestStub::isFaked();
isnt $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;

diag "EBox::Sudo unfaked";
EBox::Sudo::TestStub::unfake();
ok  not EBox::Sudo::TestStub::isFaked();
is $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;

1;
