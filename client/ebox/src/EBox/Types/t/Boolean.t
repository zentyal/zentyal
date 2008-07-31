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

use Test::More tests => 19;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::Boolean;

EBox::TestStubs::activateTestStubs();

EBox::Types::Test::defaultValueOk('EBox::Types::Boolean', 0);
EBox::Types::Test::defaultValueOk('EBox::Types::Boolean', 1);

EBox::Types::Test::storeAndRestoreGConfTest('EBox::Types::Boolean', 1, 0);
EBox::Types::Test::storeAndRestoreGConfTest('EBox::Types::Boolean', 0, 1);


my $trueBoolean = new EBox::Types::Boolean(
                                       fieldName => 'trueBool',
                                       value => 1,
                                      );


my $falseBoolean = new EBox::Types::Boolean(
                                       fieldName => 'falseBool',
                                       value => 0,
                                      );

EBox::Types::Test::cloneTest($trueBoolean);
EBox::Types::Test::cloneTest($falseBoolean);

ok $falseBoolean->isEqualTo($falseBoolean->clone()), 
    'checking isEqualTo for equality';
ok( (not $falseBoolean->isEqualTo($trueBoolean)),
    'checking isEqualTo for inequality'
  );

is $trueBoolean->cmp($trueBoolean->clone()), 0, 'checking cmp method for equality';
is $trueBoolean->cmp($falseBoolean), 1, 
    'checking cmp method for lesser other object';
is $falseBoolean->cmp($trueBoolean), -1, 
    'checking cmp method for grater other object';

1;
