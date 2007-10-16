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

# Unit test to check Composite manager

use strict;
use warnings;

use lib '../../..';

use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;

use EBox::Global;
use EBox::Logs;
use EBox::Test::Model;
use EBox::Test::Composite;
use EBox;

BEGIN {
    diag ( 'Starting composite manager unit test' );
    use_ok( 'EBox::Model::CompositeManager' );
}

EBox::init();

my $manager = EBox::Model::CompositeManager->Instance();
isa_ok( $manager, 'EBox::Model::CompositeManager');

my $logs = EBox::Global->modInstance('logs');
my $testMod1 = new EBox::Test::Model( gconfmodule => $logs,
                                      directory   => '1',
                                      runtimeIndex => '1');
my $testMod2 = new EBox::Test::Model( gconfmodule => $logs,
                                      directory   => '2',
                                      runtimeIndex => '2');

my $testComp1 = new EBox::Test::Composite( 1 );
my $testComp2 = new EBox::Test::Composite( 2 );

lives_ok {
    $manager->addComposite( '/logs/' . $testComp1->name() . '/' . $testComp1->index(),
                            $testComp1 );
    $manager->addComposite( '/logs/' . $testComp2->name() . '/' . $testComp2->index(),
                            $testComp2 );
} 'Adding two test composites to the logs namespace';

is_deeply( $testComp1, $manager->composite( '/logs/TestComposite/1'),
           'Getting the test composite 1');

is_deeply( $testComp2, $manager->composite( '/logs/TestComposite/2'),
           'Getting the test composite 2');

cmp_set ( $manager->composite( '/logs/TestComposite/' ),
          [ $testComp1, $testComp2 ],
          'Getting multiple composite instances');

cmp_set ( $manager->composite( '/logs/TestComposite/*' ),
          [ $testComp1, $testComp2 ],
          'Getting multiple composite instances using *');

lives_ok {
    $manager->removeComposite( '/logs/TestComposite/1' );
} 'Removing first composite';

throws_ok {
    $manager->composite('/logs/TestComposite/1');
} 'EBox::Exceptions::DataNotFound', 'Removing an inexistant composite';

lives_ok {
    $manager->removeComposite( '/logs/TestComposite/2' );
} 'Removing second composite';
