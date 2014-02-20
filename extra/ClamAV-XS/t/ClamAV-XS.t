# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl ClamAV-XS.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::Exception;
use Test::More tests => 1;
BEGIN { use_ok('ClamAV::XS') };

#########################

# throws_ok {
#     my $sigs = ClamAV::XS::signatures();
# } qr/Error getting signature count/ , 'It fails to get the number of signatures';
