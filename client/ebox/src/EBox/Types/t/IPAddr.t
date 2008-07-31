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

use Test::More qw(no_plan); # tests => 4;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::IPAddr;

EBox::TestStubs::activateTestStubs();


sub creationTest
{
    my %validIPAddrs = (
                         '192.168.45.0' => 24,
                         '45.34.13.123' => 32,
                     
                        );

    my %invalidIPAddrs = (
                           '40.24.3.129' => 35,
                           '40.24.3.129' => -1,
                           '40.24.3.129' => 0,       
                            '45.321.12.12' => 8,
                          # bad mask: hosts need a 32 bit mask
                          '192.168.45.1' => 24,
                          );




    while (my ($ip, $mask) = each %validIPAddrs) {
        EBox::Types::Test::createOk(
                                    'EBox::Types::IPAddr',
                                    fieldName => 'test',
                                    ip   => $ip,
                                    mask => $mask,
                                    "Checking instance creation with valid parameters ip => $ip, mask => $mask"
                                   );
        
    }


    while (my ($ip, $mask) = each %invalidIPAddrs) {
        EBox::Types::Test::createFail(
                                      'EBox::Types::IPAddr',
                                      fieldName => 'test',
                                      printableName => 'test',
                                      ip   => $ip,
                                      mask => $mask,
                                      "Checking instance creation raises error when called with invalid parameters ip => $ip, mask => $mask"
                                     );
    }
    
}


sub cmpTest
{
    my $netA = new EBox::Types::IPAddr(
                                       fieldName => 'netA',
                                       ip => '10.45.43.0',
                                       mask => 24,
                                      );
    my $netB = new EBox::Types::IPAddr(
                                       fieldName => 'netB',
                                       ip => '10.45.43.0',
                                       mask => 26,
                                      );
    my $netC = new EBox::Types::IPAddr(
                                       fieldName => 'netC',
                                       ip => '10.45.21.0',
                                       mask => 24,
                                      );
    my $hostA = new EBox::Types::IPAddr(
                                       fieldName => 'hostA',
                                       ip => '10.45.43.0',
                                       mask => 32,
                                      );
    my $hostEqA = new EBox::Types::IPAddr(
                                       fieldName => 'hostEqA',
                                       ip => '10.45.43.0',
                                       mask => 32,
                                      );


    is $netA->cmp($netA->clone), 0, 'checking cmp for equality within nets';
    isnt $netA->cmp($netB), 0, 'checking cmp for inequality within nets';
    is $netA->cmp($netC), 1, 
        'checking cmp for inequality within nets with the same mask';
    isnt $netA->cmp($hostA), 0, 
        'checking cmp for inequality within a net and a host';

    is $hostA->cmp($hostEqA), 0,
        'checking cmp for equality between hosts';
    
}


creationTest();
cmpTest();



1;
