package EBox::Model::Row::Test;

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

use lib '../../..';

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



sub deviantElementsTest : Test(8)
{
    my ($self) = @_;

    my $row= $self->_newRow();

    dies_ok {
        $row->addElement(undef);
    } 'Expecting fail when trying to add a undefined element';
    dies_ok {
        my $badElement = new Test::MockObject();
        $row->addElement($badElement);
    } 'Expecting fail when trying to add a non ebox-type element';
    dies_ok {
        my $badElement = new EBox::Types::Abstract();
        $row->addElement($badElement);
    } 'Expecting fail when trying to add a ebox-type element without fieldName';

    $self->_populateRow($row);
    dies_ok {
        my $repeatedElement =  $row->elementByIndex(1);
        $row->addElement($repeatedElement);
    } 'Expecting fail when adding a repeated element';

    my $inexistentIndex = $row->size() + 2;
    dies_ok {
        $row->elementByIndex($inexistentIndex);
    } 'Expecting error when calling elementByIndex with a inexistent index';

    my $inexistentElement = 'inexistent';
    foreach my $accesor (qw(elementByName valueByName printableValueByName)) {
        dies_ok {
            $row->$accesor($inexistentElement);
        } "Expecting error when calling $accesor with inexistent name";
    }
}





sub elementsTest : Test(35)
{
    my ($self) = @_;

    my $row= $self->_newRow();

    my @elementsToAdd;
    foreach my $i(0 .. 5) {
        my $el = new EBox::Types::Abstract(
                                           fieldName => "fieldName$i",
                                           printableName => "printableName$i",
                                          );

        $el->setValue($i);

        push @elementsToAdd, $el;
    }

    lives_ok {
        foreach my $element (@elementsToAdd) {
            $row->addElement($element);
        }

    } 'Adding elements to the row';


    is scalar @elementsToAdd, $row->size(), 
        'checking size of row after addition of elements';

    is_deeply $row->elements(), \@elementsToAdd,
        'checkign contents of the wor using elements() method';
    
    my %expectedHashElements = map {  
        ( $_->fieldName => $_)
    } @elementsToAdd;
    is_deeply $row->hashElements, \%expectedHashElements,
        'checkign contents of the wor using hashElements() method';



    ok (not $row->elementExists('inexistent')), 'checking elementExists on inexistent element';

    foreach my $index (0 .. $#elementsToAdd) {
        my $el    = $elementsToAdd[$index];
        my $name  = $el->fieldName();
        my $value = $el->value();
        my $printableValue = $el->printableValue();

        ok $row->elementExists($name), 
            "checking elementExists on existent element $name";

        is_deeply $row->elementByName($name), $el,
            "checking elementByName in a existent element $name";  
        is_deeply $row->elementByIndex($index), $el,
            "checking elementByIndex in a existent element $name";      

        is $row->valueByName($name), $value, 
            "checking valueByName in a existent element $name";
        is $row->printableValueByName($name), $printableValue,
            "checking printableValueByName in a existent element $name";
    }
    

}



sub parentRowTest : Test(3)
{
    my ($self) = @_;

    my $row= $self->_newRow();
    $self->_populateRow($row);

    is $row->parentRow(), undef,
    'checking that calling parentRow when the model has not parent returns undef';
    my $gconfmodule = EBox::Global->modInstance('fakeModule');

    my $parentDirectory = '/ebox/modules/fakeModule/Parent';
    my $rowWithChildId     = 'ParentRow';
    my $childDirectory  = "$parentDirectory/$rowWithChildId/Child";
    my $rowDirectory    = "$childDirectory/Row";


    my $parentModel =  Test::MockObject::Extends->new(
                               EBox::Model::DataTable->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => $parentDirectory,
                                                 domain      => 'domain',
                                                 )
                                        );

    $parentModel->mock('row', sub {
                           my ($self, $id) = @_;
                           if ($id eq $rowWithChildId) {
                               my $fakeRow = Test::MockObject->new();
                               $fakeRow->set_always('id', $rowWithChildId);
                           }
                           else {
                               die "BAD ID $id";
                           }

                       }

                      );


    my $childModel = EBox::Model::DataTable->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => $parentDirectory,
                                                 domain      => 'domain',
                                                 );
    $row = EBox::Model::Row->new(
                                 gconfmodule => $gconfmodule,
                                 dir         => $rowDirectory
                                );

    $row->setId('FAKE_ID');
    $row->setModel($childModel);
    $childModel->setParent($parentModel);
    
    my $parentRow;
    lives_ok {
        $parentRow = $row->parentRow()
    } 'getting parent row';


    is $parentRow->id(), $rowWithChildId, 'chekcing ID of parent row';
}


sub subModelTest : Test(3)
{
    my ($self) = @_;

    my $row= $self->_newRow();
    $self->_populateRow($row);

    my $gconfmodule = EBox::Global->modInstance('fakeModule');
    my $subModelObject = EBox::Model::DataTable->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => 'Submodel',
                                                 domain      => 'domain',
                                                );

    my $hasManyName = 'mockHasMany';
    my $hasManyObject = Test::MockObject::Extends->new(
                                                      EBox::Types::HasMany->new(
                                                      fieldName => $hasManyName,
                                                      printableName =>
                                                              $hasManyName,
                                                                                 
                                                                                )

                                                      );
    $hasManyObject->set_isa('EBox::Types::Abstract', 'EBox::Types::HasMany');
    $hasManyObject->set_always(foreignModelInstance => $subModelObject);

    $row->addElement($hasManyObject);

    dies_ok {
        $row->subModel('inexistent');
    } 'expecting error when calling subModel with a inexistent element';

    dies_ok {
        my $name = $row->elementByIndex(0)->fieldName();
        $row->subModel($name);
    } 'expecting error when calling subModel with a element that is not a HasMany';

    is_deeply(
              $row->subModel($hasManyName),
              $subModelObject,
              'checking that subModel returns the correct hasMany submodel'
             );
}

sub unionTest : Test(6)
{
    my ($self) = @_;

    my $row= $self->_newRow();
    $self->_populateRow($row);

    my $unionName           = 'fakeUnion';
    my $selectedUnionSubtype = 'selected';
    my $selectedUnionSubtypeObject =   EBox::Types::Abstract->new(
                                         fieldName => $selectedUnionSubtype,
                                         printableName => $selectedUnionSubtype, 
                                                                 );
    my $unselectedUnionSubtype = 'unselected';
    my $unselectedUnionSubtypeObject =   EBox::Types::Abstract->new(
                                         fieldName => $unselectedUnionSubtype,
                                         printableName => $unselectedUnionSubtype, 
                                                                 );

    my $unionObject = new Test::MockObject();
    $unionObject->set_isa('EBox::Types::Union', 'EBox::Types::Abstract');
    $unionObject->set_always('fieldName', $unionName);
    $unionObject->set_always('selectedType', $selectedUnionSubtype);
    $unionObject->set_always('subtypes', [
                                          $selectedUnionSubtypeObject,
                                          $unselectedUnionSubtypeObject,
                                         ]);
    $unionObject->set_always('subtype',  $selectedUnionSubtypeObject);

    $row->addElement($unionObject);

    ok $row->elementExists($unionName), 
        'checking that union object exists using elementExists';
    ok $row->elementExists($selectedUnionSubtype), 
        'checking that selected union-subtype object exists using elementExists';
    ok ( not $row->elementExists($unselectedUnionSubtype) ), 
        'checking that unselected union-subtype object does not exists for elementExists';

    is_deeply $row->elementByName($unionName), $unionObject,
   'checking that elementByName can return the union object itself if requested';
    
    is_deeply(
              $row->elementByName($selectedUnionSubtype),
              $selectedUnionSubtypeObject,
   'checking that elementByName  returns the selected union-subtype object  if requested'
             );

    is $row->elementByName($unselectedUnionSubtype), undef,
           'checking that elementByName return undef when requested a unselected union subtype';
}


sub _populateRow
{
    my ($self, $row) = @_;

    my @elementsToAdd;
    foreach my $i(0 .. 5) {
        my $el = new EBox::Types::Abstract(
                                           fieldName => "fieldName$i",
                                           printableName => "printableName$i",
                                          );

        $el->setValue($i);

        push @elementsToAdd, $el;
    }


    foreach my $element (@elementsToAdd) {
        $row->addElement($element);
    }

}

sub _newRow
{
    my $gconfmodule = EBox::Global->modInstance('fakeModule');

    my $dataTableDir = 'DataTable';
    my $rowDir = "$dataTableDir/Row";

    my $row = EBox::Model::Row->new(

                                 gconfmodule => $gconfmodule,
                                 dir         => $rowDir,
                                );

    $row->setId('FAKE_ID');


    my $dataTable  = EBox::Model::DataTable->new(
                                                 gconfmodule => $gconfmodule,
                                                 directory   => $dataTableDir,
                                                 domain      => 'domain',
                                                );
    my $mockDataTable = Test::MockObject::Extends->new($dataTable);


    $row->setModel( $mockDataTable );


    return $row;
}

1;
