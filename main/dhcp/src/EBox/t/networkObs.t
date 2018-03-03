# Copyright (C) 2007 Warp Networks S.L.
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

# Unit test to test network observer works smoothly
use strict;
use warnings;

use Test::More tests => 12;
use Test::Exception;

use EBox::Global;
use EBox;

EBox::init();

my $dhcp = EBox::Global->modInstance('dhcp');
my $net  = EBox::Global->modInstance('network');
my $obj  = $net;

sub testCareVI
{
    my ($iface, $viface, $care) = @_;

    if ( $care ) {
        ok( $dhcp->vifaceDelete($iface,$viface), 'Caring about deleting');
        throws_ok {
            $net->removeViface($iface, $viface);
        } 'EBox::Exceptions::DataInUse', 'Asking to remove';
    } else {
        ok( ! $dhcp->vifaceDelete($iface, $viface), 'Not caring about deleting');
    }
}

# Add a virtual interface
lives_ok {
    $net->setViface('eth1',
                    'adhesive',
                    '192.168.46.12',
                    '255.255.255.0');
} 'Adding a virtual interface';

# Setting something on the other thing
lives_ok {
    $dhcp->addRange('eth1:adhesive',
                    name   => 'strung out',
                    from   => '192.168.46.20',
                    to     => '192.168.46.40');
} 'Adding a range';

testCareVI('eth1', 'adhesive', 1);

lives_ok {
    $dhcp->removeRange('eth1:adhesive', 'strung out');
} 'Deleting the range';

testCareVI('eth1', 'adhesive', 0);

# Setting something on the other thing
lives_ok {
    $obj->addObject1(name => 'shed',
                     members => [ {
                         name    => 'bush',
                         ipaddr  => '192.168.46.22/32',
                         macaddr => '00:00:00:FA:BA:DA',
                         } ]);
} 'Adding a new object to be used as fixed address';


lives_ok {
    $dhcp->addFixedAddress('eth1:adhesive', object => 'shed');
} 'Adding a fixed address';

lives_ok {
    $dhcp->setFixedAddress('eth1:adhesive', 'shed', description => 'a desc');
} 'Setting the fixed address description';

testCareVI('eth1', 'adhesive', 1);

lives_ok {
    $dhcp->removeFixedAddress('eth1:adhesive', 'bush');
} 'Deleting the fixed address';

lives_ok {
    $obj->removeObject('shed');
} 'Deleting the object';

testCareVI('eth1', 'adhesive', 0);

lives_ok {
    $net->removeViface('eth1', 'adhesive', 1);
} 'Removing a virtual interface';

1;
