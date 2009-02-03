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

package EBox::Model::Composite::Test;

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
use EBox::Model::Composite;
use EBox::Model::CompositeManager;
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


    my %models;

    sub EBox::Model::ModelManager::model
    {
        my ($self, $path) = @_;

        unless (  $path ) {
            throw EBox::Exceptions::MissingArgument('path');
        }

        my $model = $models{$path};
        if (not defined $model) {
            throw EBox::Exceptions::DataNotFound( data  => 'model',
                                                  value => $path);
        }

        return $model;
    }

    
    sub setModelForPath
    {
        my ($path, $model) = @_;
        $models{$path} = $model;
    }

    sub clearModelsForPath
    {
        %models = ();
    }


    sub setRowIdInUse
    {
        my ($rowId) = @_;
        $rowIdUsed = $rowId;
    }

    my %composites;

    sub EBox::Model::CompositeManager::composite
    {
        my ($self, $path) = @_;

        unless (  $path ) {
            throw EBox::Exceptions::MissingArgument('path');
        }

        my $composite = $composites{$path};
        if (not defined $composite) {
            throw EBox::Exceptions::DataNotFound( data  => 'composite',
                                                  value => $path);
        }

        return $composite;
    }

    
    sub setCompositeForPath
    {
        my ($path, $composite) = @_;
        $composites{$path} = $composite;
    }
 
    sub clearCompositesForPath
    {
        %composites = ();
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


sub clearModelsAndComposites : Test(teardown)
{
    clearModelsForPath();
    clearCompositesForPath();
}


sub standardSetupForModelsAndComposites
{
    my ($self) = @_;

    for my $id (1 ..2) {
        my $name = 'model' . $id;
        $self->_setMockModel($name);
    }

    for my $id (1 ..2) {
        # XXX is very broken to mock the same class that we are testing! refactor
        # this
        my $name = 'composite' . $id;
        my $composite = Test::MockObject->new();
        $composite->{components} = [];
        $composite->set_always('name' => $name);
        $composite->set_isa('EBox::Model::Composite', 'EBox::Model::Component');

        $composite->mock('setDirectory' => sub {
                         my ($self, $dir) = @_;
                         defined $dir or
                             die 'no dir';

                         $self->{gconfdir} = $dir;
                     }
                    );
        $composite->mock('directory' => sub {
                             my ($self) = @_;
                             return $self->{gconfdir};
                            }
                        );
        $composite->mock('addComponent' => sub {
                             my ($self, $comp) = @_;
                             push @{ $self->{components} }, $comp, 
                         }
                        );
        $composite->mock('components' => sub {
                             my ($self) = @_;
                             return  $self->{components} ; 
                           }
                         ),
        $composite->mock('componentByName' => sub {
                             my ($self, $name, $recursive) = @_;
                             # XXX recursive otpion not supproted
                             my @comps = @{ $self->components() };
                             my ($comp) = grep { 
                                 $name eq $_->name()
                             } @comps;
                             return $comp;
                            },
                        );
    $composite->mock('setParent' => \&EBox::Model::Component::setParent);
    $composite->mock('parent'    => \&EBox::Model::Component::parent);
    $composite->mock('parentRow'    => \&EBox::Model::Composite::parentRow);
    $composite->mock('setParentComposite'    => \&EBox::Model::Component::setParentComposite);
    $composite->mock('parentComposite'    => \&EBox::Model::Component::parentComposite);

        # path is the same than name for now
        setCompositeForPath($name, $composite);
    }


}



sub _setMockModel
{
    my ($self, $name) = @_;

    my $model = Test::MockObject->new();
    $model->set_always('name' => $name);
    $model->set_isa('EBox::Model::DataTable', 'EBox::Model::Component');

    $model->mock('setDirectory' => sub {
                     my ($self, $dir) = @_;
                     $dir or
                         die 'no dir';

                     $self->{gconfdir} = $dir;
                 }
                );
    $model->mock('directory' => sub {
                     my ($self) = @_;
                     return $self->{gconfdir};
                 }
                );
    $model->mock('setParent' => \&EBox::Model::Component::setParent);
    $model->mock('parent' => \&EBox::Model::Component::parent);
    $model->mock('parentRow' => \&EBox::Model::DataTable::parentRow);
    $model->mock('setParentComposite'    => \&EBox::Model::Component::setParentComposite);
    $model->mock('parentComposite'    => \&EBox::Model::Component::parentComposite);

    # path is the same than name for now
    setModelForPath($name, $model);
}

sub deviantDescriptionTest : Test(2)
{
    my ($self) = @_;
    my %cases = (
                 'select layout text but select layout was not setted'      => {
                                        name => 'ctest',
                                        printableName => 'ctest',
                                        layout        => 'tabbed',
                                        selectMessage => 'select',
                                       },
                 'empty name' =>  {
                                        name => '',
                                        printableName => 'ctest',
                                                                   
                                       },
                );

    while (my ($testName, $description) = each %cases) {
        CompositeSubclass->setNextDescription($description);
        my $composite;

        dies_ok {
            $composite = new CompositeSubclass();
        } $testName

        
    }

}


sub descriptionTest : Test(2)
{
    my ($self) = @_;
    my %cases = (
                 'empty descrition' => {},
                 'description'      => {
                                        name => 'ctest',
                                        printableName => 'ctest',
                                       }
                );

    while (my ($testName, $description) = each %cases) {
        CompositeSubclass->setNextDescription($description);
        my $composite;

        lives_ok {
            $composite = new CompositeSubclass();
        } $testName;
        
    }

}


sub componentsTest  : Test(17)
{
    my ($self) = @_;

    CompositeSubclass->setStandardDescriptionWithComponents();

    my $composite = new CompositeSubclass();
    my @components;
    lives_ok {
        @components = @{  $composite->components() };
    } 'Checking components method call';

    is @components, 4, 'checking number of components';

    foreach my $comp (@components) {
        isa_ok $comp, 'EBox::Model::Component', 
            'Checking class of value form the list returned in components()';
    }

    # check componentByName
    # @componentByName from setStandardDescriptionWithComponents
    my @componentNames = qw(model1 model2 composite1 composite2); 
    foreach my $name (@componentNames) {
        my $component = $composite->componentByName($name);
        is $component->name(), $name,
            'checking component fetched with componentByName';
    }

    foreach my $name (@componentNames) {
        my $component = $composite->componentByName($name, 1);
        is $component->name(), $name,
 'checking component fetched with componentByName with recursive option';
    }
    
    is $composite->componentByName('sdfd'), undef,
   'checking that componentByName for inexistent component returns undef';

    my $composite1 = $composite->componentByName('composite1');
    my $nestedComponentName = 'nested1';
    $self->_setMockModel($nestedComponentName);
    
    my $modelManager =  EBox::Model::ModelManager->instance();
    my $nestedModel = $modelManager->model($nestedComponentName);
    $composite1->addComponent($nestedModel);
    defined($composite1->componentByName($nestedComponentName)) or
        die 'addComponent error';


    is $composite->componentByName($nestedComponentName), undef,
   'checking that componentByName without recursive cannot get a nested component';



    my $fetchedNestedModel = $composite->componentByName($nestedComponentName, 1);
    is $fetchedNestedModel->name(), $nestedComponentName,
    'checking name of nested model fetched with componentByName with resursive option';
    
}


sub setDirectoryTest : Test(10)
{
    my ($self) = @_;

    CompositeSubclass->setStandardDescription();
    
    my $composite = new CompositeSubclass();
    is '', $composite->directory(),
        'checking that default directory is root (empty string))';


    my $directory = '/ea/oe';

    lives_ok {
        $composite->setDirectory($directory);
    } 'setDirectory in a composite with No components';

    is $composite->directory(), $directory,
        'checking directory';

    dies_ok {
        $composite->setDirectory(undef);
    } 'setDirectory to undef fails';


    CompositeSubclass->setStandardDescriptionWithComponents();

    $composite = new CompositeSubclass();
    lives_ok {
        $composite->setDirectory($directory);
    } 'setDirectory for a composite with components';

    is $composite->directory(), $directory,
        'checking directory change';
    foreach my $component (@{ $composite->components() }) {
        my $compDir = $directory;
        if (not $component->isa('EBox::Model::Composite')) {
            $compDir .= '/' . $component->name();
        }

        is $component->directory(), $compDir,
                'checking that directory was changed in subcompoents too';
    }

}



sub parentTest  : Test(13)
{
    my ($self) = @_;

    my $compDirectory = 'GlobalGroupPolicy/keys/glob9253/filterPolicy';
    my $parentRowId = 'glob9253';

    CompositeSubclass->setStandardDescriptionWithComponents();

    my $parent = Test::MockObject->new();
    $parent->set_isa('EBox::Model::DataTable');
    $parent->mock( 'row' => sub {
                           my ($self, $id) = @_;

                           if ($id eq $parentRowId) {
                               my $row = Test::MockObject->new();
                               $row->set_isa('EBox::Model::Row');
                               $row->set_always(id => $parentRowId);
                               return $row;
                           }
                           else {
                               return undef;
                           }
                       }
                     );







    my $composite = new CompositeSubclass();
    $composite->setDirectory($compDirectory);

    is $composite->parent(), undef,
        'checking that default parent is undef';
    is $composite->parentRow(), undef,
     'checkign that parentRow without parent returns undef';
    
    lives_ok {
        $composite->setParent($parent);
    } 'Setting parent for composite';

    is $composite->parent(), $parent,
        'checking that parent was correctly setted';
    
    my $parentRow = $composite->parentRow();
    is $parentRow->id(),
        $parentRowId,
        'checking that parentRow upon composite returns the correct row';

    my @components = @{ $composite->components() };
    while (@components) {
        my $component = shift @components;
        if ($component->isa('EBox::Model::Composite')) {
            push @components, @{ $component->components() };
        }

        is $component->parent(), $parent,
            'checking that parent was correctly setted in component';
        
        $parentRow = $component->parentRow();
        is $parentRow->id(),
            $parentRowId,
                'checking that parentRow upon component returns the correct row';
    }
}


package CompositeSubclass;
use base 'EBox::Model::Composite';

my $nextDescription;


sub _description
{
    return $nextDescription;
}


sub setNextDescription
{
    my ($class, $desc) = @_;
    $nextDescription = $desc;
}


sub setStandardDescription
{
    my ($class) = @_;

    my $desc = {
                name => 'ctest',
                printableName => 'ctest',
                components => [],
               };

    $class->setNextDescription($desc);
}


sub setStandardDescriptionWithComponents
{
    my ($class) = @_;

    EBox::Model::Composite::Test->standardSetupForModelsAndComposites();

    my $desc = {

                name => 'ctest',
                printableName => 'ctest',
                components => [qw(model1 model2 composite1 composite2)],
               };

    $class->setNextDescription($desc);
}

1;
