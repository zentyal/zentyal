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

use Test::More tests => 7;

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::Abstract;

EBox::TestStubs::activateTestStubs();


my $class = 'EBox::Types::Abstract';

EBox::Types::Test::createFail($class, 
           printableName => 'test',
           'Creating instance without fieldName  must fail',
          );
EBox::Types::Test::createOk($class,
         fieldName => 'ea',
         'Creating instance with fieldName succeed',
        );

EBox::Types::Test::createFail($class,
           fieldName => 'test',
           optional => 1,
           defaultValue => 'whatever',
           'Optional and defaultValue parameters are incompatible',
          );


my $fieldName = 'testInstnace';
my $instance = EBox::Types::Abstract->new(
                                          fieldName => $fieldName
                                         );
is $instance->printableName, $fieldName,
    'checking that printableName defaults to fieldName';


EBox::Types::Test::cloneTest($instance);

1;
