#!/usr/bin/perl -w

# Copyright (C) 2006 Warp Networks S.L.
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

# A module to test restricted resources and includes methods on Apache module

use warnings;
use strict;

use Test::More tests => 24;
use Test::Exception;
use Test::Deep;

use lib '../../..';

BEGIN {
    diag('Starting test for some methods on Apache module');
    use_ok('EBox::Apache')
      or die;
}

my $apacheMod = EBox::Apache->_create();
isa_ok( $apacheMod, 'EBox::Apache');

my @resourceNames = ( 'foo/a', 'bar/a', 'foo/b' );

lives_ok {
    $apacheMod->setRestrictedResource( $resourceNames[0],
                                   [ '192.168.45.2/32', '10.0.0.0/24' ],
                                   'file');
} 'Adding a correct restricted file';

lives_ok {
    $apacheMod->setRestrictedResource( $resourceNames[0],
                                       [ '192.168.1.4/32' ],
                                       'file');
} 'Updating a correct restricted file';

lives_ok {
    $apacheMod->setRestrictedResource( $resourceNames[1],
                                       [ 'all', '102.1.2.3/32' ],
                                       'location');
} 'Adding an all allow restricted location';

throws_ok {
    $apacheMod->setRestrictedResource( $resourceNames[2] );
} 'EBox::Exceptions::MissingArgument', 'Missing a compulsory argument';

throws_ok {
    $apacheMod->setRestrictedResource( $resourceNames[2],
                                       [ 'nobody' ]);
} 'EBox::Exceptions::MissingArgument', 'Missing a compulsory argument';

throws_ok {
    $apacheMod->setRestrictedResource( $resourceNames[2], [], 'file' );
} 'EBox::Exceptions::Internal', 'No given IP address';

throws_ok {
    $apacheMod->setRestrictedResource( $resourceNames[2], [ 'foobar', '10.0.0.2/24'], 'location' );
} 'EBox::Exceptions::Internal', 'Deviant IP address';

throws_ok {
    $apacheMod->setRestrictedResource( $resourceNames[2], ['all'], 'foobar' );
} 'EBox::Exceptions::InvalidType', 'Invalid resource type';

cmp_deeply( $apacheMod->_restrictedResources(),
            [ { allowedIPs => [ '192.168.1.4/32' ],
                name       => $resourceNames[0],
                type       => 'file',
              },
              { allowedIPs => ['all'],
                name       => $resourceNames[1],
                type       => 'location',
              }],
            'The additions and updates were done correctly');

throws_ok {
    $apacheMod->delRestrictedResource( );
} 'EBox::Exceptions::MissingArgument', 'Missing a compulsory argument';

lives_ok {
    foreach my $resourceName (@resourceNames[0 .. 1]) {
        $apacheMod->delRestrictedResource( $resourceName );
    }
} 'Deleting correct restricted resources';

throws_ok {
    $apacheMod->delRestrictedResource($resourceNames[2]);
} 'EBox::Exceptions::DataNotFound', 'Given resource name not found';

# Include related tests
my @includes = ( '/bin/true', '/bin/false' );
my @deviantIncludes = ( '/bin/dafdfa' );

throws_ok {
    $apacheMod->addInclude();
} 'EBox::Exceptions::MissingArgument', 'No file to include';

throws_ok {
    $apacheMod->addInclude($deviantIncludes[0]);
} 'EBox::Exceptions::Internal', 'File to include does not exits';

lives_ok {
    $apacheMod->addInclude($_) foreach (@includes);
} 'Adding some includes';

cmp_deeply($apacheMod->_includes(), \@includes,
       'The two includes added');

lives_ok {
    $apacheMod->addInclude($_) foreach (@includes);
} 'Trying to add the same again';

cmp_deeply($apacheMod->_includes(), \@includes,
           'Only the two includes are there');

throws_ok {
    $apacheMod->removeInclude();
} 'EBox::Exceptions::MissingArgument', 'No file to exclude';

throws_ok {
    $apacheMod->removeInclude($deviantIncludes[0]);
} 'EBox::Exceptions::Internal', 'No file to remove';

lives_ok {
    $apacheMod->removeInclude($_) foreach (@includes);
} 'Removing all the include files';

cmp_ok(@{$apacheMod->_includes()}, '==', 0,
       'Nothing has been left');

1;
