package EBox::Test::Class;
# class: EBox::Test::Class
# 
#  This class is intended to use as base, replacing Test:Class, to build eBox's test classes
#
use strict;
use warnings;

use base 'Test::Class';

use Test::More;
use Test::Exception;


use EBox::Test;;
use EBox::TestStubs;

sub _testStubsForFrameworkModules :  Test(startup) {
    EBox::TestStubs::activateTestStubs();
}






1;
