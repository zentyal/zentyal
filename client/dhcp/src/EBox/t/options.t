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

use Test::More tests => 19;
use Test::Exception;
use Test::MockObject;

use lib '../..';

use EBox::Global;
use EBox;
use EBox::Network;
use EBox::DNS;

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

sub _fakeDNS
{
    Test::MockObject->fake_module('EBox::DNS',
                                  service => sub { return 1; },
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
_fakeDNS();

my $dhcp = EBox::Global->modInstance('dhcp');
my $net  = EBox::Global->modInstance('network');

diag( 'Default Gateway tests');

lives_ok {
    $dhcp->setOption('eth0',
                     default_gateway => { ebox => '' },
                     search_domain => { none => '' },
                     primary_ns    => { eBoxDNS => ''},
                     );
} 'Setting options';

cmp_ok( $dhcp->defaultGateway('eth0'), 'eq', '10.0.0.1',
       'Default gateway IP address is the interface one');

lives_ok {
    $dhcp->setOption('eth0', default_gateway => { ip => '10.0.0.2' });
} 'Setting a custom IP address as default gateway';

cmp_ok( $dhcp->defaultGateway('eth0'), 'eq', '10.0.0.2',
         'Default gateway IP address is the custom one');

lives_ok {
    $dhcp->setOption('eth0', default_gateway => { none => '' });
} 'Setting nothing as default gateway';

ok( ! $dhcp->defaultGateway('eth0'), 'Not a default gateway');

# TODO: setDefaultGateway with a configured gateway

diag( 'Search domain tests');

lives_ok {
    $dhcp->setOption('eth0',
                     search_domain => { custom => 'jimmyeatworld.com' })
} 'Setting a custom search domain';

cmp_ok( $dhcp->searchDomain('eth0'), 'eq', 'jimmyeatworld.com',
         'Getting a correct search domain' );

# TODO: setSearchDomain with a model

lives_ok {
    $dhcp->setOption('eth0',
                     search_domain => { none => '' });
} 'Setting nothing as search domain';

ok( ! $dhcp->searchDomain('eth0'), 'Nothing is the search domain');

diag(q{Nameservers' tests});

lives_ok {
    $dhcp->setOption('eth0',
                     primary_ns => { eboxDNS => '' });
} 'Setting eBox as primary NS';

cmp_ok( $dhcp->nameserver('eth0', 1), 'eq', '10.0.0.1',
         'Getting eBox iface IP address as primary nameserver');

lives_ok {
    $dhcp->setOption('eth0',
                     primary_ns => { custom_ns => '10.1.0.32' })
} 'Setting a custom NS as primary one';

cmp_ok( $dhcp->nameserver('eth0', 1), 'eq', '10.1.0.32',
         'Getting a custom primary NS');

lives_ok {
    $dhcp->setOption('eth0',
                     primary_ns => { none => '' });
} 'Setting nothing as primary NS';

ok( ! $dhcp->nameserver('eth0',1), 'Nothing as primary NS');

lives_ok {
    $dhcp->setOption('eth0', secondary_ns => '192.32.23.34')
} 'Setting a custom secondary NS';

cmp_ok( $dhcp->nameserver('eth0', 2), 'eq', '192.32.23.34',
         'Custom secondary NS OK');

throws_ok {
    $dhcp->setOption('eth0', secondary_ns => 'BEDlights for BLUEeyes');
} 'EBox::Exceptions::External', 'Setting incorrect secondary NS';

1;
