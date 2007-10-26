# Unit test to test network observer works smoothly
use strict;
use warnings;

use Test::More qw(no_plan);
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
    $dhcp->rangeAction(action => 'add',
                       iface  => 'eth1:adhesive',
                       name   => 'strung out',
                       from   => '192.168.46.20',
                       to     => '192.168.46.40');
} 'Adding a range';

testCareVI('eth1', 'adhesive', 1);

lives_ok {
    $dhcp->rangeAction(action => 'del',
                       iface  => 'eth1:adhesive',
                       indexValue => 'strung out',
                       indexField => 'name',
                       );
} 'Deleting the range';

testCareVI('eth1', 'adhesive', 0);

# Setting something on the other thing
lives_ok {
    $dhcp->fixedAddressAction(action => 'add',
                              iface  => 'eth1:adhesive',
                              name   => 'bush',
                              mac    => '00:00:00:FA:BA:DA',
                              ip     => '192.168.46.22');
} 'Adding a fixed address';

testCareVI('eth1', 'adhesive', 1);

lives_ok {
    $dhcp->fixedAddressAction(action => 'del',
                              iface  => 'eth1:adhesive',
                              indexField => 'mac',
                              indexValue => '00:00:00:FA:BA:DA',
                       );
} 'Deleting the fixed address';

testCareVI('eth1', 'adhesive', 0);

lives_ok {
    $net->removeViface('eth1', 'adhesive', 1);
} 'Removing a virtual interface';



1;
