# Copyright (C) 2008-2012 eBox Technologies S.L.
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

    my @origComponents = @{ $self->_standardComponents };
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

sub setDirectoryTest #: Test(10)
{
    my ($self) = @_;

    TestComposite->setStandardDescription();

    my $composite = new TestComposite();
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

    TestComposite->setStandardDescriptionWithComponents();

    $composite = new TestComposite();
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

sub parentTest #: Test(13)
{
    my ($self) = @_;

    my $compDirectory = 'GlobalGroupPolicy/keys/glob9253/filterPolicy';
    my $parentRowId = 'glob9253';

    TestComposite->setStandardDescriptionWithComponents();

    my $parent = Test::MockObject->new();
    $parent->set_isa('EBox::Model::DataTable');
    $parent->mock(
        'row' => sub {
            my ($self, $id) = @_;

            if ($id eq $parentRowId) {
                my $row = Test::MockObject->new();
                $row->set_isa('EBox::Model::Row');
                $row->set_always(id => $parentRowId);
                return $row;
            } else {
                return undef;
            }
        }
    );

    my $composite = new TestComposite();
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

sub _mockModel
{
    my ($self, $name) = @_;

    my $model = Test::MockObject->new();
    $model->set_always('name' => $name);
    $model->set_isa('EBox::Model::DataTable');

    $model->mock(
        'setDirectory' => sub {
            my ($self, $dir) = @_;
            $dir or
            die 'no dir';

            $self->{confdir} = $dir;
        }
    );
    $model->mock(
        'directory' => sub {
            my ($self) = @_;
            return $self->{confdir};
        }
    );
    $model->mock('setParent' => \&EBox::Model::Component::setParent);
    $model->mock('parent' => \&EBox::Model::Component::parent);
    $model->mock('parentRow' => \&EBox::Model::DataTable::parentRow);
    $model->mock('setParentComposite' => \&EBox::Model::Component::setParentComposite);
    $model->mock('parentComposite' => \&EBox::Model::Component::parentComposite);
}

sub _mockModel
{
    my ($self, $name) = @_;

    my $model = Test::MockObject::Extends->new('EBox::Model::DataTable');
    $model->set_always('name' => $name);

    $model->mock(
        'setDirectory' => sub {
            my ($self, $dir) = @_;
            $dir or
            die 'no dir';

            $self->{confdir} = $dir;
        }
    );
    $model->mock(
        'directory' => sub {
            my ($self) = @_;
            return $self->{confdir};
        }
    );

}

sub _standardComponents
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
                        description => { name => 'composite2'}
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
