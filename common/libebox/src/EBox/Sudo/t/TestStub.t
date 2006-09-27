# Description:
# 
use strict;
use warnings;

use Test::More tests => 5; # 8
use Test::Exception;
use EBox::Sudo;

use lib '../../..';

# XXX we remnoveddeactivated the unmocked sudo test because they were not automated: we need to enter manually sudo password!
# XXX we only test unmocked sudo for failure because we do not parse or mangle /etc/sudoers and it don't think is worth the effort

BEGIN { use_ok 'EBox::Sudo::TestStub'; }
testFake();


sub testFake
{
    my $tmpDir = "/tmp/ebox.test.mock.sudo";
    my $file = "$tmpDir/macaco";
    my $cmdNotInSudoers = "touch $file";

    system "rm -rf $tmpDir" if -e $tmpDir;
    
    system "mkdir -p $tmpDir";
    ($? == 0) or die "Can not create test dir $tmpDir";

#    dies_ok { EBox::Sudo::root($cmdNotInSudoers) } 'Checking that can not execute a sudo command without password';

    EBox::Sudo::TestStub::fake();
    lives_and { EBox::Sudo::root($cmdNotInSudoers);  ok (-e $file) } "Checking if the not in sudoers command was carried on with Sudo::root";

    # reset file
    system "rm -f $file";
    die "$!" if ($? != 0);

    lives_and {  EBox::Sudo::rootWithoutException($cmdNotInSudoers); ok (-e $file)  } "Checking if the not in sudoers command was carried on with Sudo::rootWithoutException";

    my $exceptionCommand = '/bin/ls /macaco/monos/inexistente';
    dies_ok { EBox::Sudo::root($exceptionCommand) } 'Checking that mocked EBox::Sudo::root raises exception as expected';
    lives_ok { EBox::Sudo::rootWithoutException($exceptionCommand) } 'Checking that mocked EBox::Sudo::rootWithoutException does not raises exception on error';

    EBox::Sudo::TestStub::unfake();
    # we have commented these two tests because it prompts  the user
 #   dies_ok { EBox::Sudo::root($cmdNotInSudoers) } 'Checking that root had returned to his normal behaviour';
#   dies_ok { EBox::Sudo::rootWithoutException($cmdNotInSudoers) } 'Checking that root had returned to his normal behaviour';
    system "rm -rf $tmpDir";
}

1;
