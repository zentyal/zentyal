# Copyright (C) 2008 eBox Technologies S.L.
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

# A test for EBox::Types::Float

use strict;
use warnings;

use lib '../../..';

use Test::More tests => 37;

use EBox::TestStubs;

use EBox::Types::Test;
use EBox::Types::Text;
BEGIN {
    use_ok('EBox::Types::Float')
      or die "Cannot load EBox::Types::Float: $!";
}

sub creationTest
{
    my @validCases = (
                      # no defined bounds
                      [
                       value => 1,
                      ],
                      [
                       value => 2.1,
                      ],
                      [
                       value => 14.98,
                      ],
                      [
                       value => 6.02e23,
                      ],
                      # negative value as min bound
                      [
                       min => -5.01,
                       value => 2,
                      ],
                      # value between defined bounds
                      [
                       min => -8,
                       max => 2e1,
                       value => 18,
                      ],
                      # equal than min value
                      [
                       min => 2.0,
                       value => 2,
                      ],
                      # equal than max value
                      [
                       max => 4e2,
                       value => 400.0,
                      ],
                     );

    my @deviantCases = (
                        # default min value must be zero, so no negatives allowed
                        [
                         value => -1.2,
                        ],
                        # mix and max mismatch
                        [
                         max => 4.01,
                         min => 7e1,
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
            'EBox::Types::Float',
            fieldName => 'test',
            @params,
            'Checking instance creation with valid parameters and value'
           );
    }

    foreach my $case_r (@deviantCases) {
        my @params = @{ $case_r };
        EBox::Types::Test::createFail(
            'EBox::Types::Float',
            @params,
            'Checking instance creation raises error when '
             . ' called with invalid parameters and value'
           );
    }

}

sub cmpTest
{
    my $four = new EBox::Types::Float(
        fieldName => 'four',
        value    => 4.0,
       );
    my $otherFour = new EBox::Types::Float(
        fieldName => 'otherFour',
        value => 4e0,
       );
    my $two = new EBox::Types::Float(
        fieldName => 'two',
        value    => 2,
       );
    my $seven = new EBox::Types::Float(
        fieldName => 'seven',
        value    => 7.0,
       );
    my $fourWithMin = new EBox::Types::Float(
        fieldName => 'fourWithMin',
        value     => 4,
        min       => -5,
       );
    my $fourWithMax = new EBox::Types::Float(
        fieldName => 'fourWithMax',
        value     => 4,
        max       => 51,
                                   );
    my $text = new EBox::Types::Text(
        fieldName => 'text',
        value => 'ea',
       );

    ok($four->isEqualTo($otherFour), 'checking isEqualTo for equality');
    ok((not $four->isEqualTo($two)), 'checking isEqualTo for inequality');

    cmp_ok($four->cmp($otherFour), , '==', 0,
           'checking cmp method for equality');
    cmp_ok($four->cmp($two), '==', 1,
           'checking cmp method with a less one');
    cmp_ok($four->cmp($seven), '==', -1,
           'checking cmp method with a greater one');

    cmp_ok($four->cmp($fourWithMin), '==', 0,
           'checking cmp for equalify though the bounds');
    cmp_ok($four->cmp($fourWithMax), '==', 0,
           'checking cmp for equalify though the bounds');

    is($four->cmp($text), undef,
        'whether different types are incomparable');

}

EBox::TestStubs::activateTestStubs();
creationTest();

EBox::Types::Test::defaultValueOk('EBox::Types::Float', 4.0);
EBox::Types::Test::defaultValueOk('EBox::Types::Float', 0);
EBox::Types::Test::defaultValueOk('EBox::Types::Float', 2e3);
EBox::Types::Test::defaultValueOk('EBox::Types::Float', -2.03,
                                  (extraNewParams => [ min => '-5' ]));

EBox::Types::Test::storeAndRestoreGConfTest('EBox::Types::Float',
                                            4.0, 1.02, 2 ,5e0, 3.03e1);

cmpTest();

1;
