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

# Unit test to check the DNS API exposition

use strict;
use warnings;

use lib '../../';

use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;

use EBox::Global;

BEGIN {
    diag ( 'Starting firewall unit test' );
    use_ok ( 'EBox::Firewall' );
}

my $fwMod = EBox::Global->modInstance('firewall');

isa_ok ( $fwMod, 'EBox::Firewall' );

# Add a service
my $servMod = EBox::Global->modInstance('services');
my $servId;

unless ( $servMod->serviceExists('name' => 'test') ) {
    $servId = $servMod->addService( name            => 'test',
                                    protocol        => 'tcp',
                                    sourcePort      => 'any',
                                    destinationPort => '19999',
                                    internal        => 0,
                                    readOnly        => 0,
                                    description     => 'test service');
}

my $addedId;
ok ( $addedId = $fwMod->addOutputService( decision    => 'accept',
                                          destination => { destination_any => 'any', inverse => 0 },
                                          service     => $servId,
                                          description => ''),
     'Adding an output rule to test service');

cmp_ok ( ref( $fwMod->getOutputService( 0 )), 'eq', 'HASH',
         'Getting first output rule service');

lives_ok {
    my $idx = 0;
    my $row;
    do {
        $row = $fwMod->getOutputService($idx);
        $idx++;
    } until ( $row->{id} eq $addedId);
} 'Getting the service added';

lives_ok {
    $fwMod->removeOutputService( $addedId );
} 'Remove output rule for test service';

throws_ok {
    $fwMod->removeOutputService( $addedId );
} 'EBox::Exceptions::DataNotFound', 'Remove an inexistant service';

$servMod->removeService( name => 'test' );

1;
