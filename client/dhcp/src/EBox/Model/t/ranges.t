# Copyright (C) 2007 Warp Networks S.L.
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

use Test::More tests => 24;
use Test::Exception;
use Test::Deep;
use Test::MockObject;

use EBox;
use EBox::Global;
use EBox::Model::ModelManager;
use EBox::Network;

BEGIN {
    diag ( 'Starting RangeTable and FixedAddressTable unit test' );
    use_ok( 'EBox::DHCP::Model::RangeTable' );
    use_ok( 'EBox::DHCP::Model::FixedAddressTable' );
}


sub _fakeNetwork
{
Test::MockObject->fake_module('EBox::Network',
                              ifaceNetwork => \&_ifaceNetwork,
                              ifaceNetmask => \&_ifaceNetmask,
                              ifaceAddress => \&_ifaceAddress,
                              allIfaces    => \&_allIfaces,
                              ifaceMethod  => \&_ifaceMethod,
                             );
}

sub _ifaceNetwork
{
    return '10.0.0.0';
}

sub _ifaceNetmask
{
    return '255.255.255.0';
}

sub _ifaceAddress
{
    return '10.0.0.1';
}

sub _allIfaces
{
    return [ 'eth0' ];
}

sub _ifaceMethod
{
    return 'static';
}

EBox::init();
_fakeNetwork();
my $manager = EBox::Model::ModelManager->instance();

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

throws_ok {
    $fixedAddressModel->add( name => 'mansun',
                             ip   => '10.0.0.1',
                             mac  => '00:00:00:FA:BA:DA');
} 'EBox::Exceptions::External', 'Fixed map not possible with the iface IP address';

throws_ok {
    $fixedAddressModel->add( name => 'mansun',
                             ip   => '10.1.0.1',
                             mac  => '00:00:00:FA:BA:DA');
} 'EBox::Exceptions::External', 'Fixed map using an IP on not available range';

throws_ok {
    $fixedAddressModel->add( name => 'mansun',
                             ip   => '10.0.0.20',
                             mac  => '00:00:00:FA:BA:DA');
} 'EBox::Exceptions::External', 'Fixed map on a defined range';

my $addedMapId = $fixedAddressModel->add( name => 'mansun',
                                          ip   => '10.0.0.5',
                                          mac  => '00:00:00:FA:BA:DA');

ok ( $addedMapId, 'Adding a valid mapping MAC/IP address');

ok ( $fixedAddressModel->row($addedMapId), 'Valid mapping addition correct');

throws_ok {
    $fixedAddressModel->add( name => 'mansun _ cancer',
                             ip   => '10.0.0.3',
                             mac  => '00:00:00:FA:BA:DA');
} 'EBox::Exceptions::DataExists', 'Duplicate MAC address';

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

throws_ok {
    $fixedAddressModel->set( $addedMapId,
                             ip => '10.0.0.33');
} 'EBox::Exceptions::External', 'Setting an ip within a range';

lives_ok {
    $rangeModel->removeRow( $addedRangeId );
    $rangeModel->removeRow( $addedRangeId2 );
    $fixedAddressModel->removeRow( $addedMapId );
} 'Removing everything we made';

1;

