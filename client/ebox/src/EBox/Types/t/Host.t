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

use Test::More tests => 12;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::Host;

EBox::TestStubs::activateTestStubs();

my @validHostNames = (
                     'macaco.monos.org',
                     'gorilla',
                      'baboon5.monos.org',
                     
                    );

my @invalidHostNames = (
                        'badhost_.monos.com',
                       );


my @validHostAddresses = (
                              '198.23.100.12',
                               '10.0.4.3',
                         );

my @invalidHostAddresses = (
                                  '198.23.423.12',
                           );
    


sub newTest  # 7 checks
    {
        foreach my $host (@validHostNames, @validHostAddresses) {
            EBox::Types::Test::createOk(
                                        'EBox::Types::Host',
                                        fieldName => 'test',
                                        value     => $host,
                                        printableName => 'Host valid test',
                                        "Checking instance creation with valid host $host"
                                       );
        }


        foreach my $host (@invalidHostNames, @invalidHostAddresses) {
            EBox::Types::Test::createFail(
                                          'EBox::Types::Host',
                                          fieldName => 'test',
                                          printableName => 'Host invalid test',
                                          value => $host,
                                          "Checking instance creation raises error when called with invalid host $host"
                                         );
        }
}


sub cmpTest # 5 tests
{
    my ($name1, $name2) = @validHostNames;
    my ($addr1, $addr2)  = @validHostAddresses;

    my %equal = (
                 $name1 => $name1,
                 $addr2 => $addr2,
                );

    my %unequal = (
                   $name1 => $name2,
                   $addr1 => $addr2,
                  );

        
    my %incomparable = ( $name1 => $addr1 );

    while (my ($aV, $bV) = each %equal) {
        my $a = _createHost($aV);
        my $b = _createHost($bV);

        is $a->cmp($b), 0, 
            "Checking equality between hosts with value $aV and $bV";
    }

    while (my ($aV, $bV) = each %unequal) {
        my $a = _createHost($aV);
        my $b = _createHost($bV);

        isnt $a->cmp($b), 0, 
            "Checking unequality between hosts with value $aV and $bV";
    }

    while (my ($aV, $bV) = each %incomparable) {
        my $a = _createHost($aV);
        my $b = _createHost($bV);

        is $a->cmp($b), undef, 
          "Checking that hosts with value $aV and $bV are uncomparable";
    }
}


sub _createHost
{
    my ($value) = @_;
    my $h = EBox::Types::Host->new(
                                   fieldName => 'hostInstance',
                                   value     => $value,
                                  );

    $h->setValue($h->printableValue);
    return $h;
}

newTest();
cmpTest();


1;
