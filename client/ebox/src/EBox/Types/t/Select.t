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


use strict;
use warnings;

use Test::More tests => 20;
use Test::MockObject;
use Test::Exception;

use Error qw(:try);

use EBox::TestStubs;


use lib '../../..';

use EBox::Types::Test;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Model::DataTable;





sub creationTest
{
    my $class = 'EBox::Types::Select';

    EBox::Types::Test::createOk(
                                $class,
                                noSetCheck => 1,

                                fieldName => 'select',
                                editable  => 1,
                                populate => sub { return []  },

                                'select with populate option creation ok'
                               );

    EBox::Types::Test::createOk(
                                $class,
                                noSetCheck => 1,

                                fieldName => 'select',
                                editable  => 1,
                                foreignModel => \&_foreignModel,
                                foreignField => 'name',

                                'select with foreignModel and foreignField options creation ok'
                               );

    EBox::Types::Test::createFail(
                                  $class,
                                  noSetCheck => 1,

                                  fieldName => 'select',
                                  populate => sub { return []  },

                                  'select without editable option fails construction'
                                 );


    EBox::Types::Test::createFail(
                                  $class,
                                  noSetCheck => 1,

                                  fieldName => 'select',
                                  populate => sub { return []  },
                                  editable => 1,
                                  optional => 1,

                                  'select with optional option fails construction'
                                 );


    EBox::Types::Test::createFail(
                                  $class,
                                  noSetCheck => 1,

                                  fieldName => 'select',
                                  editable => 1,
                                  optional => 1,

                                  'select without either populate or foreignModel fails construction'
                                 );

    EBox::Types::Test::createFail(
                                  $class,
                                  noSetCheck => 1,

                                  fieldName => 'select',
                                  editable => 1,
                                  optional => 1,
                                  foreignModel => \&_foreignModel,

                                  'select with foreignModel but lacking foreignField fails construction'
                                 );


    EBox::Types::Test::createFail(
                                  $class,
                                  noSetCheck => 1,

                                  fieldName => 'select',
                                  editable => 1,
                                  optional => 1,
                                  foreignField => 'name', 

                                  'select with foreignField but lacking foreignModel fails construction'
                                 );
}



my $_foreignModel;
sub _foreignModel
{
    my ($self) = @_;

    if (not defined $_foreignModel) {
        $_foreignModel =  __PACKAGE__->_newPopulatedDataTable();
    }

    return $_foreignModel;
}


sub _newDataTable
{
    my ($self, $table) = @_;
    if (not defined $table) {
        die 'no table';
    }

    EBox::TestStubs::fakeEBoxModule(name => 'fakeModule');
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

                       [ name => 'a', regularField => 'regular' ],
                       [ 
                        name => 'b', regularField => 'regular', 
                        defaultField => 'noDefaultText' 
                       ],
                       [ 
                        name => 'c', regularField => 'regular', 
                        optionalField => 'noDefaultText' 
                       ],
                      );

    foreach (@values) {
        $dataTable->add( @{ $_  } );
    }


    return $dataTable;
}




sub _tableDescription4fields
{
      my $tableDescription = {
                  tableDescription => [
                                       new EBox::Types::Text(
                                                   fieldName => 'name',
                                                   printableName => 'name',
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


sub optionsFromPopulateTest
{
    my $populateOptions = [
                           { value => 'a' , printableValue => 'a' },
                           { value => 'ea' , printableValue => 'ea' },
                           { value => 'cas' , printableValue => 'cas' },
                          ];

    my $select =  new EBox::Types::Select(
                                          fieldName => 'select',
                                          editable  => 1,
                                          populate => sub { 
                                              return $populateOptions  
                                          },
                                         );

    is_deeply $select->options(), $populateOptions,
        'checking options returned from a select with populate attribute';
}

sub optionsFromForeignModelTest
{
    my $select = new EBox::Types::Select(
                                         fieldName => 'select',
                                         editable  => 1,
                                         foreignModel => \&_foreignModel,
                                         foreignField => 'name',
                                        );

    my @expected = map {
                          my $id = $_->id();
                          my $name = $_->valueByName('name');
                    {value => $id, printableValue => $name },
                   } @{ _foreignModel->rows() };

    my @actual = @{ $select->options() };


    is_deeply \@actual, \@expected,
        'checking options returned from a select with foreign model';
}


sub setValueTest
{

    my $validParam = 'ea';
    my $invalidParam = 'inexistent';
    my $populateOptions = [
                           { value => 'a' , printableValue => 'a' },
                           { value => $validParam , printableValue => 'ea' },
                           { value => 'cas' , printableValue => 'cas' },
                          ];

    my $select =  new EBox::Types::Select(
                                          fieldName => 'select',
                                          editable  => 1,
                                          populate => sub { 
                                              return $populateOptions  
                                          },
                                         );

    lives_ok {
        $select->setValue($validParam);
    } 'setting valid parameter';
    is $select->value(), $validParam,
        'wether the value has changed';
    dies_ok {
        $select->setValue($invalidParam);
    } 'expecting error when setting value not found in options';
    isnt $select->value, $invalidParam,
        'wethr invalid value has not been stored';
}


sub defaultValueTest
{
    my $defaultValue = 'default';
    my $populateSub =  sub {
        return [
                {  value => 'default', printableValue => 'default' },
                { value  => 'e', printableValue => 'e',},
               ]
    };

    EBox::Types::Test::defaultValueOk(
                                      'EBox::Types::Select',
                                      $defaultValue,
                                      extraNewParams => [
                                                         editable => 1,
                                                         populate => $populateSub
                                                        ]
                                     );
    
}

sub storeAndRestoreGConfTest
{

    EBox::TestStubs::fakeEBoxModule(name => 'store');
    
    my $mod = EBox::Global->modInstance('store');
    my $dir = 'storeAndRestoreTest';

    # to remove remains for other tests
    $mod->delete_dir($dir);


    my $populateOptions = [
                           { value => 'a' , printableValue => 'a' },
                           { value => 'ea' , printableValue => 'ea' },
                           { value => 'cas' , printableValue => 'cas' },
                          ];

    my $select =  new EBox::Types::Select(
                                          fieldName => 'select',
                                          editable  => 1,
                                          populate => sub { 
                                              return $populateOptions  
                                          },
                                         );

    
    my @values = map {
        $_->{value}
    } @{ $populateOptions };
    my $otherValue = pop @values;

    foreach my $value (@values) {
        $select->setValue($value);
 
        lives_ok {
            $select->storeInGConf($mod, $dir);
        } "storing in GConf select with value $value";
        

        try {
            $select->setValue($otherValue);
        }
        otherwise {
            my $ex = shift;
            die "Cannot set value $value: $ex";
        };

        my $hash = $mod->hash_from_dir($dir);
        lives_ok {
            $select->restoreFromHash($hash);
        } 'restoring form hash returned by hash_from_dir';

        is $select->value(), $value,
            'checking that the value was restored';
        
    }
}



EBox::TestStubs::activateTestStubs();
creationTest();
optionsFromPopulateTest();
optionsFromForeignModelTest();
setValueTest();
storeAndRestoreGConfTest();
defaultValueTest();



1;
