package EBox::Test::Class;
# Description:
# 
use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Fatal qw(mkdir);

use EBox::Test qw(activateEBoxTestStubs);


sub _testStubsForFrameworkModules :  Test(startup) {
    activateEBoxTestStubs();
}






1;
