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
                  'empty field name' => {
                                               tableDescription => [
                                                     new EBox::Types::Abstract()               
                                                                    
                                                                   ],
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

    push @cases, [
                  'sortedBy uses unexistent field' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'field1',
                                                                          ),
                                                                   
                                                                   ],

                                                tableName => 'test',
                                                sortedBy => 'unexistentField',
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

sub tableTest : Test(4)
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
sub moveRowsTest : Test(2)
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();
    $tableDescription->{orderBy} = 'uniqueField';

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
    my @reverseOrder = reverse @order;
   
    $dataTable->moveUp($order[0]);
    is_deeply $dataTable->order, \@order, 
        'checking that moving up the upper filed has not changed the order';
    ok ((not $dataTable->called('movedUpRowNotify')), 
        'Checking that movedUpRowNotify has not triggered');

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


sub removeRowTest : Test(8)
{
    my ($self) = @_;

    my $dataTable;
    my $id;

    $dataTable = $self->_newPopulatedDataTable();
    my @ids = map {
        $_->id()
    } @{ $dataTable->rows() };


    dies_ok {
        $dataTable->removeRow('inexistent');
    } 'expecting error when trying to remove a inexistent row';


    $id = shift @ids;
    lives_ok {
        $dataTable->removeRow($id);
    } 'removing row';
    is $dataTable->row($id), undef,
        'checking that row is not longer in the table';


    # tests with automatic remove

    $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();


    @ids = map {
        $_->id()
    } @{ $dataTable->rows() };
    $id = shift @ids;

    setRowIdInUse($id);
    


    throws_ok {
        $dataTable->removeRow($id, 0)
    } 'EBox::Exceptions::DataInUse',
      'removeRow in a row reported as usedin a automaticRemove table  raises DataInUse execption';

    lives_ok {
        $dataTable->removeRow($id, 1)
    } 'removeRow with force in a used row within a automaticRemove table works';
    is $dataTable->row($id), undef,
        'checking that row is not longer in the table';
    
    $id = shift @ids;
    lives_ok {
        $dataTable->removeRow($id, 0)
    } 'removeRow with force in a unused row within a automaticRemove table works';
    is $dataTable->row($id), undef,
        'checking that row is not longer in the table';
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

sub optionsFromForeignModelTest : Test(1)
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
    
    
#    my @options;
#     @options = $dataTable->optionsFromForeignModel('field1');

#     my @expectedOptions = map {
#         {  value => $_, printableValues}
#     } @field1Values;
    
#     is_deeply  \@options, \@expectedOptions, 'checking ';

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

    my $dataTableDir = 'DataTable';
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
