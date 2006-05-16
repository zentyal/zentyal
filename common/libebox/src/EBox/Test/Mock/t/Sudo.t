# Description:
# 
use strict;
use warnings;

use Test::More tests => 3; # => 5
use Test::Exception;
use EBox::Sudo;

use lib '../../../..';

# XXX we remnoveddeactivated the unmocked sudo test because they were not automated: we need to enter manually sudo password!
# XXX we only test unmocked sudo for failure because we do not parse or mangle /etc/sudoers and it don't think is worth the effort

BEGIN { use_ok 'EBox::Test::Mock::Sudo'; }
testMock();


sub testMock
{
    my $tmpDir = "/tmp/ebox.test.mock.sudo";
    my $file = "$tmpDir/macaco";
    my $cmdNotInSudoers = "touch $file";

    system "rm -rf $tmpDir" if -e $tmpDir;
    
    system "mkdir -p $tmpDir";
    ($? == 0) or die "Can not create test dir $tmpDir";

  #  dies_ok { EBox::Sudo::root($cmdNotInSudoers) };

    EBox::Test::Mock::Sudo::mock();
    lives_ok { EBox::Sudo::root($cmdNotInSudoers) };
    ok (-e $file), "Checking if the not in sudoers command was carried on";

    EBox::Test::Mock::Sudo::unmock();
#    dies_ok { EBox::Sudo::root($cmdNotInSudoers) };
    system "rm -rf $tmpDir";
}

1;
