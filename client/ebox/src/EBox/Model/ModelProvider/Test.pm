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



sub _classesProvidedByName
{
  return  {
	   Canoply => 'EBox::Jungle::Model::Canoply',
	   Monkeys => {
		       class      => 'EBox::Jungle::Model::Monkeys',
		       parameters => [specie => 'gibbon'],
		       },
	  };
}





sub modelTest : Test(9)
{
  my ($self) = @_;
  $self->SUPER::providedInstanceTest('model');  
}


sub modelsTest : Test(8)
{
  my ($self) = @_;
  $self->SUPER::providedInstancesTest('models');
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

  $instance->set_isa('EBox::Model::ModelProvider', 'EBox::GConfModule');

  return $instance;
}





sub _fakeModelClasses : Test(setup)
{
  my ($self) = @_;

  $self->_fakeProvidedClasses(parent => 'EBox::Model::DataTable');
}




1;
