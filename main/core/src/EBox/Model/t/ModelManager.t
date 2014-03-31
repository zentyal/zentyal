# Copyright (C) 2007 Warp Networks S.L.
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

# Unit test to check ModelManager

use strict;
use warnings;

use lib '../../..';

use Test::More tests => 8;
use Test::Exception;
use Test::Deep;
use EBox::Test::Model;
use EBox::TestStubs;

BEGIN {
    diag ( 'Starting model manager unit test' );
    use_ok( 'EBox::Model::Manager' );
}

EBox::TestStubs::activateTestStubs();

my $manager = EBox::Model::Manager->instance();
isa_ok($manager, 'EBox::Model::Manager');

EBox::TestStubs::fakeModule(name => 'logs');
my $logs = EBox::Global->modInstance('logs');
my $testMod = new EBox::Test::Model(confmodule => $logs, directory => 'foobar');

lives_ok {
    $manager->addModel($testMod);
} 'Adding two test models to the logs menuspace';

is_deeply($testMod, $manager->model('logs/TestTable'), 'Getting the test model');

is_deeply($testMod, $manager->model('TestTable'), 'Getting the test model by name');

is('logs', $manager->model('TestTable')->parentModule()->name(), 'Checking parentModule name');

lives_ok {
    $manager->removeModel('logs', 'TestTable');
} 'Removing model';

throws_ok {
    $manager->model('logs', 'TestTable');
} 'EBox::Exceptions::DataNotFound', 'Removing an inexistant model';

1;
