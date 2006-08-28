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


my $nStaticIfacesReturnValue = 1; # this controls the output of EBox::DHCP::nStaticIfaces


sub _moduleInstantiationTest : Test
{
  checkModuleInstantiation('dhcp', 'EBox::DHCP');

  Test::MockObject->fake_module('EBox::DHCP',
			       nStaticIfaces => sub {  return $nStaticIfacesReturnValue }, 
				_configureFirewall => sub {},
			       );
}




sub setDHCPEBoxModule : Test(setup)
{
  EBox::Global::TestStub::setEBoxModule('dhcp' => 'EBox::DHCP');
  EBox::GConfModule::TestStub::setEntry('/ebox/modules/dhcp/active', 0);
  EBox::GConfModule::TestStub::setEntry('/ebox/modules/global/modules/dhcp/depends', ['network']);

}

sub clearEBoxModules : Test(teardown)
{
  EBox::Global::TestStub::setAllEBoxModules();
}


sub setServiceTest : Test(6)
{
  my $dhcp = EBox::Global->modInstance('dhcp');
  $nStaticIfacesReturnValue = 1;
  lives_ok { $dhcp->setService(1)  } 'Setting active service with static ifaces';
  ok $dhcp->service(), 'Checking that server is now active';
  lives_ok { $dhcp->setService(0)  } 'Unsetting service';
  ok !$dhcp->service(), 'Checking that server is now inactive';

  $nStaticIfacesReturnValue = 0;
  dies_ok { $dhcp->setService(1)  } 'Attempt to set the server active without static ifaces must raise error';
    ok !$dhcp->service(), 'Checking that server state remains inactive';
}

sub ifaceMethodChangedTest : Test(32)
{
  my @problematicChanges = (['static', 'dhcp'], ['static', 'notset'], ['static', 'trunk']);
  my @harmlessChanges = (
			    ['static', 'static'],
			    ['dhcp',  'static'], ['dhcp', 'dhcp'], ['dhcp', 'notset' ], ['dhcp', 'trunk'],
			    ['notset',  'static'], ['notset', 'dhcp'], ['notset', 'notset' ], ['notset', 'trunk'],
    ['trunk',  'static'], ['trunk', 'dhcp'], ['trunk', 'notset' ], ['trunk', 'trunk'],
			    );


  my $dhcp = EBox::Global->modInstance('dhcp');
  ok !$dhcp->ifaceMethodChanged('eth0', @{ $_ }), 'Testing if dhcp inactive server allows a harmless change in network interface IP method' foreach @harmlessChanges;
  ok !$dhcp->ifaceMethodChanged('eth0', @{ $_ }), 'Testing if dhcp inactive server allows a  change in network interface IP method' foreach @problematicChanges;

  $nStaticIfacesReturnValue = 10;
  $dhcp->setService(1);
  ok !$dhcp->ifaceMethodChanged('eth0', @{ $_ }), 'Testing if dhcp server allows a harmless change in network interface IP method' foreach @harmlessChanges;
#  ok $dhcp->ifaceMethodChanged('eth0', @{ $_ }), 'Testing if dhcp  server disallows a problematic  change in network interface IP method' foreach @problematicChanges;

}




1;
