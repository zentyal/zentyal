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
use EBox::Types::Abstract;
use EBox::Types::HasMany;


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
        my $dataTable = Test::MockObject::Extends->new($self->_newDataTable);
        $dataTable->set_always('_table' => $table);
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
        my $dataTable = Test::MockObject::Extends->new($self->_newDataTable);
        $dataTable->set_always('_table' => $table);

        my $tableFromModel;
        lives_ok {
            $tableFromModel = $dataTable->table();
        } "checking first call to table method with: $caseName";

        ok exists $tableFromModel->{tableDescriptionByName}, 'checking that some fileds were inserted by first time setup';
    }

}


sub _newDataTable
{
    my $gconfmodule = EBox::Global->modInstance('fakeModule');

    my $dataTableDir = 'DataTable';


    my $dataTable  = EBox::Model::DataTable->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => $dataTableDir,
                                                 domain      => 'domain',
                                                );


    return $dataTable;
}


1;
