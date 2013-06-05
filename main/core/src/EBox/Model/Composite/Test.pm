# Copyright (C) 2008-2013 Zentyal S.L.
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

use lib '../../..';

package EBox::Model::Composite::Test;
use base 'EBox::Test::Class';

use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;
use Perl6::Junction qw(any);

use EBox::Model::Row;
use EBox::Model::DataTable;
use EBox::Model::Composite;
use EBox::Model::Manager;

sub setModules : Test(setup)
{
    EBox::TestStubs::fakeModule(name => 'fakeModule');
}

sub clearGConf : Test(teardown)
{
    EBox::TestStubs::setConfig();
}

sub deviantDescriptionTest : Test(2)
{
    my ($self) = @_;
    my %cases = (
        'invalid layout' => {
            name => 'ctest',
            printableName => 'ctest',
            layout        => 'broken',
        },
        'empty name' =>  {
            name => '',
            printableName => 'ctest',
        },
    );

    while (my ($testName, $description) = each %cases) {
        my $composite;
        dies_ok {
            $composite = new TestComposite(description => $description);
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
        my $composite;
        lives_ok {
            $composite = new TestComposite(description => $description);
        } $testName;
    }
}

sub componentsTest : Test(17)
{
    my ($self) = @_;

    my @origComponents = @{ $self->_defaultComponents };
    my $description = {  name => 'compositeForComponentTests' };
    my $composite = new TestComposite(description => $description, components => \@origComponents);

    my @components;
    lives_ok {
        @components = @{ $composite->components() };
    } 'Checking components method call';

    is_deeply (\@components, \@origComponents, 'checking  components');

    # check componentByName
    # @componentByName from _standardComponest
    my @componentNames = qw(model1 model2 composite1 composite2);
    foreach my $name (@componentNames) {
        my $component = $composite->componentByName($name);
        isa_ok ($component, 'EBox::Model::Component', 'Checking that return of componentByName has proper class');
        is ($component->name(), $name, 'checking component fetched with componentByName');
    }

    foreach my $name (@componentNames) {
        my $component = $composite->componentByName($name, 1);
        is $component->name(), $name,
           'checking component fetched with componentByName with recursive option';
    }

    is $composite->componentByName('sdfd'), undef,
       'checking that componentByName for inexistent component returns undef';

    my $nestedComponentName = 'nestedModel1';
    is $composite->componentByName($nestedComponentName), undef,
       'checking that componentByName without recursive cannot get a nested component';

    my $fetchedNestedModel = $composite->componentByName($nestedComponentName, 1);
    is $fetchedNestedModel->name(), $nestedComponentName,
       'checking name of nested model fetched with componentByName with resursive option';
}

sub modelsTest : Test(9)
{
    my ($self) = @_;

    my @origComponents = @{ $self->_defaultComponents };
    my $description = {  name => 'compositeForModelTests' };
    my $composite = new TestComposite(description => $description, components => \@origComponents);

    my @models;
    lives_ok {
        @models = @{ $composite->models() };
    } 'Checking components method call';

    my @expectedNames = qw(model1 model2);
    my @modelNames = ();
    foreach my $model (@models) {
        push (@modelNames, $model->name());
    }
    is_deeply (\@modelNames, \@expectedNames, 'checking models');

    foreach my $model (@models) {
        isa_ok ($model, 'EBox::Model::DataTable', 'Checking that return of models has proper class');
    }

    my @recursiveModels;
    lives_ok {
        @recursiveModels = @{ $composite->models(1) };
    } 'Checking components method call with recursive option';

    foreach my $model (@recursiveModels) {
        isa_ok ($model, 'EBox::Model::DataTable', 'Checking that return of models with recursive option has proper class');
    }

    push (@expectedNames, 'nestedModel1');
    my @recursiveModelNames = ();
    foreach my $model (@recursiveModels) {
        push (@recursiveModelNames, $model->name());
    }
    is_deeply (\@recursiveModelNames, \@expectedNames, 'checking models with recursive option');
}

sub setDirectoryTest : Test(10)
{
    my ($self) = @_;

    my $emptyComposite = new TestComposite(
                                       description => {name => 'emptyCompositeForSetDirectoryTest'},
                                       components => [],
                                      );
    is undef, $emptyComposite->directory(),
       'checking that default directory is root (empty string))';

    my $directory = '/ea/oe';

    lives_ok {
        $emptyComposite->setDirectory($directory);
    } 'setDirectory in a composite with No components';

    is $emptyComposite->directory(), $directory,
       'checking directory';

    dies_ok {
        $emptyComposite->setDirectory(undef);
    } 'setDirectory to undef fails';

    $directory = '/dir1/dir2';
    my $composite = new TestComposite(
                       description => {name => 'compositeForSetDirectoryTest'},
                       components => $self->_defaultComponents(),
                      );

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
           'checking that directory was changed in subcomponents too';
    }
}

sub _mockModel
{
    my ($self, $name) = @_;

    my $model = Test::MockObject::Extends->new('EBox::Model::DataTable');
    $model->set_always('name' => $name);
    return $model;
}

sub _defaultComponents
{
    my ($self) = @_;
    my @components;
    push @components, $self->_mockModel('model1');
    push @components, $self->_mockModel('model2');
    push @components, new TestComposite(
                        description => { name => 'composite1'},
                        components => [ $self->_mockModel('nestedModel1') ],
                      );
    push @components, new TestComposite(
                        description => { name => 'composite2'},
                        components => [],
                      );

    return \@components;
}

package TestComposite;

use base 'EBox::Model::Composite';

sub new
{
    my ($class, %params) = @_;
    if (exists $params{description}) {
        my $description = delete $params{description};
        $params{__description} = $description;
    }
    my $self = $class->SUPER::new(%params);
    bless ($self, $class);
    return $self;
}

sub _description
{
    my ($self) = @_;
    return $self->{__description};
}

1;
