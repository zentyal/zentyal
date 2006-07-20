package main;
# Description:
use strict;
use warnings;

use Test::More qw(no_plan);
use Test::MockObject;
use Test::Differences;
use Test::Exception;

use lib '../..';

use_ok('EBox::NetWrappers');
iface_addresses_and_friends_test();
netmaskConversionsTests();

sub iface_addresses_and_friends_test
{
  my %ifaceData = (
		eth0   => {   
			   _ifaceShowAddressOutput =>  ['192.168.45.4/24'],
			   addresses               =>  ['192.168.45.4'],
			   addressesWithNetmask    =>  {'192.168.45.4' => '255.255.255.0'}			  },
		vmnet4   => {   
			     _ifaceShowAddressOutput =>  ['45.34.12.12/8', '129.45.34.12/16'],
			     addresses               =>   ['45.34.12.12', '129.45.34.12'],
			     addressesWithNetmask    =>   {'45.34.12.12' => '255.0.0.0', '129.45.34.12' => '255.255.0.0'},
			    },
		  );



  Test::MockObject->fake_module('EBox::NetWrappers', 
		     _ifaceShowAddress => sub {
		       my ($if) = @_;
		       if (exists $ifaceData{$if}) {
			 return @{ $ifaceData{$if}->{_ifaceShowAddressOutput} };
		       }
		       else {
			 throw EBox::Exceptions::External "";
		       }
		     }
		    );

  dies_ok { EBox::NetWrappers::iface_addresses('inexistent iface')  } "iface_addresses called with a inexistent network interface";
  foreach my $iface (keys %ifaceData) {
    my @result = EBox::NetWrappers::iface_addresses($iface);
    eq_or_diff \@result, $ifaceData{$iface}->{addresses}, "Checking result of iface_address call in interface $iface";
  }

  dies_ok { EBox::NetWrappers::iface_addresses_with_netmask('inexistent iface')  } "iface_address_with_netmask called with a inexistent network interface";
  foreach my $iface (keys %ifaceData) {
    my $result = EBox::NetWrappers::iface_addresses_with_netmask($iface);
    eq_or_diff $result, $ifaceData{$iface}->{addressesWithNetmask}, "Checking result of iface_addresses_with_netmask call in interface $iface";
  }

}

sub netmaskConversionsTests
{
  my %masks = (
	       0 => '0.0.0.0',
	       1 => '128.0.0.0',
	       8 => '255.0.0.0',
	       16 => '255.255.0.0',
	       24 => '255.255.255.0',
	       31 => '255.255.255.254',
	       32 => '255.255.255.255',
	      );

  while (my ($numericMask, $dottedMask) = each %masks) {
    is EBox::NetWrappers::mask_from_bits($numericMask), $dottedMask, "Checking result of mask_from_bits($numericMask)";
    is EBox::NetWrappers::bits_from_mask($dottedMask), $numericMask, "Checking result of bits_from_mask($dottedMask)";
  }

}


1;
