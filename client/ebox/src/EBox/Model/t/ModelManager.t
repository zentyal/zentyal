# Copyright (C) 2007 Warp Networks S.L.
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

use Test::More tests => 10;
use Test::Exception;
use Test::Deep;

use EBox::Global;
use EBox::Logs;
use EBox::Test::Model;

BEGIN {
    diag ( 'Starting model manager unit test' );
    use_ok( 'EBox::Model::ModelManager' );
}

my $manager = EBox::Model::ModelManager->instance();
isa_ok( $manager, 'EBox::Model::ModelManager');

my $logs = EBox::Global->modInstance('logs');
my $testMod1 = new EBox::Test::Model( gconfmodule => $logs,
                                      directory   => '1',
                                      runtimeIndex => '1');
my $testMod2 = new EBox::Test::Model( gconfmodule => $logs,
                                      directory   => '2',
                                      runtimeIndex => '2');

lives_ok {
    $manager->addModel( '/logs/' . $testMod1->name() . '/' . $testMod1->index(),
                        $testMod1 );
    $manager->addModel( '/logs/' . $testMod2->name() . '/' . $testMod2->index(),
                        $testMod2 );
} 'Adding two test models to the logs menuspace';

is_deeply( $testMod1, $manager->model( '/logs/TestTable/1'),
           'Getting the test model 1');

is_deeply( $testMod2, $manager->model( '/logs/TestTable/2'),
           'Getting the test model 2');

cmp_set ( $manager->model( '/logs/TestTable/' ),
          [ $testMod1, $testMod2 ],
          'Getting multiple model instances');

cmp_set ( $manager->model( '/logs/TestTable/*' ),
          [ $testMod1, $testMod2 ],
          'Getting multiple model instances using *');

lives_ok {
    $manager->removeModel( '/logs/TestTable/1' );
} 'Removing first model';

throws_ok {
    $manager->model('/logs/TestTable/1');
} 'EBox::Exceptions::DataNotFound', 'Removing an inexistant model';

lives_ok {
    $manager->removeModel( '/logs/TestTable/2' );
} 'Removing second model';


