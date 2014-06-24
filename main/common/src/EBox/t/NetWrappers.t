use strict;
use warnings;

use Test::More tests => 38;
use Test::MockObject;
use Test::Differences;
use Test::Exception;

use lib '../..';

use_ok('EBox::NetWrappers');

my @subsAssumed = qw(_ifaceShowAddress iface_is_up list_ifaces list_routes);

diag "WARNING: this tests assume that he following functions are correct: @subsAssumed\n There are overriden with fake subs but if the real implementation where incorrect this tests would no catch the error";

iface_addresses_and_friends_test();
list_local_addresses_and_friends_tests();
netmaskConversionsTests();
networkConversionTests();
iface_by_address_test();

sub fakeIfaceShowAddress
{
    my %ifaceData = @_;

    Test::MockObject->fake_module('EBox::NetWrappers',
        _ifaceShowAddress => sub {
            my ($if) = @_;
            if (exists $ifaceData{$if}) {
                return @{ $ifaceData{$if}->{_ifaceShowAddressOutput} };
            } else {
                throw EBox::Exceptions::External "";
            }
        }
    );
}

sub fakeIfaceIsUp
{
    my @ifaces = @_;

    Test::MockObject->fake_module('EBox::NetWrappers',
        iface_is_up => sub {
            my ($if) = @_;
            return scalar grep { $_ eq $if } @ifaces;
        }
    );
}

sub fakeListIfaces
{
    my @ifaces = @_;

    Test::MockObject->fake_module('EBox::NetWrappers',
        list_ifaces => sub {
            return @ifaces;
        }
    );
}

sub fakeListRoutes
{
    my @routes = @_;

    Test::MockObject->fake_module('EBox::NetWrappers',
        list_routes => sub {
            return @routes;
        }
    );
}

sub iface_addresses_and_friends_test
{
    my %ifaceData = (
        eth0   => {
            _ifaceShowAddressOutput =>  ['192.168.45.4/24'],
            addresses               =>  ['192.168.45.4'],
            addressesWithNetmask    =>  {'192.168.45.4' => '255.255.255.0'},
        },
        vmnet4   => {
            _ifaceShowAddressOutput =>  ['45.34.12.12/8', '129.45.34.12/16'],
            addresses               =>   ['45.34.12.12', '129.45.34.12'],
            addressesWithNetmask    =>   {'45.34.12.12' => '255.0.0.0', '129.45.34.12' => '255.255.0.0'},
        },
    );

    fakeIfaceShowAddress(%ifaceData);

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

sub list_local_addresses_and_friends_tests
{
    my %ifaceData = (
        eth0   => {
            _ifaceShowAddressOutput =>  ['192.168.45.4/24'],
            addresses               =>  ['192.168.45.4'],
            addressesWithNetmask    =>  {'192.168.45.4' => '255.255.255.0'}
        },
        vmnet4   => {
            _ifaceShowAddressOutput =>  ['45.34.12.12/8', '129.45.34.12/16'],
            addresses               =>   ['45.34.12.12', '129.45.34.12'],
            addressesWithNetmask    =>   {'45.34.12.12' => '255.0.0.0', '129.45.34.12' => '255.255.0.0'},
        },
    );

    fakeIfaceShowAddress(%ifaceData);
    fakeIfaceIsUp(keys %ifaceData);
    fakeListIfaces(keys %ifaceData);

    my @localAddressesExpected;
    push @localAddressesExpected, @{ $_->{addresses} } foreach values %ifaceData;
    my %localAddressesWithMaskExpected;
    my @addrTmp;
    push @addrTmp, %{ $_->{addressesWithNetmask} } foreach values %ifaceData;
    %localAddressesWithMaskExpected = @addrTmp;

    my @localAddresses= EBox::NetWrappers::list_local_addresses();
    eq_or_diff \@localAddresses, \@localAddressesExpected, 'Checking list_local_addresses';

    my %localAddressesWithMask = EBox::NetWrappers::list_local_addresses_with_netmask();
    eq_or_diff \%localAddressesWithMask, \%localAddressesWithMaskExpected, 'Checking list_local_addresses_with_netmask';
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

sub networkConversionTests
{
    my @cases = (
        {with => '192.168.45.0/24', without => '192.168.45.0', netmask => '255.255.255.0'},
        {with => '192.168.45.0/30', without => '192.168.45.0', netmask => '255.255.255.252'},
        {with => '145.68.0.0/16', without => '145.68.0.0', netmask => '255.255.0.0'},
        {with => '10.0.0.0/8', without => '10.0.0.0', netmask => '255.0.0.0'}
    );

    foreach my $case (@cases) {
        my $without = $case->{without};
        my $with    = $case->{with};
        my $netmask = $case->{netmask};

        my $newWith = EBox::NetWrappers::to_network_with_mask($without, $netmask);
        is $newWith, $with, "Checking conversion of net $without netmask $netmask to 'with netask' format";

        my ($newWithout, $newNetmask) = EBox::NetWrappers::to_network_without_mask($with);
        is $newWithout, $without, "Checking network part of conversion from 'with netmask' format to 'without netmask' format";
        is $newNetmask, $netmask, "Checking netmask part of conversion from 'with netmask' format to 'without netmask' format";
    }
}

sub iface_by_address_test
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

    fakeIfaceShowAddress(%ifaceData);
    fakeIfaceIsUp(keys %ifaceData);
    fakeListIfaces(keys %ifaceData);

    my %testCases;
    while (my ($if, $ifConf) = each %ifaceData) {
        my @addresses = @{ $ifConf->{addresses} };
        foreach my $addr (@addresses) {
            $testCases{$addr} = $if;
        }
    }

    while (my ($addr, $expectedIf) = each %testCases) {
        my ($if) = EBox::NetWrappers::iface_by_address($addr);
        is $if, $expectedIf, "Checking iface_by_address with address $addr";
    }
}

1;
