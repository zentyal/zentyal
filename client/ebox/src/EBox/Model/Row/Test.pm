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


sub setEBoxModules : Test(setup)
{
    EBox::TestStubs::fakeEBoxModule(name => 'fakeModule');

}

sub clearGConf : Test(teardown)
{
  EBox::TestStubs::setConfig();
}



sub deviantElementsTest : Test(4)
{
    my ($self) = @_;

    my $row= $self->_newRow();

    dies_ok {
        $row->addElement(undef);
    } 'Expecting fail when trying to add a undefined element';
    dies_ok {
        my $badElement = new Test::MockObject();
        $row->addElement($badElement);
    } 'Expecting fail when trying to addi a non ebox-type element';
    dies_ok {
        my $badElement = new EBox::Types::Abstract();
        $row->addElement($badElement);
    } 'Expecting fail when trying to add a ebox-type element without fieldName';

    $self->_populateRow($row);
    dies_ok {
        my $repeatedElement =  $row->elementByIndex(1);
        $row->addElement($repeatedElement);
    } 'Expecting fail when adding a repeated element';
}





sub elementsTest : Test(32)
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


    is scalar @elementsToAdd, $row->size(), 'checking size of row after addition of elements';

    # elements
    # hashElements


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



sub parentRowTest
{

}


sub unionTest
{
    my ($self) = @_;

    my $row= $self->_newRow();
    $self->_populateRow($row);
    # test: elementExists, elementByName

    my $unionName           = 'fakeUnion';
    my $selectedUnionSubtype = 'selected';
    my $unselectedUnionSubtype = 'unselected';
    my @unionTypes = ($selectedUnionSubtype, $unselectedUnionSubtype);

    my $fakeUnion = new Test::MockObject();
    $fakeUnion->set_isa('EBox::Types::Union');
    $fakeUnion->set_always('fieldName', $unionName);
    $fakeUnion->set_always('selected', $selectedUnionSubtype);

    $row->addElement($fakeUnion);

    
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
    my $dir = 'Row';

    my $row = EBox::Model::Row->new(

                                 gconfmodule => $gconfmodule,
                                 dir         => $dir,
                                );

    $row->setId('FAKE_ID');

    my $dataTableDir = 'DataTable';
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
