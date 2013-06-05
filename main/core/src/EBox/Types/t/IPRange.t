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

use Test::More qw(no_plan); # tests => 4;

use lib '../../..';

use EBox::Types::TestHelper;
use EBox::Types::IPRange;
EBox::Types::TestHelper::setupFakes();

sub creationTest
{
    my @straightCases = (
           {
               begin => '192.168.5.6',
               end => '192.168.5.12',
               expectedAddresses => [
                   '192.168.5.6',
                   '192.168.5.7',
                   '192.168.5.8',
                   '192.168.5.9',
                   '192.168.5.10',
                   '192.168.5.11',
                   '192.168.5.12',
                  ],
           },
           # max number of addresses
           {
               begin => '10.0.0.0',
               end => '10.255.255.255',
           },
       );

    my @deviantCases = (
                        # bad begin IP
                        {
                         begin => 'mustnotbedomain.com',
                         end => '10.45.3.3',
                        },
                        # bad end IP
                        {
                         begin => '4.3.4.1',
                         end => '4.3.4.2.1',
                        },
                        # end IP < begin IP
                        {
                         begin => '45.32.12.12',
                         end => '10.34.11.12',
                        },
                        # excesive number of addresses
                        {
                         begin => '10.0.0.0.0',
                         end   => '11.0.0.0',
                        }

                       );

    my $addressOutside = '192.168.100.123';

    foreach my $case (@deviantCases) {
        my $begin = $case->{begin};
        my $end   = $case->{end};

        EBox::Types::TestHelper::createFail(
            'EBox::Types::IPRange',
            fieldName => 'test',
            begin   => $begin,
            end => $end,
            "Checking instance creation  with  incorrect parameters raises error.( begin => $begin, end => $end)"
                                     );
    }

    foreach my $case (@straightCases) {
        my $begin = $case->{begin};
        my $end   = $case->{end};
        EBox::Types::TestHelper::createOk(
            'EBox::Types::IPRange',
            fieldName => 'test',
            begin   => $begin,
            end => $end,
            "Checking instance creation with valid parameters begin => $begin, end => $end"
           );


        my $range = EBox::Types::IPRange->new(
                                              fieldName => 'test',
                                              begin => $begin,
                                              end => $end);



        if (not exists $case->{expectedAddresses} ) {
            next;
        }


        my $addresses = $range->addresses();
        is_deeply $addresses, $case->{expectedAddresses},
            'Checking addresses in the range';
        my ($addressInside) = @{ $case->{expectedAddresses} };
        ok $range->isIPInside($addressInside),
            'Checking that address is correctly reported inside the range';
        my $outsideAddressIsOutside = not $range->isIPInside($addressOutside);
        ok $outsideAddressIsOutside,
            'Checking that outisdeaddress is correctly reported outside the range';
    }
}

sub cmpTest
{
    my $rangeA = new EBox::Types::IPRange(
                                       fieldName => 'rangeA',
                                       begin => '10.45.43.0',
                                       end => '10.45.44.0',
                                      );
    my $rangeB = new EBox::Types::IPRange(
                                       fieldName => 'rangeB',
                                       begin => '10.45.52.3',
                                       end => '10.46.52.4',
                                      );
    my $rangeC = new EBox::Types::IPRange(
                                       fieldName => 'rangeB',
                                       begin => '10.45.12.3',
                                       end => '10.45.12.4',
                                      );

    is $rangeA->cmp($rangeA->clone), 0, 'checking cmp for equality within nets';
    is $rangeA->cmp($rangeB), -1, 'checking cmp for inequality within nets (comparaing against bigger)';
    is $rangeA->cmp($rangeC), 1, 'checking cmp for inequality within nets (comparing against smaller)';
}

creationTest();
cmpTest();

1;
