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

# Unit test regarding to autoload functions from DataModel

use strict;
use warnings;

use lib '../../..';

use Test::More qw(no_plan);
use Test::Exception;
use Test::MockObject;
use Test::Deep;

use EBox::TestStubs;
use EBox::Objects;
use EBox::Objects::Model::MemberTable;
use EBox::Model::ModelManager;

BEGIN {
    use_ok ( 'EBox::Test::Model' );
}

# Method: _fakeSetUpModels
#
#      Fake to manage model manager within this test suite
#
sub _fakeSetUpModels
  {

      my ($self) = @_;

      $self->{models}->{MemberTable} = new EBox::Objects::Model::MemberTable(
                         gconfmodule => EBox::Global->modInstance('objects'),
                         directory   => 'memberTable'
                                                                            );

  }

# Fake the model manager
Test::MockObject->fake_module('EBox::Model::ModelManager',
                              _setUpModels => \&_fakeSetUpModels);

# Fake eBox
EBox::TestStubs::activateTestStubs();
EBox::TestStubs::fakeEBoxModule( name => 'foo' );
EBox::TestStubs::fakeEBoxModule( name => 'objects',
                                 class  => 'EBox::Objects',
                               );
my $fakeModule = EBox::Global->modInstance('foo');

my $model = new EBox::Test::Model(
                                  gconfmodule => $fakeModule,
                                  directory   => 'model'
                                 );

isa_ok ( $model, 'EBox::Test::Model' );

lives_ok
  {
      $fakeModule->delete_dir($model->directory());
  } 'deleting previous data';

diag ('Checking method name parsing');

# Check the method Name
throws_ok
  {
      $model->addFooToTestTable();
  } 'EBox::Exceptions::Internal', 'Wrong submodel name';

throws_ok
  {
      $model->fooTestTable();
  } 'EBox::Exceptions::Internal', 'Wrong action name';

diag( 'Checking additions' );

my $addedId;
ok ( $addedId = $model->addTestTable(
                                     compulsory_addr     => '192.168.45.120/32',
                                     compulsory_boolean  => 1,
                                     compulsory_int      => 12,
                                     compulsory_select   => 'a',
                                     compulsory_text     => 'foo',
                                     compulsory_mac      => '00:13:72:D8:23:E4',
                                     compulsory_password => 'foobar',
                                     port_range          => '1:20',
                                     union               => { 'foo' => 'bar' },
                                     inverse_select      => 'b',
                                     inverse_union       => { 'inverse_foo' => 'baz' },
                                     compulsory_service  => '200/tcp',
                                     member              => [ {
                                                               name    => 'a',
                                                               ipaddr  => '192.168.45.1/32',
                                                              },
                                                              {
                                                               name    => 'b',
                                                               ipaddr  => '192.168.45.2/32',
                                                               macaddr => '00:13:72:D8:23:E3'
                                                              }
                                                            ],
                                    ),
     'Adding using add<tableName> pattern' );

ok ( $model->row($addedId), 'Check added was done correctly' );

my $toRemoveId;
ok ( $toRemoveId = $model->addTestTable(
                                        compulsory_addr     => '10.168.5.120/32',
                                        compulsory_boolean  => 1,
                                        compulsory_int      => 112,
                                        compulsory_select   => 'b',
                                        compulsory_text     => 'foo',
                                        compulsory_mac      => '01:13:72:D8:23:E4',
                                        compulsory_password => 'foobar',
                                        port_range          => '1:20',
                                        union               => { 'foo' => 'bar' },
                                        inverse_select      => 'b',
                                        inverse_union       => { 'inverse_foo' => 'baz' },
                                        compulsory_service  => '200/tcp',
                                        member              => [ {
                                                                  name    => 'ada',
                                                                  ipaddr  => '192.1.45.1/32',
                                                                 },
                                                               ],
                                       ),
     'Adding another one using add<tableName> pattern' );

cmp_ok ( $model->size(), '==', 2, 'Addition done correctly');

throws_ok
  {
      $model->addTestTable(
                           compulsory_addr     => '192.168.45.120/32',
                           compulsory_int      => 12,
                           compulsory_select   => 'a',
                           compulsory_text     => 'foo',
                           compulsory_mac      => '00:13:72:D8:23:E4',
                           compulsory_password => 'foobar',
                           port_range          => '1:20',
                           union               => { 'foo' => 'bar' },
                           inverse_select      => 'b',
                           inverse_union       => { 'inverse_foo' => 'baz' },
                           compulsory_service  => '200/tcp',
                          ),
  } 'EBox::Exceptions::External', 'Missing compulsory field';

my $addedMemberId;
ok ( $addedMemberId = $model->addMemberToTestTable($addedId,
                                                   name    => 'c',
                                                   ipaddr  => '192.168.45.3/32',
                                                   macaddr => '00:13:72:D8:43:E3'),
     'Adding a member to the test table using add<submodelFieldName>To<tableName> pattern');

throws_ok
  {
      $addedMemberId = $model->addMemberToTestTable(name   => 'd',
                                                    ipaddr => '192.168.45.2/23');
  } 'EBox::Exceptions::Internal', 'Missing identifier to insert the row';

diag( 'Checking removals' );

ok ( $model->delTestTable( $toRemoveId ), 'Delete a row in a model');

is ( $model->row($toRemoveId), undef, 'Remove done correctly');

throws_ok
  {
      $model->delTestTable ( 'flooba' );
  } 'EBox::Exceptions::DataNotFound', 'Deleting an unexistant row from a model';

ok ( $model->delMemberToTestTable ( $addedId, 'c' ), 'Delete a row in a submodel');

throws_ok
  {
      $model->delMemberToTestTable ( $addedId, 'floobal');
  } 'EBox::Exceptions::DataNotFound', 'Deleting an unexistant row from a submodel';

diag ( 'Checking get' );

cmp_ok ( $model->getTestTable( $addedId )->{plainValueHash}->{compulsory_password},
         'eq', 'foobar', 'Getting a complete row');

cmp_ok ( $model->getTestTable( $addedId, [ 'compulsory_int' ] )->value(), '==', 12,
         'Getting one field from a row in a model');

cmp_deeply ( $model->get( $addedId, [ 'compulsory_text', 'inverse_select' ] )->{plainValueHash},
             { compulsory_text => 'foo', 'inverse_select' => 'b' },
             'Getting two fields from a row in a model');

is (  $model->get( 'flooba' ), undef, 'Getting an unexistant row');

throws_ok
  {
      $model->getTestTable( $addedId, ['foobar'] );
  } 'EBox::Exceptions::Internal', 'Getting an unexistant field';

throws_ok
  {
      $model->get( $addedId, 'ada', 'dfa' );
  } 'EBox::Exceptions::Internal', 'Wrong call to get something in a model';

cmp_ok ( $model->getMemberToTestTable( $addedId, 'a' )->{printableValueHash}->{ipaddr},
         'eq', '192.168.45.1/32', 'Getting a row within a submodel' );

cmp_ok ( $model->getMemberToTestTable( $addedId, 'b', [ 'macaddr' ])->value() ,
         'eq', '00:13:72:D8:23:E3',
         'Getting a single field from a row within a submodel' );

cmp_deeply ( $model->getMemberToTestTable( $addedId, 'b', [ 'ipaddr', 'macaddr' ])->{printableValueHash},
             { ipaddr => '192.168.45.2/32', macaddr => '00:13:72:D8:23:E3' },
             'Getting two fields from a row within a submodel' );

throws_ok {
    $model->getMemberToTestTable( $addedId, 'foolba' );
} 'EBox::Exceptions::DataNotFound', 'Getting an unexistant row in a submodel';

throws_ok
  {
      $model->getMemberToTestTable( $addedId, 'a', [ 'fadfa' ] );
  } 'EBox::Exceptions::Internal', 'Getting an unexistant field in a row in a submodel';

throws_ok
  {
      $model->getMemberToTestTable( $addedId, 'ada', 'dfa' );
  } 'EBox::Exceptions::Internal', 'Wrong call to get something in a sub model';

diag ( 'Checking update' );

lives_ok
  {
      $model->setTestTable( $addedId, compulsory_int => 232);
  } 'Updating a field in a model';

cmp_ok ( $model->get( $addedId, ['compulsory_int'])->value(), '==', 232,
         'Update a field in a model correctly done');

lives_ok
  {
      $model->set( $addedId,
                   compulsory_addr => '192.168.5.21/32',
                   compulsory_text => 'bar' );
  } 'Updating two fields in a model';

cmp_deeply ( $model->get($addedId, [ 'compulsory_addr', 'compulsory_text' ])->{printableValueHash},
             { compulsory_addr => '192.168.5.21/32', compulsory_text => 'bar' },
             'Update two fields correctly done in a model');

lives_ok
  {
      $model->setTestTable( $addedId, member => [
                                                 'a' => {
                                                         name    => 'ada',
                                                         ipaddr  => '192.168.45.1/32',
                                                        },
                                                 'b' => {
                                                         ipaddr  => '192.168.45.2/32',
                                                         macaddr => '00:13:72:D8:23:E4'
                                                        }
                                                ]);
  } 'Updating a submodel field in a model';

isnt ( $model->getMemberToTestTable( $addedId, 'ada' ), undef,
       'Updating a submodel done correctly');

throws_ok
  {
      $model->set( $addedId, 'daf');
  } 'EBox::Exceptions::Internal', 'Updating using a wrong call';

throws_ok
  {
      $model->set( $addedId, 'foolba' => '232');
  } 'EBox::Exceptions::Internal', 'Updating an unexistant field in a model';

lives_ok
  {
      $model->setMemberToTestTable( $addedId, 'a', name => 'ada' );
  } 'Updating an index field in a model';

isnt ( $model->getMemberToTestTable( $addedId, 'ada'), undef, 
       'Update an index field in a submodel correctly done');

lives_ok
  {
      $model->setMemberToTestTable( $addedId, 'ada',
                                    ipaddr  => '192.168.1.21/32',
                                    macaddr => '00:13:72:D8:23:E1' );
  } 'Updating two fields in a sub model';

cmp_deeply ( $model->getMemberToTestTable($addedId, 'ada', [ 'ipaddr', 'macaddr' ])
             ->{printableValueHash},
             { ipaddr => '192.168.1.21/32', macaddr => '00:13:72:D8:23:E1' },
             'Update two fields correctly done in a sub model');

throws_ok
  {
      $model->setMemberToTestTable( $addedId, 'foolba', name => '12');
  } 'EBox::Exceptions::DataNotFound', 'Updating an existant row in a sub model';

throws_ok
  {
      $model->setMemberToTestTable( $addedId, 'ada', 'foolba' => '232');
  } 'EBox::Exceptions::Internal', 'Updating an unexistant field in a sub model';


1;
