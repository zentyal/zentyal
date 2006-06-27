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


sub cleanTestDir  : Test(startup) {
    my $testDir = testDir();

    system "rm -rf $testDir"; 
    ($? == 0) or die "Can not clean test dir $testDir";

    mkdir $testDir;
}


sub testDir
{
    return '/tmp/ebox.test';
}



1;
