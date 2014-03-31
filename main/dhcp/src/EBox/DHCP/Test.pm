# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package EBox::DHCP::Test;

use base 'EBox::Test::Class';

# Description:

use Test::More;
use Test::Exception;
use EBox::Global;
use EBox::Test qw(checkModuleInstantiation);
use EBox::TestStubs qw(fakeModule);

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

sub setDHCPModule : Test(setup)
{
  EBox::Global::TestStub::setModule('dhcp' => 'EBox::DHCP');
  EBox::Module::Config::TestStub::setEntry('/ebox/modules/dhcp/active', 0);
  EBox::Module::Config::TestStub::setEntry('/ebox/modules/global/modules/dhcp/depends', ['network']);

}

sub clearModules : Test(teardown)
{
  EBox::Global::TestStub::setAllModules();
}

sub setServiceTest : Test(6)
{
  my $dhcp = EBox::Global->modInstance('dhcp');
  $nStaticIfacesReturnValue = 1;
  lives_ok { $dhcp->setService(1)  } 'Setting active service with static ifaces';
  ok $dhcp->isEnabled(), 'Checking that server is now active';
  lives_ok { $dhcp->setService(0)  } 'Unsetting service';
  ok !$dhcp->isEnabled(), 'Checking that server is now inactive';

  $nStaticIfacesReturnValue = 0;
  dies_ok { $dhcp->setService(1)  } 'Attempt to set the server active without static ifaces must raise error';
    ok !$dhcp->isEnabled(), 'Checking that server state remains inactive';
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
  ok $dhcp->ifaceMethodChanged('eth0', @{ $_ }), 'Testing if dhcp  server disallows a problematic  change in network interface IP method' foreach @problematicChanges;

}

sub staticRoutes : Test(2)
{
  my @macacoStaticRoutes = (
			    '192.168.30.0/24' => { network => '192.168.4.0', netmask => '255.255.255.0', gateway => '192.168.30.4' },
			    '10.0.0.8/8' => { network => '192.168.4.0', netmask => '255.255.254.0', gateway => '10.0.10.5' },

			   );

  my @gibonStaticRoutes = (
			    '192.168.30.0/24'    => { network => '192.168.4.0', netmask => '255.0.0.0', gateway => '192.168.30.15' },
			   );

  fakeModule(name => 'macacoStaticRoutes', isa => ['EBox::DHCP::StaticRouteProvider'], subs => [ staticRoutes => sub { return [@macacoStaticRoutes]  }  ]);
  fakeModule(name => 'gibonStaticRoutes', isa => ['EBox::DHCP::StaticRouteProvider'], subs => [ staticRoutes => sub { return [@gibonStaticRoutes]  }  ]);
  fakeModule(name => 'titiNoStaticRoutes');
  fakeModule(name => 'mandrillNoStaticRoutes');

  my $dhcp = EBox::Global->modInstance('dhcp');
  my $staticRoutes_r;

  my %expectedRoutes = (
			'192.168.30.0/24' => [ { network => '192.168.4.0', netmask => '255.255.255.0', gateway => '192.168.30.4' }, { network => '192.168.4.0', netmask => '255.0.0.0', gateway => '192.168.30.15' }, ],
			'10.0.0.8/8' => [ { network => '192.168.4.0', netmask => '255.255.254.0', gateway => '10.0.10.5' } ],
		       );

  lives_ok { $staticRoutes_r = $dhcp->staticRoutes()  } 'Calling staticRoutes';
  eq_or_diff $staticRoutes_r, \%expectedRoutes, 'Checking staticRoutes result';
}

1;
