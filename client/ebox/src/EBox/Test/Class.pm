package EBox::Test::Class;
# Description:
# 
use strict;
use warnings;

use base 'Test::Class';

use Test::More;
use Test::Exception;


use EBox::Test;;


sub _testStubsForFrameworkModules :  Test(startup) {
    EBox::Test::activateEBoxTestStubs();
}






1;
