# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Model::DataTable::Test;

use base 'EBox::Test::Class';

use Test::More;;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;
use Test::MockModule;
use Test::File;
use Perl6::Junction qw(any);
use POSIX;

use  EBox::Model::Manager::Fake;

use EBox::Model::Row;
use EBox::Model::DataTable;
use EBox::Model::Manager;
use EBox::Types::Abstract;
use EBox::Types::HasMany;
use EBox::Types::Text;

sub mockManager  : Test(startup)
{
    my ($self) = @_;
    EBox::Model::Manager::Fake->overrideOriginal();
}

sub setModules : Test(setup)
{
    EBox::TestStubs::fakeModule(name => 'fakeModule');
}

sub clearGConf : Test(teardown)
{
    EBox::TestStubs::setConfig();
}

sub deviantTableTest : Test(5)
{
    my ($self) = @_;

    my @cases;
    push @cases, [ 'empty table description' => {
                        tableName => 'test',
                   }
    ];
    push @cases, [ 'empty tableDescription' => {
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

        dies_ok {
            my $dataTable = $self->_newDataTable($table);
            $dataTable->table();
        } "expecting error with deviant table case: $caseName";
    }
}

sub tableTest  : Test(6)
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

        ok exists $tableFromModel->{tableDescriptionByName}, 'checking that some fields were inserted by first time setup';
    }
}

sub contextNameTest  : Test(1)
{
    my ($self) = @_;
    my $dataTable = $self->_newDataTable();

    my $expectedContenxtName = '/fakeModule/test/';
    is $dataTable->contextName, $expectedContenxtName, 'checking contextName';
}

sub deviantAddTest : Test(5)
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();

    my $dataTable = $self->_newDataTable($tableDescription);

    # add one row
    lives_ok {
        $dataTable->addRow(uniqueField => 'valueForUnique', regularField => 'regular');
    } 'Adding first row';

    my %invalidAdds = (
            'unique field repeated' => [
                uniqueField => 'valueForUnique',
                regularField =>'adaads',
            ],
            'missing required field' => [
                uniqueField => 'anotherValueForUnique',
            ],
    );

    my $dataTableSize = $dataTable->size();
    while (my ($testName, $addParams_r) = each %invalidAdds) {
        dies_ok {
            $dataTable->addRow(@{ $addParams_r });
        } "expecting error with incorrect row addition: $testName";

        is $dataTable->size(), $dataTableSize, 'checking wether no new rows were added using size method';
    }
}

sub addRowTest  : Test(25)
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
                # default field is always added with its default value
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
            # default field is always added with its default value
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

sub moveRowsTest : Test(21)
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();
    $tableDescription->{order}   = 1;
    $tableDescription->{insertPosition} = 'back';

    my $dataTable = $self->_newDataTable($tableDescription);
    my @cases = (
        {
            desc => 'Move first to normal position',
            args => ['a', 'c', 'd'],
            expected => {
                    'a' => 2,
                    'b' => 0,
                    'c' => 1,
                    'd' => 3,
                    'e' => 4,
               }
        },
        {
            desc => 'Move first to last position',
            args => ['a', 'e', undef],
            expected => {
                    'a' => 4,
                    'b' => 0,
                    'c' => 1,
                    'd' => 2,
                    'e' => 3,
               }
        },
        {
            desc => 'Move normal to first',
            args => ['d', undef, 'a'],
            expected => {
                    'a' => 1,
                    'b' => 2,
                    'c' => 3,
                    'd' => 0,
                    'e' => 4,
               }
        },
        {
            desc => 'Move normal to normal',
            args => ['b', 'd', 'e'],
            expected => {
                    'a' => 0,
                    'b' => 3,
                    'c' => 1,
                    'd' => 2,
                    'e' => 4,
               }
        },
        {
            desc => 'Move normal to end',
            args => ['d', 'e', undef],
            expected => {
                    'a' => 0,
                    'b' => 1,
                    'c' => 2,
                    'd' => 4,
                    'e' => 3,
               }
        },

        {
            desc => 'Move end to first',
            args => ['e', undef, 'a'],
            expected => {
                    'a' => 1,
                    'b' => 2,
                    'c' => 3,
                    'd' => 4,
                    'e' => 0,
               }
        },
        {
            desc => 'Move end to normal',
            args => ['e', 'b', 'c'],
            expected => {
                    'a' => 0,
                    'b' => 1,
                    'c' => 3,
                    'd' => 4,
                    'e' => 2,
               }
        },

        {
            desc => 'Move normal to same position',
            args => ['c', 'b', 'd'],
            expected => {
                    'a' => 0,
                    'b' => 1,
                    'c' => 2,
                    'd' => 3,
                    'e' => 4,
               }
        },
    );

    foreach my $case (@cases) {
        _moveRowTestTableSetup($dataTable);
        lives_ok {
            $dataTable->moveRowRelative(@{ $case->{args}  });
        } 'Moving row case: ' . $case->{desc};

        my %newOrder = $dataTable->_orderHash();
        is_deeply \%newOrder, $case->{expected},
              'checking that the order after the move is correct';
    }

    my @invalidArgumens = (
        ['b', 'b', 'c'],
        ['a', undef, 'a'],
        ['c', 'd', 'd'],
       );
    foreach my $args (@invalidArgumens) {
        my @args = @{ $args };
        throws_ok {
            $dataTable->moveRowRelative(@args);
        } 'EBox::Exceptions::MissingArgument', "Checking call to moveRowRelative with invalid arguments @args";
    }
}


sub _moveRowTestTableSetup
{
    my ($dataTable) = @_;
    $dataTable->removeAll(1);
    foreach my $id ('a', 'b', 'c', 'd', 'e') {
        my @fields = (id => $id, uniqueField => "unique $id", regularField => "regular $id");

        $dataTable->addRow(@fields);
    }
    return $dataTable;
}

sub removeAllTest : Test(3)
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
}

sub removeAllRowsWithAutomaticRemove : Test(5)
{
    my ($self) = @_;
    my $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();
    my $rowId =  $dataTable->ids()->[0];

    EBox::Model::Manager::Fake::setModelsUsingId(
        $dataTable->contextName() => {
              $rowId => ['fakeTableUsingId']
           }
       );

    throws_ok {
        $dataTable->removeAll(0)
    } 'EBox::Exceptions::DataInUse', 'Checking  removeAll without force with autoremove and used files';

    lives_ok {
        $dataTable->removeAll(1)
    } 'Checking  removeAll with force with autoremove and used files';
    is $dataTable->size, 0, 'checking that after removing all rowswith force=1  the table is empty';

    # automatic remove with no row used case
    EBox::Model::Manager::Fake::setModelsUsingId();
    $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();

    lives_ok {
        $dataTable->removeAll(0)
    } 'Checking  removeAll withoy force with autoremove option but no used rows';
    is $dataTable->size, 0, 'checking that after removing all rows with force-0 but not used rows  the table is empty';
}

sub removeRowTest : Test(5)
{
    my ($self) = @_;

    my $notifyMethodName = 'deletedRowNotify';

    my $dataTable = $self->_newPopulatedDataTable();

    $dataTable->can($notifyMethodName) or
        die "bad notify method name $notifyMethodName";
    $dataTable->set_true($notifyMethodName);

    my @ids = @{ $dataTable->ids() };

    dies_ok {
        $dataTable->removeRow('inexistent');
    } 'expecting error when trying to remove a inexistent row';

    ok ((not $dataTable->called($notifyMethodName)), 'checking that on error notify method was not called');

    my $id = shift @ids;
    lives_ok {
        $dataTable->removeRow($id);
    } 'removing row';
    is $dataTable->row($id), undef,
       'checking that row is not longer in the table';
    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();
}

sub removeRowWithAutomaticRemoveTest : Test(8)
{
    my ($self) = @_;
    # tests with automatic remove
    my $notifyMethodName = 'deletedRowNotify';

    my $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();
    $dataTable->set_true($notifyMethodName);

    my @ids =  @{ $dataTable->ids() };
    my $id = shift @ids;

    EBox::Model::Manager::Fake::setModelsUsingId(
        $dataTable->contextName() => {
              $id => ['fakeTableUsingId']
           }
       );

    throws_ok {
        $dataTable->removeRow($id, 0)
    } 'EBox::Exceptions::DataInUse',
              'removeRow in a row reported as usedin a automaticRemove table  raises DataInUse execption';
    ok ((not $dataTable->called($notifyMethodName)), 'checking that on DataInUse excpeion notify method was not called');

    lives_ok {
        $dataTable->removeRow($id, 1)
    } 'removeRow with force in a used row within a automaticRemove table works';

    is $dataTable->row($id), undef, 'checking that row is not longer in the table';
    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();

    my $unusedId = shift @ids;
    lives_ok {
        $dataTable->removeRow($unusedId, 0)
    } 'removeRow with force in a unused row within a automaticRemove table works';

    is $dataTable->row($unusedId), undef, 'checking that row is not longer in the table';
    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();
}

sub deviantSetRowTest : Test(9)
{
    my ($self) = @_;
    my $dataTable = $self->_newPopulatedDataTable();
    my @ids = @{ $dataTable->ids() };
    my $id = shift @ids;

    my $notifyMethodName = 'updatedRowNotify';

    my $repeatedUnique = $dataTable->row($ids[0])->valueByName('uniqueField');
    $self->_checkDeviantSetRow(
        $dataTable,
        $id,
        {
            uniqueField => $repeatedUnique,
            regularField => 'distinctData',
            defaultField => 'aa',
        },
        'Checking that setting repeated unique field raises error'
    );

  SKIP: {
        skip 'new implementation does not raises error when settign a inexistent field', 3;
        $self->_checkDeviantSetRow(
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
    }

    $dataTable->mock('validateTypedRow' => sub { die 'always fail' });
    $self->_checkDeviantSetRow(
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



sub _checkDeviantSetRow
{
    my ($self, $dataTable, $id, $params_r, $testName) = @_;
    my $notifyMethodName = 'updatedRowNotify';

    my $oldRow =   $dataTable->row($id);
    my $oldHashElements = $oldRow->hashElements();

    $params_r->{id} = $id;

    dies_ok {
        $dataTable->setRow(
                0,
                %{ $params_r }
        );
    } $testName;

    my $newRow = $dataTable->row($id);
    is_deeply($newRow, $oldRow,
              'checking that erroneous operation has not changed the row values');
    ok (
        (not $dataTable->called($notifyMethodName)),
        'checking that on error notify method was not called',
    );
}

sub _checkSetRow
{
    my ($self, $dataTable, $id, $changeParams_r, $testName) = @_;
    my $notifyMethodName = 'updatedRowNotify';
    my %changeParams = %{ $changeParams_r };
    $changeParams{id} = $id;
    my $force = delete $changeParams{force};

    my $oldSize = $dataTable->size();
    lives_ok {
        $dataTable->setRow($force, %changeParams);
    } $testName;

    my $row = $dataTable->row($id);
    while (my ($field, $value) = each %changeParams) {
        ($field eq 'id') and
            next;

        is $row->valueByName($field),
           $value,
           "testing if $field has the updated value";
    }

    is $dataTable->size(), $oldSize,
       'checking that table size has not changed after the setRow';

    $dataTable->called_ok($notifyMethodName);
    $dataTable->clear();
}

# XXX TODO add notification method parameters test
sub setRowTest : Test(8)
{
    my ($self) = @_;
    my $dataTable = $self->_newPopulatedDataTable();
    my @ids =  @{ $dataTable->ids() };
    my $id = shift @ids;

    my $notifyMethodName = 'updatedRowNotify';
    $dataTable->set_true($notifyMethodName);

    my %changeParams = (
            regularField => 'distinctData',
            uniqueField => 'newUniqueValue',
            defaultField => 'aaa',
    );
    $self->_checkSetRow(
            $dataTable,
            $id,
            \%changeParams,
            'Setting row',
    );

    lives_ok {
        $changeParams{id} = $id;
        $dataTable->setRow(0, %changeParams);
    } 'Setting row with the same values';

    ok (($dataTable->called($notifyMethodName)), 'checking that on setting row with no changes also calls notify method');
}

sub setWithDataInUseTest : Test(15)
{
    my ($self) = @_;

    my $dataTable = $self->_newPopulatedDataTableWithAutomaticRemove();
    my @ids = @{ $dataTable->ids() };
    my $id = shift @ids;

    $dataTable->set_true('updatedRowNotify');

    # Real Model::Manager expects this kind of weird context name
    my $contextName = $dataTable->contextName();
    $contextName =~ s{^/}{};
    $contextName =~ s{/$}{};
    EBox::Model::Manager::Fake::setModelsUsingId(
        $contextName => { $id => ['fakeTableUsingId'] }
    );

    my %changeParams = (
            regularField => 'distinctData',
            uniqueField => 'newUniqueValue',
            defaultField => 'aaa',
    );

    $self->_checkDeviantSetRow (
            $dataTable,
            $id,
            \%changeParams,
            'Checking that try to set a row with data in use raises error'
    );

    $changeParams{force} = 1;
    $self->_checkSetRow (
            $dataTable,
            $id,
            \%changeParams,
            'Checking that setting a row with data in use and force = 1 works'
    );

    delete $changeParams{force};
    EBox::Model::Manager::Fake::setModelsUsingId();
    $changeParams{defaultField} = 'anotherValue';
    $self->_checkSetRow (
            $dataTable,
            $id,
            \%changeParams,
            'Checking that setting a row with no data in use and force = 0 works in a automaticRemoveTable'
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

    my %valueHash = %{ $row->hashElements };
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
        my $id = $_;
        my $row = $dataTable->row($id);
        {
            value => $id,
            printableValue => $row->printableValueByName($field),
        }
    } @{ $dataTable->ids() };

    my $options=  $dataTable->optionsFromForeignModel($field);

    is_deeply  $options, \@expectedOptions,
               'checking optionsFromForeignModel for a existent field';
}

sub findTest : Test(10)
{
    my ($self) = @_;

    my $dataTable = $self->_newPopulatedDataTable();

    my $fieldName = 'uniqueField';
    my $fieldValue = 'populatedRow2';
    my $field2Name = 'regularField';
    my $field2Value = 'regular';
    my $fieldValue2 = 'populatedRow1';

    my $row;

    dies_ok {
        $dataTable->find('inexistentField' => 'b');
    } 'checking that find() with a inexistent field fails' ;

    throws_ok {
        $dataTable->findValueMultipleFields({});
    } 'EBox::Exceptions::InvalidData', 'thrown exception when no fields is searched on multiple';

    throws_ok {
        $dataTable->findValue();
    } 'EBox::Exceptions::MissingArgument', 'thrown exception when no fields is searched on single';

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
       'checking return value of findId method';

    my $valueFound = $dataTable->findValue($fieldName => $fieldValue);
    is $valueFound->id(), $row->id(),
       'checking return value of findValue method';

    $valueFound = $dataTable->findValueMultipleFields({$fieldName => $fieldValue,
                                                       $field2Name => $field2Value});
    is $valueFound->id(), $row->id(),
       'checking return value of findValueMultipleFields method';

    my $anotherRow = $dataTable->findValueMultipleFields({$fieldName => $fieldValue2,
                                                          $field2Name => $field2Value});
    isnt $anotherRow->id(), $row->id(),
       'checking return value of findMultipleFields is another row';
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

    my $confmodule = EBox::Global->modInstance('fakeModule');

    my $dataTableDir = '/conf/fakeModule/DataTable';
    # remove old data from previous runs
    $confmodule->delete_dir($dataTableDir);

    my $dataTableBase = EBox::Model::DataTable->new(
            confmodule => $confmodule,
            directory   => $dataTableDir,
            domain      => 'domain',
            );

    my $dataTable = Test::MockObject::Extends->new($dataTableBase);
    $dataTable->set_always('_table' => $table);

    $dataTable->removeAll(); # to clean remains of faked config

    return $dataTable;
}

sub _newPopulatedDataTable
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();

    my $dataTable = $self->_newDataTable($tableDescription);
    $self->_populateDataTable($dataTable);

    return $dataTable;
}

sub _newPopulatedDataTableWithAutomaticRemove
{
    my ($self) = @_;

    my $tableDescription = _tableDescription4fields();
   $tableDescription->{automaticRemove} = 1;
    my $dataTable = $self->_newDataTable($tableDescription);
    $self->_populateDataTable($dataTable);

    return $dataTable;
}

sub _populateDataTable
{
    my ($self, $dataTable) = @_;
    my @values = (
            [ uniqueField => 'populatedRow1', regularField => 'regular' ],
            [
                uniqueField => 'populatedRow2', regularField => 'regular',
                defaultField => 'noDefaultText'
            ],
            [
                uniqueField => 'populatedRow3', regularField => 'regular',
                optionalField => 'noDefaultText'
            ],
            [
                uniqueField => 'populatedRow4', regularField => 'regular',
                optionalField => 'undef'
            ],
    );

    foreach (@values) {
        $dataTable->addRow( @{ $_  } );
    }
}

sub _tableDescription4fields
{
    my $tableDescription = {
        tableDescription => [
            new EBox::Types::Text(
                    fieldName => 'uniqueField',
                    printableName => 'uniqueField',
                    unique => 1,
            ),
            new EBox::Types::Text(
                    fieldName => 'regularField',
                    printableName => 'regularField',
            ),
            new EBox::Types::Text(
                    fieldName => 'defaultField',
                    printableName => 'defaultField',
                    defaultValue  => 'defaultText',
            ),
            new EBox::Types::Text(
                    fieldName => 'optionalField',
                    printableName => 'optionalField',
                    optional => 1,
            ),
        ],
        tableName => 'test',
    };

    return $tableDescription;
}

1;
