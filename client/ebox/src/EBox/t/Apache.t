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

# A module to test restricted files methods on Apache module

use warnings;
use strict;

use Test::More qw(no_plan);
use Test::Exception;

use lib '../../..';

BEGIN {
    diag('Starting test for restricted files method on Apache module');
    use_ok('EBox::Apache')
      or die;
}

my $apacheMod = EBox::Apache->_create();
isa_ok( $apacheMod, 'EBox::Apache');

my @fileNames = ( 'foo/a', 'bar/a', 'foo/b' );

lives_ok {
    $apacheMod->setRestrictedFile( $fileNames[0],
                                   [ '192.168.45.2/32', '10.0.0.0/24' ]);
} 'Adding a correct restricted file';

lives_ok {
    $apacheMod->setRestrictedFile( $fileNames[0],
                                   [ '192.168.1.4/32' ]);
} 'Updating a correct restricted file';

lives_ok {
    $apacheMod->setRestrictedFile( $fileNames[1],
                                   [ 'all', '102.1.2.3/32' ]);
} 'Adding an all allow restricted file';

throws_ok {
    $apacheMod->setRestrictedFile( $fileNames[2] );
} 'EBox::Exceptions::MissingArgument', 'Missing a compulsory argument';

throws_ok {
    $apacheMod->setRestrictedFile( $fileNames[2], [] );
} 'EBox::Exceptions::Internal', 'No given IP address';

throws_ok {
    $apacheMod->setRestrictedFile( $fileNames[2], [ 'foobar', '10.0.0.2/24'] );
} 'EBox::Exceptions::Internal', 'Deviant IP address';

throws_ok {
    $apacheMod->delRestrictedFile( );
} 'EBox::Exceptions::MissingArgument', 'Missing a compulsory argument';

lives_ok {
    foreach my $fileName (@fileNames[0 .. 1]) {
        $apacheMod->delRestrictedFile( $fileName );
    }
} 'Deleting correct restricted files';

throws_ok {
    $apacheMod->delRestrictedFile($fileNames[2]);
} 'EBox::Exceptions::DataNotFound', 'Given file name not found';

1;
