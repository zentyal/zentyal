package EBox::DHCP::Test;
use base 'EBox::Test::Class';
# Description:
use strict;
use warnings;

use Test::More;
use Test::Exception;
use EBox::Global;
use EBox::Test qw(checkModuleInstantiation);
use Test::MockObject::Extends;
use Test::Differences;
use lib '../..';



sub _moduleInstantiationTest : Test
{
  checkModuleInstantiation('dhcp', 'EBox::DHCP');
}


sub setDHCPEBoxModule : Test(setup)
{
  EBox::Global::TestStub::setEBoxModule('dhcp' => 'EBox::DHCP');
}

sub clearEBoxModules : Test(teardown)
{
  EBox::Global::TestStub::setAllEBoxModules();
}


package EBox::NetworkObserver;
1;
