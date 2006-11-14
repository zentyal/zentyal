# Description:
# 
use strict;
use warnings;

use Test::More tests => 25;
use Test::Exception;
use Test::Differences;
use Data::Dumper; # bug in Test::Differences requires e must load this in order to get normal results

use lib '../../..';



BEGIN { use_ok 'EBox::NetWrappers::TestStub'; }



EBox::NetWrappers::TestStub::fake();
ifaceTest();
routesTest();

sub ifaceTest
{
  my %fakeIfaces = (
		    'eth0' => {
			        up => 1,
			        address => {
					    '192.168.3.4' => '255.255.255.0',
					    },
			       mac_address => '00:EE:11:CC:CE:8D',

			      },
		    'eth1' => {
			        up => 1,
			        address => {
					    '192.168.45.4' => '255.255.255.0',
					    '10.0.0.7'     => '255.0.0.0',
					    },
			       mac_address => '00:11:11:CC:CE:8D',

			      },
		    'eth2' => {
			        up => 0,
			        address => {
					    '142.120.45.4' => '255.255.255.0',
					    '44.0.0.7'     => '255.0.0.0',
					    },
			       mac_address => '00:11:11:CC:AA:8D',
			      },

		   );

  EBox::NetWrappers::TestStub::setFakeIfaces(\%fakeIfaces);
  
  eq_or_diff [EBox::NetWrappers::TestStub::list_ifaces()], [keys %fakeIfaces ], "Checking list_ifaces()";

    ok !EBox::NetWrappers::iface_exists('macacoInterfaz'), 'Testing negative result of iface_exists';
  foreach my $iface  (keys %fakeIfaces) {
    ok EBox::NetWrappers::iface_exists($iface), 'Testing positive result of iface_exists';
    my $expectedUpResult = $fakeIfaces{$iface}->{up} ? 1 : 0;
    my $upResult = EBox::NetWrappers::iface_is_up($iface) ? 1 : 0;
    is $upResult, $expectedUpResult, "Testing iface_is_up in $iface";

    is EBox::NetWrappers::iface_mac_address($iface),  $fakeIfaces{$iface}->{mac_address}, "Testing iface_mac_address in $iface";
    
    my @expectedAddress = sort keys %{ $fakeIfaces{$iface}->{address} };
    my @actualAddress = sort ( EBox::NetWrappers::iface_addresses($iface) );
    eq_or_diff \@actualAddress, \@expectedAddress, "Testing result of iface_addresses($iface)";

    eq_or_diff EBox::NetWrappers::iface_addresses_with_netmask($iface), $fakeIfaces{$iface}->{address}, "Testing result of iface_addresses_with_netmask($iface)"
    
  }
}



sub routesTest 
{
  my %routes = (
		'192.168.45.0' => '0.0.0.0',
		'0.0.0.0'      => '10.0.1.100',
		'10.0.0.0'     => '192.168.45.123',
	       );

  EBox::NetWrappers::TestStub::setFakeRoutes(\%routes);

  my @expectedListedRoutes = sort  (
			       { network => '192.168.45.0' , router => '0.0.0.0'},
			       { network => '0.0.0.0' , router => '10.0.1.100'},
			       { network => '10.0.0.0' , router => '192.168.45.123'}
			      );

  my @actualListedRoutes = sort (EBox::NetWrappers::list_routes());
  diag 'The following test may return a false negative'; # amybe this is a bug in Test::Difference
  eq_or_diff [@actualListedRoutes], [@expectedListedRoutes], "Checking list_routes()";
  
  while (my ($net, $router) = each %routes) {
    ok EBox::NetWrappers::route_is_up($net, $router), "Checking route_is_up($net, $router)"
  }
 
  my %inexistentRoutes = (
		'192.168.0.0' => '0.0.0.0',         # gateway matchs but net not
		'10.0.0.0'     => '192.168.45.200',  # net match but gateway not
		'120.34.23.13'      => '34.32.61.34', # neither match
	       );
  
  while (my ($net, $router) = each %inexistentRoutes) {
    ok !EBox::NetWrappers::route_is_up($net, $router), "Checking route_is_up($net, $router) with inexistent routes"
  }
}

1;
