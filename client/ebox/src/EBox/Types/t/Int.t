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

use Test::More tests => 28;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::Int;
use EBox::Types::Text;



sub creationTest
{
    my @validCases = (
                      # no defined bounds
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
                      # equal than min value
                      [
                       min => -4,
                       value => -4,
                      ],
                      # equal than max value
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
                        # mix and max mismatch
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

}

sub cmpTest
{
    my $four = new EBox::Types::Int(
                                    fieldName => 'four',
                                    value    => 4,
                                   );

    my $otherFour = new EBox::Types::Int(
                                         fieldName => 'otherFour',
                                         value => 4,
                                        );
    my $two = new EBox::Types::Int(
                                    fieldName => 'two',
                                    value    => 2,
                                   );
    my $seven = new EBox::Types::Int(
                                    fieldName => 'seven',
                                    value    => 7,
                                   );

    

    my $fourWithMin = new EBox::Types::Int(
                                    fieldName => 'fourWithMin',
                                    value    => 4,
                                    min => -5,
                                   );
    my $fourWithMax = new EBox::Types::Int(
                                    fieldName => 'fourWithMax',
                                    value    => 4,
                                    max => 51,
                                   );

    my $text = new EBox::Types::Text(
                                     fieldName => 'text',
                                     value => 'ea',
                                    );

    ok $four->isEqualTo($otherFour), 'checking isEqualTo for equality';
    ok((not $four->isEqualTo($two)), 'checking isEqualTo for inequality');

    is $four->cmp($otherFour), 0,
        'checking cmp method for equality';
    is $four->cmp($two), 1,
        'checking cmp method with a lesser other';
    is $four->cmp($seven), -1,
        'checking cmp method with a greater other';

    cmp_ok($four->cmp($fourWithMin), '==', 0,
           'checking cmp for equalify though the bounds');

    cmp_ok($four->cmp($fourWithMax), '==', 0,
           'checking cmp for equalify though the bounds');

    is $four->cmp($text), undef,
        'whether different types are incomparable';

}


EBox::TestStubs::activateTestStubs();
creationTest();

EBox::Types::Test::defaultValueOk('EBox::Types::Int', 4);


EBox::Types::Test::storeAndRestoreGConfTest('EBox::Types::Int', 4, 1, 4 ,5);

cmpTest();

1;
