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


sub elementsTest : Test(3)
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

}



sub parentRowTest
{

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
