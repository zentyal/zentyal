use strict;
use warnings;


use Test::More tests =>11 ;
use Test::Exception;

use lib '../../..';

use EBox::Sudo;
use EBox::Sudo::TestStub;


my $GOOD_SUDO_PATH = $EBox::Sudo::SUDO_PATH;
my $GOOD_STDERR_FILE = $EBox::Sudo::STDERR_FILE;

diag "EBox::Sudo untouched";
ok not EBox::Sudo::TestStub::isFaked();
is $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;
is $EBox::Sudo::STDERR_FILE, $GOOD_STDERR_FILE;
dies_ok { EBox::Sudo::root('/bin/ls /')  } 'try to use root() wothout faking';

diag "EBox::Sudo faked";
EBox::Sudo::TestStub::fake();
ok  EBox::Sudo::TestStub::isFaked();
isnt $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;
isnt $EBox::Sudo::STDERR_FILE, $GOOD_STDERR_FILE;
lives_ok { EBox::Sudo::root('/bin/ls /')  } ;

diag "EBox::Sudo unfaked";
EBox::Sudo::TestStub::unfake();
ok  not EBox::Sudo::TestStub::isFaked();
is $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;
is $EBox::Sudo::STDERR_FILE, $GOOD_STDERR_FILE;

1;
