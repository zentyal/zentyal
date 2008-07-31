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

use Test::More tests => 3;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::Basic;




sub compareToHashTest
{
    my $basicName   = 'compareHashTest';
    my $basicValue = 'basicValue';
    my $basic = new EBox::Types::Basic(
                                   fieldName => $basicName,
                                   value => $basicValue,
                                  );


    my $hashWoBasic = {
                       fdsdsfa => 'dsfsdasad',
                      };

    my $hashWithWrongBasic = {
                              sfdsdf => 'afsddsfa',
                              $basicName => 'dsfsfd',
                             };

    my $hashWithBasic      = {
                              sgsfdasdfaa => 'assfda',
                              $basicName => $basicValue,
                             };

    ok(
       (not $basic->compareToHash($hashWoBasic)),
    'comparing to hash without the key for the field returns false'
      );
    ok(
       (not $basic->compareToHash($hashWithWrongBasic)),
 'comparing to hash with the key for the field but wrong data returns false'
      );

    ok(
        ($basic->compareToHash($hashWithBasic)),
       'comparing to hash with the key and the data for the field returns true'
      );

}





EBox::TestStubs::activateTestStubs();
compareToHashTest();


1;
