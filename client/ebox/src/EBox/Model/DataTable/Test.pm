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

package EBox::Model::DataTable::Test;

use lib '../../..';
use base 'EBox::Test::Class';

use strict;
use warnings;


use Test::More;;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;
use Perl6::Junction qw(any);
use POSIX;


use EBox::Types::Abstract;

use EBox::Model::Row;
use EBox::Model::DataTable;
use EBox::Model::ModelManager;
use EBox::Types::Abstract;
use EBox::Types::HasMany;
use EBox::Types::Text;



{
    my $rowIdUsed;

    no warnings 'redefine';
    sub EBox::Model::ModelManager::warnIfIdIsUsed
    {
        my ($self, $context, $id) = @_;
        if (not defined $rowIdUsed) {
            return;
        }
        elsif ($rowIdUsed eq $id) {
            throw EBox::Exceptions::DataInUse('fake warnIfIdIsUsed: row in use');
        }
       
    }

    sub EBox::Model::ModelManager::warnOnChangeOnId
    {
        my ($self, $tableName, $id) = @_;
        if (not defined $rowIdUsed) {
            return;
        }
        elsif ($rowIdUsed eq $id) {
            throw EBox::Exceptions::DataInUse('fake warnIfIdIsUsed: row in use');
        }
    }

    sub EBox::Model::ModelManager::removeRowsUsingId
    {
        # do nothing
    }

    sub EBox::Model::ModelManager::modelActionTaken
    {
        # do nothing
    }



    sub setRowIdInUse
    {
        my ($rowId) = @_;
        $rowIdUsed = $rowId;
    }
}

sub setEBoxModules : Test(setup)
{
    EBox::TestStubs::fakeEBoxModule(name => 'fakeModule');

}

sub clearGConf : Test(teardown)
{
  EBox::TestStubs::setConfig();
}


sub deviantTableTest : Test(6)
{
    my ($self) = @_;

    my @cases;
    push @cases,  [  'empty table description' => {
                                                   tableName => 'test',
                         }

                  ];
    push @cases,  [  'empty tableDescription' => {
                            tableDescription => [],
                            tableName => 'test',
                         }

                  ];

    push @cases, [
                  'repeated field name' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'repeated',
                                                                          ),
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'repeated',
                                                                          ),                                                                    
                                                                   ],

                                                tableName => 'test',
                                              }
                  
                 ];
    push @cases, [
                  'no table name' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'field1',
                                                                          ),
                                                                   
                                                                   ],


                                              }
                  
                 ];

#  XXX this feature was temporally removed form DataTable
#     push @cases, [
#                   'sortedBy uses unexistent field' => {
#                                                tableDescription => [
#                                                  new EBox::Types::Abstract(
#                                                        fieldName => 'field1',
#                                                                           ),
                                                                   
#                                                                    ],

#                                                 tableName => 'test',
#                                                 sortedBy => 'unexistentField',
#                                               }
                  
#                  ];

    push @cases, [
                  'sortedBy and order are both set' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'field1',
                                                                          ),
                                                                   
                                                                   ],

                                                tableName => 'test',
                                                sortedBy => 'field1',
                                                order    => 1,
                                              }
                  
                 ];
    
    foreach my $case_r (@cases) {
        my ($caseName, $table) = @{ $case_r };
        my $dataTable = $self->_newDataTable($table);

        dies_ok {
            $dataTable->table();
        } "expecting error with deviant table case: $caseName";
    }


}

sub tableTest : Test(6)
{
    my ($self) = @_;

    my @cases;
    push @cases,  [  'simple table' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'field1',
                                                                          ),
                                                                   
                                                                   ],
                                                   tableName => 'test',
                         }

                  ];
    push @cases,  [  'sorted table' => {
                                        tableDescription => [
                                            new EBox::Types::Abstract(
                                                      fieldName => 'field1',
                                                                     ),
                                            new EBox::Types::Abstract(
                                                       fieldName => 'field2',
                                                                     ),
                                                             
                                                            ],
                                        tableName => 'test',
                                        sortedBy => 'field1',
                                       }

                  ];
    push @cases,  [  'ordered by user table' => {
                                        tableDescription => [
                                            new EBox::Types::Abstract(
                                                      fieldName => 'field1',
                                                                     ),
                                            new EBox::Types::Abstract(
                                                       fieldName => 'field2',
                                                                     ),
                                                             
                                                            ],
                                        tableName => 'test',
                                        order => 1,
                                       }

                  ];

    foreach my $case_r (@cases) {
        my ($caseName, $table) = @{ $case_r };
        my $dataTable = $self->_newDataTable($table);

        my $tableFromModel;
        lives_ok {
            $tableFromModel = $dataTable->table();
        } "checking first call to table method with: $caseName";

        ok exists $tableFromModel->{tableDescriptionByName}, 'checking that some fileds were inserted by first time setup';
    }

}


sub contextNameTest : Test(2)
{
    my ($self) = @_;
    my $dataTable = $self->_newDataTable();

    my $expectedContenxtName = '/fakeModule/test/';
    is $dataTable->contextName, $expectedContenxtName,
        'checking contextName';

    # text with index
    $dataTable->set_always('index' => 'indexed');
$expectedContenxtName = '/fakeModule/test/indexed';
    is $dataTable->contextName, $expectedContenxtName,
        'checking contextName for model with index';


}





sub deviantAddTest : Test(4)
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();

    my $dataTable = $self->_newDataTable($tableDescription);

    # add one row 
    $dataTable->add(uniqueField => 'a', regularField => 'regular');

    my %invalidAdds = (
                       'unique field repeated' => [
                                                   uniqueField => 'a',
                                                   regularField =>'adaads',
                                                  ],
                       'missing required field' => [
                                                    uniqueField => 'c',
                                                   ],

                      );

    
    my $dataTableSize = $dataTable->size();
    while (my ($testName, $addParams_r) = each %invalidAdds) {
        dies_ok {
            $dataTable->add(  @{ $addParams_r });
        } "expecting error with incorrect row addition: $testName";
        is $dataTable->size(), $dataTableSize,
            'checking wether no new rows were added using size method';
    }

}

sub addTest : Test(25)
{
    my ($self) = @_;
    my $tableDescription = _tableDescription4fields();

    my $dataTable = $self->_newDataTable($tableDescription);


    
    my @correctAdds = (
                       # only mandatory
                       [ uniqueField => 'a', regularField => 'regular' ],
                       # value for default field
                       [ 
                        uniqueField => 'b', regularField => 'regular', 
                        defaultField => 'noDefaultText' 
                       ],
                       # value for optional field
                       [ 
                        uniqueField => 'c', regularField => 'regular', 
                        optionalField => 'noDefaultText' 
                       ],
                      );

    my @addParams;
    my %expectedAddedRowFields;

    $dataTable->mock(validateTypedRow => sub {
                         my @callParams = @_;


                         my %expectedChanged = @addParams;
                         if (not exists $expectedChanged{defaultField}) {
                             # defualt field always is added with its default value
                             $expectedChanged{defaultField} = 'defaultText';
                         }

                         # for and add call changed and all fields are the same
                         my %expectedAll = %expectedChanged;

                         _checkValidateTypedRowCall(
                                            callParams => \@callParams,
                                            expectedAction => 'add',
                                            expectedChanged => \%expectedChanged,
                                            expectedAll     => \%expectedAll,
                                                   );
                     }
                    );

    $dataTable->mock(addedRowNotify => sub {
                         my @callParams = @_;

                         _checkAddeRowNotifyCall(
                                    callParams => \@callParams,
                                    expectedFields => \%expectedAddedRowFields
                                                )
                         }
                    );



    foreach my $addCase (@correctAdds) {
        @addParams =  @{ $addCase  };
        %expectedAddedRowFields = @addParams;
        if (not exists $expectedAddedRowFields{defaultField}) {
            # default field always is added with its default value
            $expectedAddedRowFields{defaultField} = 'defaultText';
        }
        if (not exists $expectedAddedRowFields{optionalField}) {
            # optional field exists with undef value
            $expectedAddedRowFields{optionalField} = undef;
        }

        my $rowId;
        lives_ok {
            $rowId = $dataTable->add( @addParams );
        } "adding correct rows => @addParams";

        $dataTable->called_ok('validateTypedRow');
        $dataTable->called_ok('addedRowNotify');
        $dataTable->clear(); # clear mock object call registed

        my $row = $dataTable->row($rowId);
        _checkRow(
                  row => $row,
                  expectedFields => \%expectedAddedRowFields,
                  testName => 'checking new added row after retrieval'
                 );
    }

    is $dataTable->size(), scalar @correctAdds,
        'Checking data table size after the additions';
}


# XXX TODO:
# deviant test up and down in no-prderer table
# straight test of moving up and down
sub moveRowsTest : Test(8)
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();
    $tableDescription->{order}   = 1;

    my $dataTable = $self->_newDataTable($tableDescription);
    $dataTable->set_true('movedUpRowNotify', 'movedDownRowNotify');


    
    my @tableRows = (
                [ uniqueField => 'a', regularField => 'regular' ],
                [ uniqueField => 'b', regularField => 'regular', ],
               );
    foreach (@tableRows) {
        $dataTable->add( @{  $_  }  );
    }
 
    my @order = @{ $dataTable->order() };


    my $upperRow = $order[0];
    my $lowerRow = $order[1];        

    $dataTable->moveUp($upperRow);
    is_deeply $dataTable->order, \@order, 
        'checking that moving up the upper row has not changed the order';
    ok ((not $dataTable->called('movedUpRowNotify')), 
        'Checking that movedUpRowNotify has not been triggered');
    $dataTable->clear();

    $dataTable->moveDown($lowerRow);
    is_deeply $dataTable->order, \@order, 
        'checking that moving down the  lower row has not changed the order';
    ok ((not $dataTable->called('movedDownRowNotify')), 
        'Checking that movedDownRowNotify has not been triggered');
    $dataTable->clear();

    my @reverseOrder = reverse @order;
    $dataTable->moveUp($lowerRow);
    is_deeply $dataTable->order, \@reverseOrder,
        'checking that lower row was moved up';
    ok ( $dataTable->called('movedUpRowNotify'), 
        'Checking that movedUpRowNotify has  been triggered');
    $dataTable->clear();

    $dataTable->moveDown($lowerRow);
    is_deeply $dataTable->order, \@order,
        'checking that upper row was moved down';
    ok ( $dataTable->called('movedDownRowNotify'), 
        'Checking that movedDownRowNotify has  been triggered');
    $dataTable->clear();
}



sub removeAllTest : Test(8)
{
    my ($self)  = @_;

    my $dataTable = $self->_newPopulatedDataTable();

    lives_ok {
        $dataTable->removeAll(0);
    } 'removeAll without force in a table without autoremove';
    is $dataTable->size, 0, 'checking that after removing all rows the table is empty';

    lives_ok {
        $dataTable->removeAll();
    } 'call removeAll in a empty table';



    $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();
    my $rowId =  $dataTable->rows()->[0]->id();
    setRowIdInUse($rowId);


    throws_ok {
        $dataTable->removeAll(0)
    } 'EBox::Exceptions::DataInUse', 
       'Checking  removeAll without force with autoremove and used files';

    lives_ok {
        $dataTable->removeAll(1)
    } 'Checking  removeAll with force with autoremove and used files';
    is $dataTable->size, 0, 'checking that after removing all rowswith force=1  the table is empty';

    # automatic remve with no row used case
    setRowIdInUse(undef);
    $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();

    lives_ok {
        $dataTable->removeAll(0)
    } 'Checking  removeAll withoy force with autoremove option but no used rows';
        is $dataTable->size, 0, 'checking that after removing all rows with force-0 but not used rows  the table is empty';
}


sub removeRowTest : Test(13)
{
    my ($self) = @_;

    my $dataTable;
    my $id;

    my $notifyMethodName = 'deletedRowNotify';


    $dataTable = $self->_newPopulatedDataTable();

    $dataTable->can($notifyMethodName) or
        die "bad notify method name $notifyMethodName";
    $dataTable->set_true($notifyMethodName);

    my @ids = map {
        $_->id()
    } @{ $dataTable->rows() };


    dies_ok {
        $dataTable->removeRow('inexistent');
    } 'expecting error when trying to remove a inexistent row';
    ok (
        (not $dataTable->called($notifyMethodName)),
        'checking that on error notify method was not called',
       );

    $id = shift @ids;
    lives_ok {
        $dataTable->removeRow($id);
    } 'removing row';
    is $dataTable->row($id), undef,
        'checking that row is not longer in the table';
    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();

    # tests with automatic remove

    $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();
    $dataTable->set_true($notifyMethodName);

    @ids = map {
        $_->id()
    } @{ $dataTable->rows() };
    $id = shift @ids;

    setRowIdInUse($id);
    


    throws_ok {
        $dataTable->removeRow($id, 0)
    } 'EBox::Exceptions::DataInUse',
      'removeRow in a row reported as usedin a automaticRemove table  raises DataInUse execption';
    ok (
        (not $dataTable->called($notifyMethodName)),
        'checking that on DataInUse excpeion notify method was not called',
       );

    lives_ok {
        $dataTable->removeRow($id, 1)
    } 'removeRow with force in a used row within a automaticRemove table works';
    is $dataTable->row($id), undef,
        'checking that row is not longer in the table';
    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();
    
    $id = shift @ids;
    lives_ok {
        $dataTable->removeRow($id, 0)
    } 'removeRow with force in a unused row within a automaticRemove table works';
    is $dataTable->row($id), undef,
        'checking that row is not longer in the table';
    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();
}


sub deviantSetTest : Test(12)
{
    my ($self) = @_;
    my $dataTable = $self->_newPopulatedDataTable();
    my @ids = map {
        $_->id()
    } @{ $dataTable->rows() };
    my $id = shift @ids;

    my $notifyMethodName = 'updatedRowNotify';


    my $repeatedUnique = $dataTable->row($ids[0])->valueByName('uniqueField');
    $self->_checkDeviantSet(
                               $dataTable,
                               $id,
                               {
                                uniqueField => $repeatedUnique,
                                regularField => 'distinctData',
                                defaultField => 'aa',
                               },
                               'Checking that setting repeated unique field raises error'
                              );



   $self->_checkDeviantSet(
                               $dataTable,
                               $id,
                               {
                                inexistentField => 'inexistentData',
                                uniqueField =>  'zaszxza',
                                regularField => 'distinctData',
                                defaultField => 'aa',

                               },
                              'Checking that setting a inexistent field raises error'

                             );


    $dataTable->mock('validateTypedRow' => sub { die 'always fail' });
    $self->_checkDeviantSet(
                               $dataTable,
                               $id,
                               {
                                uniqueField =>  'zaszxza',
                                regularField => 'distinctData',
                                defaultField => 'aa',

                               },
                              'Checking error when validateTypedRow fails'

                             );


}


sub _checkDeviantSet # counts as 4 tests
{
    my ($self, $dataTable, $id, $params_r, $testName) = @_;
    my $notifyMethodName = 'updatedRowNotify';

    my $version = $dataTable->_storedVersion();
    my $oldValues = $dataTable->row($id)->hashElements();

    dies_ok {
        $dataTable->set(
                         $id,
                         %{ $params_r }
                        );

    } $testName;


    is_deeply $dataTable->row($id)->hashElements, $oldValues,
        'checking that erroneous operation has not changed the row values';
    is $version, $dataTable->_storedVersion(), 
     'checking that stored table version has not changed after incorrect set operation';
    ok (
        (not $dataTable->called($notifyMethodName)),
        'checking that on error notify method was not called',
       );
}


sub _checkSet
{
    my ($self, $dataTable, $id, $changeParams_r, $testName) = @_;
    my $notifyMethodName = 'updatedRowNotify';
    my %changeParams = %{ $changeParams_r };

    my $oldSize = $dataTable->size();
    my $version = $dataTable->_storedVersion();
    lives_ok {
        $dataTable->set (
                         $id,
                         %changeParams,
                        );

    } $testName;

    my $row = $dataTable->row($id);
    while (my ($field, $value) = each %changeParams) {
        ($field eq 'force') and 
            next;

        is $row->valueByName($field),
            $value,
             "testing if $field has the updated value";
    }

    is $dataTable->_storedVersion, ($version + 1),
        'checking that stored version has been incremented';
    is $dataTable->size(), $oldSize,
        'checking that table size has not changed after the setRow';

    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();
}


# XXX tODO add notification method parameters test
sub setTest : Test(10)
{
    my ($self) = @_;
    my $dataTable = $self->_newPopulatedDataTable();
    my @ids = map {
        $_->id()
    } @{ $dataTable->rows() };
    my $id = shift @ids;

    my $notifyMethodName = 'updatedRowNotify';
    $dataTable->set_true($notifyMethodName);



    my %changeParams = (
                        regularField => 'distinctData',
                        uniqueField => 'newUniqueValue',
                        defaultField => 'aaa',
                       );
    $self->_checkSet(
                     $dataTable,
                     $id,
                     \%changeParams,
                     'Setting row',
                    );



    my $version = $dataTable->_storedVersion();
    lives_ok {
        $dataTable->set (
                         $id,
                         %changeParams,
                        );

    } 'Setting row with the same values';
    is $version, $dataTable->_storedVersion(), 
        'checking that stored table version has not changed';
    ok (
        (not $dataTable->called($notifyMethodName)),
        'checking that on setting row with no changes notify method was not called',
       );
}


sub setWithDataInUseTest : Test(18)
{
    my ($self) = @_;
    my $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();
    my @ids = map {
        $_->id()
    } @{ $dataTable->rows() };
    my $id = shift @ids;

    my $notifyMethodName = 'updatedRowNotify';
    $dataTable->set_true($notifyMethodName);

    setRowIdInUse($id);

    my %changeParams = (
                        regularField => 'distinctData',
                        uniqueField => 'newUniqueValue',
                        defaultField => 'aaa',
                       );  

    $self->_checkDeviantSet ( 
                      $dataTable,
                      $id,
                      \%changeParams,
      'Checking that setting a row with data on use raises error'
                     );

    $changeParams{force} = 1;
    $self->_checkSet ( 
                      $dataTable,
                      $id,
                      \%changeParams,
      'Checking that setting a row with data on use and force =1 works'
                     );

    delete $changeParams{force};
    setRowIdInUse(undef);
    $changeParams{defaultField} = 'anotherValue';
    $self->_checkSet ( 
                      $dataTable,
                      $id,
                      \%changeParams,
      'Checking that setting a row with no data on use and force =0 works in a automaticRemoveTable'
                     );
}

sub _checkValidateTypedRowCall
{
    my %params = @_;
    my $expectedAction = $params{expectedAction};
    my %expectedChangedFields = %{ $params{expectedChanged}  } ;
    my %expectedAllFields     = %{ $params{expectedAll}  } ;

    my ($dataTable, $action, $changedFields_r, $allFields_r) = @{ $params{callParams} };
    my %changedFields = %{ $changedFields_r };
    my %allFields = %{ $allFields_r };
    foreach  (values %changedFields) {
        $_ = $_->value();
    }
    foreach  (values %allFields) {
        $_ = $_->value();
    }



    is $action, $expectedAction, "checking action parameter in validateTypedRow";
    
        is_deeply \%changedFields, \%expectedChangedFields,
        'checking changedFields names in validateTypeRow';
    is_deeply \%allFields , \%expectedAllFields, 
        'checkinf allFields names in validateTypeRow';


}


sub _checkAddeRowNotifyCall
{
    my %params = @_;

    my ($dataTable, $row) = @{ $params{callParams} };

    _checkRow(
              row => $row,
              expectedFields => $params{expectedFields},
              testName =>  'checking row contents in addedRowNotify',
             );
}


sub _checkRow
{
    my %params = @_;
    my $row    = $params{row};
    my %expectedFields =  %{  $params{expectedFields} };
    my $testName = $params{testName};
    $testName or
        $testName = 'checking row';

    my %valueHash = %{  $row->hashElements };
    foreach (values %valueHash) {
        $_ = $_->value();
    }

    is_deeply \%valueHash, \%expectedFields, $testName ;
}

sub optionsFromForeignModelTest : Test(2)
{
    my ($self) = @_;
    my $tableDescription = {
                  tableDescription => [
                                       new EBox::Types::Text(
                                                    fieldName => 'field1',
                                                    printableName => 'field1',
                                                    unique        => 1,
                                                                ),
                                       new EBox::Types::Text(
                                                    fieldName => 'field2',
                                                    printableName => 'field2',
                                                                ),
                                                                   
                                      ],
                            tableName => 'test',

                           };

    my $dataTable = $self->_newDataTable($tableDescription);

    my @field1Values= qw(a b c);
    foreach my $value (@field1Values) {
        $dataTable->add(field1 => $value, field2 => 'irrelevant');
    }
        

    dies_ok {
        $dataTable->optionsFromForeignModel('inexistentField');
    }'expecting error when using a inexistent field for optionsFromForeignModel';
    

    my $field = 'field1';

   my @expectedOptions =  map {
                                   {
                              value => $_->id(),
                              printableValue => $_->printableValueByName($field),
                                   }
                               } @{ $dataTable->rows() };
    



     my $options=  $dataTable->optionsFromForeignModel($field);


     is_deeply  $options, \@expectedOptions, 
        'checking optionsFromForeignModel for a existent field';

}


sub findTest : Test(6)
{
    my ($self) = @_;

    my $dataTable = $self->_newPopulatedDataTable();

    my $fieldName = 'uniqueField';
    my $fieldValue = 'b';

    my $row;

    dies_ok {
        $dataTable->find('inexistentField' => 'b');
    } 'checking that find() with a inexistent field fails' ;


    $row = $dataTable->find($fieldName => 'inexistent');
    ok ((not defined $row), 'checking that find() with a inexistent value returns undef' );
    
    $row = $dataTable->find($fieldName => $fieldValue);
    isa_ok ($row, 
            'EBox::Model::Row',
            'checking that find with row name and value returns  a row'
           );
    
    
    my $rowfound =  $dataTable->findRow($fieldName => $fieldValue);
    is $row->id(), $rowfound->id(),
        'checking return value of findRow method';

    my $idfound = $dataTable->findId($fieldName => $fieldValue);
    is $idfound, $row->id(),
        'checking return value of findId metthod';

    my $valueFound = $dataTable->findValue($fieldName => $fieldValue);
        is $valueFound->id(), $row->id(),
        'checking return value of findValue method';



}


sub filterTest : Test(5)
{
    my ($self) = @_;

    my $dataTable = $self->_newPopulatedDataTable();
    $dataTable->add(
                    'uniqueField' => 'x',
                    'regularField' => 'onceRepeated twiceRepeated',

                   );
    $dataTable->add(
                    'uniqueField' => 'z',
                    'regularField' => 'twiceRepeated',

                   );

    my %filterAndRowsExpected = (
                                 'twiceRepeated' => 2,
                                 'onceRepeated' => 1,
                                 'twiceRepeated onceRepeated' => 1,
                                 'onceRepeated zeroRepeated' => 0, 
                                 'zeroRepeated' => 0,
                                );

    while (my ($filter, $rowsExpected) = each %filterAndRowsExpected) {
        $dataTable->setFilter($filter);
        my $nRows = scalar @{ $dataTable->rows($filter) };
        is $nRows, $rowsExpected, "Checking number of rows returned with filter: $filter";
    }
}



sub pageTest : Test(38)
{
    my ($self) = @_;

    my $rows = 20;
    my $dataTable = $self->_newDataTable($self->_tableDescription4fields());
    foreach (1 .. $rows) {
        $dataTable->add(
                        uniqueField => $_,
                        regularField => "regular for $_",
                       );
    }

    my @pagesSizes = (1, 5, 7, 11);
    foreach my $size (@pagesSizes) {
        my %rowsSeen = ();

        lives_ok {
            $dataTable->setPageSize($size)
        } "Setting page size to $size";

        my $pageCount = POSIX::ceil($rows / $size);
        my $lastPage     = $pageCount - 1;
        my $lastPageRows = $rows - ( ($pageCount -1) * $size );
        foreach my $page (0 .. $lastPage) {
            my $expectedRows = ($page != $lastPage) ?
                                                 $size        :
                                                 $lastPageRows;
                                          

            my @rows  =  @{ $dataTable->rows(undef, $page) };
            foreach my $row (@rows) {
                my $id = $row->id();
                if (exists $rowsSeen{$id}) {
                    fail 
            "Row with id $id was previously returned i nanother page";
                    next;

                }

                $rowsSeen{$id} = 1;
            }

            is scalar @rows, $expectedRows,
              "Checking expected number of rows ($expectedRows) for page $page with size $size";
                    
        }

    }

    dies_ok {
        $dataTable->rows(undef, -1);
    } 'Check that rows() raises error when requested a negative page';


    $dataTable->setPageSize($rows);
    is_deeply $dataTable->rows(undef, 0),
              $dataTable->rows(undef, 1),
        'Checking that a number greater than available page means last page';

    dies_ok {
        $dataTable->setPageSize(-1);
    } 'Setting page size to a negative number must raise error';
    

    $dataTable->setPageSize($rows + 1);
    is scalar @{ $dataTable->rows(undef, 1)  }, $rows,
'Checking that a apge size greater than the number of rows returns all the rows';

    $dataTable->setPageSize(0);
    is scalar @{ $dataTable->rows(undef, 1)  }, $rows,
        'Checking that pageZise ==0 means unlimited page size';


}

sub _newDataTable
{
    my ($self, $table) = @_;
    if (not defined $table) {
        $table = {
                  tableDescription => [
                                       new EBox::Types::Abstract(
                                                    fieldName => 'field1',
                                                    printableName => 'field1',
                                                                ),
                                                                   
                                      ],
                  tableName => 'test',
                 };

    }

    my $gconfmodule = EBox::Global->modInstance('fakeModule');

    my $dataTableDir = '/ebox/modules/fakeModule/DataTable';
    # remove old data from prvious modules
    $gconfmodule->delete_dir($dataTableDir);


    my $dataTableBase = EBox::Model::DataTable->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => $dataTableDir,
                                                 domain      => 'domain',
                                                );


    my $dataTable = Test::MockObject::Extends->new($dataTableBase);
    $dataTable->set_always('_table' => $table);


    return $dataTable;
}


sub _newPopulatedDataTable
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();


    my $dataTable = $self->_newDataTable($tableDescription);

    my @values = (

                       [ uniqueField => 'a', regularField => 'regular' ],
                       [ 
                        uniqueField => 'b', regularField => 'regular', 
                        defaultField => 'noDefaultText' 
                       ],
                       [ 
                        uniqueField => 'c', regularField => 'regular', 
                        optionalField => 'noDefaultText' 
                       ],
                      );

    foreach (@values) {
        $dataTable->add( @{ $_  } );
    }


    return $dataTable;
}


sub _newPopulatedDataTableWithAutomaticRemove
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();
    $tableDescription->{automaticRemove} = 1;
    my $dataTable = $self->_newDataTable($tableDescription);   
 
    my @values = (

                       [ uniqueField => 'a', regularField => 'regular' ],
                       [ 
                        uniqueField => 'b', regularField => 'regular', 
                        defaultField => 'noDefaultText' 
                       ],
                       [ 
                        uniqueField => 'c', regularField => 'regular', 
                        optionalField => 'noDefaultText' 
                       ],
                      );  

    foreach (@values) {
        $dataTable->add( @{  $_  }  );
    } 

    return $dataTable;
}

sub _tableDescription4fields
{
      my $tableDescription = {
                  tableDescription => [
                                       new EBox::Types::Text(
                                                   fieldName => 'uniqueField',
                                                   printableName => 'uniqueField',
                                                   unique        => 1,
                                                                ),
                                       new EBox::Types::Text(
                                                  fieldName => 'regularField',
                                                 printableName => 'regularField',
                                                                ),
                                       new EBox::Types::Text(
                                                fieldName => 'defaultField',
                                                printableName => 'defaultField',
                                                defaultValue    => 'defaultText',
                                                                ),
                                       
                                       new EBox::Types::Text(
                                                fieldName => 'optionalField',
                                                printableName => 'optionalField',
                                                optional      => 1,
                                                                ),
                                                                   
                                      ],
                            tableName => 'test',

                           };

      return $tableDescription;
}


1;
