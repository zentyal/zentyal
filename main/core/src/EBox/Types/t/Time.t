# Copyright (C) 2011-2013 Zentyal S.L.
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

use Test::More  tests => 36;

use lib '../../..';

use EBox::Types::TestHelper;
use EBox::Types::Time;

sub creationTest
{
    my @straightCases = (
           # no default value
           {
               expected => {
                   printableValue => '',
               }
           },
           {
               value => undef,
               expected => {
                   printableValue => '',
               }
           },
           # with default values
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

    my @deviantCases = (
        #invalid number of components
        '21', '21:23', '11:22:33:44',
        # blank component
        '21::21', ':11:11', '10:10::',
        # no digit component
        'aa:21:12', '00:a2:00', '00:00:2a',
        # out of range
        '60:00:00', '00:60:00', '00:00:60',
       );

    foreach my $case (@deviantCases) {
            EBox::Types::TestHelper::createFail(
                'EBox::Types::Time',
                fieldName => 'test',
                defaultValue => $case,
                "Checking instance creation with incorrect value $case"
           );
    }

    foreach my $case (@straightCases) {
        my @creationParams = ( fieldName => 'test',);
        if (exists $case->{value}) {
            push @creationParams, (defaultValue => $case->{value});
        }
        my $instance =
            EBox::Types::TestHelper::createOk(
                'EBox::Types::Time',
                @creationParams,
                "Checking instance creation"
           );

        while (my ($method, $expectedResult) = each %{ $case->{expected} }) {
            my $actualResult = $instance->$method();
            is $actualResult, $expectedResult, "Checking '$method'";
        }
    }
}

EBox::Types::TestHelper::setupFakes();
creationTest();

1;
