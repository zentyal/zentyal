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

package EBox::Model::DataForm::Test;

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
use EBox::Model::DataForm;
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



sub deviantFormTest : Test(7)
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
                  'form with order' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'field1',
                                                                          ),
                                                                   
                                                                   ],
                                                order => 1,

                                              }
                  
                 ];

   push @cases, [
                  'form with sortedBy' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'field1',
                                                                          ),
                                                                   
                                                                   ],

                                                   sortedBy => 'field1',
                                              }
                  
                 ];


    
    foreach my $case_r (@cases) {
        my ($caseName, $table) = @{ $case_r };
        my $dataForm = $self->_newDataForm($table);

        dies_ok {
            $dataForm->table();
        } "expecting error with deviant form case: $caseName";
    }


}

sub formTest : Test(2)
{
    my ($self) = @_;

    my @cases;
    push @cases,  [  'simple form' => {
                                               tableDescription => [
                                                 new EBox::Types::Abstract(
                                                       fieldName => 'field1',
                                                                          ),
                                                                   
                                                                   ],
                                                   tableName => 'test',
                         }

                  ];


    foreach my $case_r (@cases) {
        my ($caseName, $table) = @{ $case_r };
        my $dataForm = $self->_newDataForm($table);

        my $tableFromForm;
        lives_ok {
            $tableFromForm = $dataForm->table();
        } "checking first call to form method with: $caseName";

        ok exists $tableFromForm->{tableDescriptionByName}, 'checking that some fileds were inserted by first time setup';
    }

}


sub _newDataForm
{
    my ($self, $table) = @_;
    if (not defined $table) {
        $table = $self->_tableDescription4fields();

    }

    my $gconfmodule = EBox::Global->modInstance('fakeModule');

    my $dataFormDir = '/ebox/modules/fakeModule/DataForm';
    # remove old data from previous modules
    $gconfmodule->delete_dir($dataFormDir);


    my $dataFormBase = EBox::Model::DataForm->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => $dataFormDir,
                                                 domain      => 'domain',
                                                );


    my $dataForm = Test::MockObject::Extends->new($dataFormBase);
    $dataForm->set_always('_table' => $table);


    return $dataForm;
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
