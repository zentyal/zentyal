# Copyright (C) 2008-2013 Zentyal S.L.
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

use Test::More tests => 6;

use lib '../../..';

use EBox::Types::TestHelper;
use EBox::Types::Abstract;

EBox::Types::TestHelper::setupFakes();

my $class = 'EBox::Types::Abstract';

EBox::Types::TestHelper::createFail($class,
           printableName => 'test',
           'Creating instance without fieldName  must fail',
          );
EBox::Types::TestHelper::createOk($class,
         fieldName => 'ea',
         'Creating instance with fieldName succeed',
        );

EBox::Types::TestHelper::createFail($class,
           fieldName => 'test',
           optional => 1,
           defaultValue => 'whatever',
           'Optional and defaultValue parameters are incompatible',
          );

my $fieldName = 'testInstance';
my $instance = EBox::Types::Abstract->new(
                                          fieldName => $fieldName
                                         );

# FIXME: this behavior was changed in 4b4381dda729c079516220a397a0dcdf5210285a
#is $instance->printableName, $fieldName,
#    'checking that printableName defaults to fieldName';

EBox::Types::TestHelper::cloneTest($instance);

1;
