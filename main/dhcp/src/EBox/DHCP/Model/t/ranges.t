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

# Unit test to check RangeTable and FixedAddressTable data models

use strict;
use warnings;

use lib '../../..';

use Test::More tests => 25;
use Test::Exception;
use Test::Deep;
use Test::MockObject;

use EBox;
use EBox::Global;
use EBox::Model::Manager;
use EBox::Network;

BEGIN {
    diag('Starting RangeTable and FixedAddressTable unit test');
    use_ok('EBox::DHCP::Model::RangeTable');
    use_ok('EBox::DHCP::Model::FixedAddressTable');
}

sub _fakeNetwork
{
Test::MockObject->fake_module('EBox::Network',
                              ifaceNetwork => \&_ifaceNetwork,
                              ifaceNetmask => \&_ifaceNetmask,
                              ifaceAddress => \&_ifaceAddress,
                              ifaces    => \&_ifaces,
                              ifaceMethod  => \&_ifaceMethod,
                             );
}

sub _ifaceNetwork
{
    my ($self, $iface) = @_;
    if ( $iface eq 'eth0' ) {
        return '10.0.0.0';
    } else {
        return '10.0.1.0';
    }
}

sub _ifaceNetmask
{
    return '255.255.255.0';
}

sub _ifaceAddress
{
    my ($self, $iface) = @_;
    if ( $iface eq 'eth0' ) {
        return '10.0.0.1';
    } else {
        return '10.0.1.1';
    }
}

sub _ifaces
{
    return [ 'eth0', 'eth1' ];
}

sub _ifaceMethod
{
    return 'static';
}

EBox::init();
_fakeNetwork();
my $manager = EBox::Model::Manager->instance();
my $objMod  = EBox::Global->modInstance('network');
my $dhcpMod = EBox::Global->modInstance('dhcp');

my $rangeModel = $manager->model('/dhcp/RangeTable/eth0');
isa_ok($rangeModel, 'EBox::DHCP::Model::RangeTable' );

my $fixedAddressModel = $manager->model('/dhcp/FixedAddressTable/eth0');
isa_ok($fixedAddressModel, 'EBox::DHCP::Model::FixedAddressTable');

throws_ok {
    $rangeModel->add( name => 'shed seven',
                      from => '192.168.45.1',
                      to   => '192.168.45.10' );
} 'EBox::Exceptions::External', 'Range not in the interface network';

throws_ok {
    $rangeModel->add( name => 'shed seven',
                      from => '10.0.0.1',
                      to   => '10.0.0.100');
} 'EBox::Exceptions::External', 'Range includes iface IP address';

throws_ok {
    $rangeModel->add( name => 'shed seven',
                      from => '10.0.0.110',
                      to   => '10.0.0.12');
} 'EBox::Exceptions::External', 'Range is incorrect';

my $addedRangeId = $rangeModel->add( name => 'shed seven',
                                     from => '10.0.0.10',
                                     to   => '10.0.0.30');
ok ( $addedRangeId, 'Adding a valid range to the model');

ok ( $rangeModel->row($addedRangeId), 'Valid range has been correctly added');

throws_ok {
    $rangeModel->add( name => 'the bluetones',
                      from => '10.0.0.15',
                      to   => '10.0.0.60');
} 'EBox::Exceptions::External', 'New range overlaps current ranges';

my $objId;
lives_ok {
    $objId = $objMod->addObject1(name => 'beady eye',
                                 members => [
                                     { 'name'    => 'mansun',
                                       'ipaddr'  => '10.0.0.1/32',
                                       'macaddr' => '00:00:00:FA:BA:DA' },
                                     { 'name'    => 'band of horses',
                                       'ipaddr'  => '10.1.0.1/32',
                                       'macaddr' => '00:00:01:FA:BA:DA' },
                                     { 'name'    => 'glasvegas',
                                       'ipaddr'  => '10.0.0.20/32',
                                       'macaddr' => '00:00:02:FA:BA:DA' },
                                     { 'name'    => 'mona',
                                       'ipaddr'  => '10.0.0.5/32',
                                       'macaddr' => '00:00:03:FA:BA:DA' },
                                     { 'name'    => 'elbow',
                                       'ipaddr'  => '10.0.0.6/32',
                                       'macaddr' => '00:00:00:FA:BA:DA' },
                                     # FIXME: 2.1 two members with the same macaddr
                                     # will not be possible
                                     { 'name'    => 'nero',
                                       'ipaddr'  => '10.0.0.7/32',
                                       'macaddr' => '00:00:00:FA:BA:DA' },
                                    ]);
} 'Adding a new object';

my $addedMapId = $fixedAddressModel->add(object => $objId);
ok( $addedMapId, 'Adding an object to be used as fixed address');

my $fixedAddr = $dhcpMod->fixedAddresses('eth0', 0);
is_deeply($fixedAddr,
          [ { 'name' => 'mona',
              'ip'   => '10.0.0.5',
              'mac'  => '00:00:03:FA:BA:DA' } ],
          'Only a member is valid as fixed address');

throws_ok {
    $rangeModel->add( name => 'foocast',
                      from => '10.0.0.3',
                      to   => '10.0.0.8');
} 'EBox::Exceptions::External', 'Range overlaps a fixed address';

lives_ok {
    $rangeModel->set( $addedRangeId,
                      name => 'foocast');
} 'Changing the name on a range';

my $addedRangeId2 = $rangeModel->add( name => 'autofelatoria',
                                      from => '10.0.0.31',
                                      to   => '10.0.0.50');

ok ( $addedRangeId2, 'Adding another range' );

ok ( $rangeModel->row($addedRangeId2), 'Added done correctly');

throws_ok {
    $rangeModel->set( $addedRangeId,
                      to => '10.0.0.35');
} 'EBox::Exceptions::External', 'Collision ranges';

throws_ok {
    $rangeModel->set( $addedRangeId2,
                      from => '10.0.0.25');
} 'EBox::Exceptions::External', 'Collision ranges 2';

lives_ok {
    $objMod->setMemberIP( 'beady eye/mona',
                          '10.0.0.33/32' );
} 'Setting an ip within a range in an object member';

my $fixed = $dhcpMod->fixedAddresses('eth0', 0);
is_deeply($fixed, [], 'No fixed address available to be used as fixed addresses');

# Test address coincedence in different models
my $fixedAddressModel2 = $manager->model('/dhcp/FixedAddressTable/eth1');
isa_ok($fixedAddressModel2, 'EBox::DHCP::Model::FixedAddressTable');

my $objId2 = $objMod->addObject1( name => 'factory',
                                  members => [ { 'name'    => 'mansun',
                                                 'ipaddr'  => '10.0.1.20/32',
                                                 'macaddr' => '00:AD:DA:AD:AD:AA' }]);

my $addedMapId2 = $fixedAddressModel2->add( object => $objId2 );
ok( $addedMapId2, 'Added another fixed address to the other interface');

$fixed = $dhcpMod->fixedAddresses('eth1', 0);
is_deeply($fixed, [], 'No fixed addresses since it already exists the same member name in other model');

lives_ok {
    $rangeModel->removeRow( $addedRangeId );
    $rangeModel->removeRow( $addedRangeId2 );
    $fixedAddressModel->removeRow( $addedMapId );
    $fixedAddressModel2->removeRow( $addedMapId2 );
    $objMod->removeObject( $objId );
    $objMod->removeObject( $objId2 );
} 'Removing everything we made';

1;
