package EBox::Test::Class;
# Description:
# 
use strict;
use warnings;

use base 'Test::Class';
use Test::More;

use Fatal qw(mkdir);

use EBox::Sudo::Mock;
EBox::Sudo::Mock::mock();

use EBox::Mock;
use EBox::Config::Mock;
use EBox::GConfModule::Mock;
use EBox::Global::Mock;

sub _mockFrameworkModules :  Test(startup) {
    EBox::Mock::mock();
    EBox::Config::Mock::mock();

    EBox::GConfModule::Mock::mock();
    EBox::Global::Mock::mock();
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
