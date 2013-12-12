# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::Model::ModelProvider::Test;

use lib '../../..';
use base 'EBox::Model::ProviderBase::Test';

use strict;
use warnings;

use Test::More;;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;
use Perl6::Junction qw(any);


use lib '../../..';

use EBox::Model::DataTable;
use EBox::Model::ModelProvider;

use constant TYPE          =>  'model' ;

sub _classesProvidedByName
{
  return  {
           Canoply => 'EBox::Jungle::Model::Canoply',
           Monkeys => {
                       class      => 'EBox::Jungle::Model::Monkeys',
                       parameters => [specie => 'gibbon'],
                       },
           # multiple instances model
           Humans => {
                      class => 'EBox::Jungle::Model::Humans',
                      multiple => 1,
                     },
          };
}





sub modelTest : Test(9)
{
  my ($self) = @_;
  $self->SUPER::providedInstanceTest('model', 'addModelInstance');
}


sub modelsTest : Test(5)
{
  my ($self) = @_;
  $self->SUPER::providedInstancesTest('models', 'addModelInstance');
}


sub addAndRemoveModelInstanceTest : Test(15)
{
  my ($self) = @_;
  $self->SUPER::addAndRemoveInstancesTest(
                                          getterMethod => 'model',
                                          addMethod   => 'addModelInstance',
                                          removeMethod => 'removeModelInstance',
                                         );
}

sub removeAllModelInstancesTest  : Test(2)
{
  my ($self) = @_;
  $self->SUPER::removeAllInstancesTest(
                                       getAllMethod => 'models',
                                       addMethod    => 'addModelInstance',
                                       removeAllMethod => 'removeAllModelInstances',
                                      );

}

sub providedClassIsMultipleTest : Test(3)
{
  my ($self) = @_;
  $self->SUPER::providedClassIsMultipleTest(TYPE);
}


sub _providerInstance
{
  my ($self) =  @_;
  my %modelClassesByName = %{ $self->_classesProvidedByName  };

  my $instance = {};
  bless $instance, 'EBox::Model::ModelProvider';

  $instance = Test::MockObject::Extends->new($instance);
  $instance->mock('modelClasses' => sub {
                                          return [values %modelClassesByName]
                                        }
              );
  $instance->mock( 'name' =>   sub { return 'moduleName'  }  );

  $instance->set_isa('EBox::Model::ModelProvider', 'EBox::GConfModule');

  return $instance;
}


sub _providedInstance
{
  my ($self, $provider, $class) = @_;

  my $provider = $self->_providerInstance();
  my $instance = $provider->newModelInstance(
                                             $class,
                                             name => $class->nameFromClass,
                                            );
}


sub _fakeModelClasses : Test(setup)
{
  my ($self) = @_;

  $self->_fakeProvidedClasses(parent => 'EBox::Model::DataTable');
}




1;
