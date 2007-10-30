# Copyright (C) 2007  Warp Networks S.L.
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
    $dhcp->addFixedAddress('eth1:adhesive',
                           name   => 'bush',
                           mac    => '00:00:00:FA:BA:DA',
                           ip     => '192.168.46.22');
} 'Adding a fixed address';

testCareVI('eth1', 'adhesive', 1);

lives_ok {
    $dhcp->removeFixedAddress('eth1:adhesive', 'bush');
} 'Deleting the fixed address';

testCareVI('eth1', 'adhesive', 0);

lives_ok {
    $net->removeViface('eth1', 'adhesive', 1);
} 'Removing a virtual interface';

1;
