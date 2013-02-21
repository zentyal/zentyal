# Copyright (C) 2011-2012 eBox Technologies S.L.
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

use Test::More qw(no_plan); # tests => 4;

use lib '../../..';

use EBox::Types::TestHelper;
use EBox::Types::Time;



sub creationTest
{
    my @straightCases = (
           {
               value => '12:45:21',
               expected => {
                   hour => 12,
                   minute => 45,
                   second => 21,
                   printableValue => '12:45:21',
                  },
           },
           {
               value => '00:05:23',
               expected => {
                   hour => 0,
                   minute => 5,
                   second => 23,
                   printableValue => '00:05:23',
                  },
           },
           {
               value => '04:00:03',
               expected => {
                   hour => 4,
                   minute => 0,
                   second => 3,
                   printableValue => '04:00:03',
                  },
           },
           {
               value => '00:05:00',
               expected => {
                   hour => 0,
                   minute => 5,
                   second => 0,
                   printableValue => '00:05:00',
                  },
           },
       );

    foreach my $case (@straightCases) {
        my $value = $case->{value};
        my $instance =
            EBox::Types::TestHelper::createOk(
                'EBox::Types::Time',
                fieldName => 'test',
                "Checking instance creation"
           );

        $instance->setValue($value);
        while (my ($method, $expectedResult) = each %{ $case->{expected} }) {
            my $actualResult = $instance->$method();
            is $actualResult, $expectedResult, "Checking '$method'";
        }
    }
}


EBox::Types::TestHelper::setupFakes();
creationTest();



1;
