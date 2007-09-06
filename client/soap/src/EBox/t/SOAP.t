#!/usr/bin/perl -w

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

# A unit test SOAP module

use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;
use Data::Dumper;

use EBox::Global;
use EBox;

use lib '../..';

# Check arguments
unless ( scalar (@ARGV) == 1 ) {
    print "Usage: SOAP.t bundle $/";
    print 'where bundle: the tar.gz created by joinEBox.pl at the control center' . $/;
    exit 1;
}

my $bundle = $ARGV[0];

diag ( 'Starting EBox::SOAP test' );

BEGIN {
  use_ok ( 'EBox::SOAP' )
    or die;
}

EBox::init();

# Start testing
my $soap;
lives_ok { $soap = EBox::Global->modInstance( 'soap' ) }
  'Getting a soap instance';

lives_ok { $soap->setEnabled(undef) }
  'Disable soap service';

ok ( ! $soap->enabled(), 'Disable was done correctly');

cmp_ok ( $soap->listeningPort(), '==', 443,
         'Listening to the default port' );

ok ( ! $soap->eBoxCN(), 'No common name assigned');

ok ( ! $soap->bundleUploaded(), 'No bundle uploaded');

lives_ok { $soap->parseUploadedBundle($bundle) }
     'Parse a bundle correctly';

ok ( $soap->eBoxCN(), 'A common name is assigned');

ok ( $soap->controlCenterIP(), 'An IP address for the control center');

ok ( $soap->controlCenterSOAPServerPort(), 'An Apache Web SOAP server port');

ok ( $soap->bundleUploaded(),
     'Bundle uploaded correctly');

lives_ok { $soap->deleteBundleUploaded() }
     'Deleting uploaded bundle';

ok ( ! $soap->bundleUploaded(), 'Bundle deleted correctly');

throws_ok { $soap->deleteBundleUploaded() }
     'EBox::Exceptions::External', 'Deleting an existing bundle';

lives_ok { $soap->_regenConfig(restart => 1) }
  'Restarting the service';
