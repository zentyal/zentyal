# Copyright (C) 2008 Warp Networks S.L.
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


use strict;
use warnings;

use Test::More tests => 10;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::Int;

EBox::TestStubs::activateTestStubs();

my @validCases = (
                  # no defiend bounds
                  [
                   value => 0,
                  ],
                  [
                   value => 10,
                  ],
                  # negative value as min bound
                  [
                   min => -5,
                   value => 1,
                  ],
                  # value between defined bounds
                  [
                   min => -8,
                   max => 2,
                   value => 1,
                  ],
                  # equal tan min value
                  [
                   min => -4,
                   value => -4,
                  ],
                  # equal tan max value
                  [
                   max => 5,
                   value => 5,
                  ],
                  
                 );


my @deviantCases = (
                    # default min value must be zero, so no negatives allowed
                    [
                     value => -1,
                    ],
                    # mix and max missmatch
                    [
                     max => 4,
                     min => 7,
                     value => 5,
                    ],
                    # greater than max
                    [
                     min => -1,
                     max => 0,
                     value => 1,
                    ],
                    # lesser than min
                    [
                     min => 2,
                     value => 1,
                    ]
                   );




foreach my $case_r (@validCases) {
    my @params = @{ $case_r };
    EBox::Types::Test::createOk(
                                'EBox::Types::Int',
                                fieldName => 'test',
                                @params,
                                "Checking instance creation with valid parameters and value"
                               );

}

foreach my $case_r (@deviantCases) {
    my @params = @{ $case_r };
    EBox::Types::Test::createFail(
                                  'EBox::Types::Int',
                                  @params,
"Checking instance creation raises error when called with invalid parameters and value"
                                 );
}






1;
