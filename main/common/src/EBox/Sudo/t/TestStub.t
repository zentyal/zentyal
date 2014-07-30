use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;

use EBox::TestStub;
use EBox::Sudo;
use EBox::Sudo::TestStub;
use EBox::Config::TestStub;

my $GOOD_SUDO_PATH = $EBox::Sudo::SUDO_PATH;
my $GOOD_STDERR_FILE = $EBox::Sudo::STDERR_FILE;

diag "EBox::Sudo untouched";
ok not EBox::Sudo::TestStub::isFaked();
is $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;
is $EBox::Sudo::STDERR_FILE, $GOOD_STDERR_FILE;
#FIXME: Test to much dependant in the enviroment right now
#dies_ok { EBox::Sudo::root('/bin/ls /root')  } 'try to use root() without faking';

EBox::TestStub::fake();
EBox::Config::TestStub::fake(tmp => '/tmp');

diag "EBox::Sudo faked";
EBox::Sudo::TestStub::fake();
ok EBox::Sudo::TestStub::isFaked();
isnt $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;
isnt $EBox::Sudo::STDERR_FILE, $GOOD_STDERR_FILE;
lives_ok { EBox::Sudo::root('/bin/ls /root')  } ;

diag "EBox::Sudo unfaked";
EBox::Sudo::TestStub::unfake();
ok not EBox::Sudo::TestStub::isFaked();
is $EBox::Sudo::SUDO_PATH, $GOOD_SUDO_PATH;
is $EBox::Sudo::STDERR_FILE, $GOOD_STDERR_FILE;

1;
