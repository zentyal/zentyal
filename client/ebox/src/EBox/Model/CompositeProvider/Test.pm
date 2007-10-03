package EBox::Model::CompositeProvider::Test;

use lib '../../..';
use base 'EBox::Model::ProviderBase::Test';

use strict;
use warnings;

use Test::More;;
use Test::Exception;
use Test::MockObject;
use Test::MockObject::Extends;


use lib '../../..';


use EBox::Model::CompositeProvider;
use EBox::Model::Composite;

sub _classesProvidedByName
{
  return  {
	   Plants => {
		      class => 'EBox::Jungle::Composite::Plants',
		      parameters => [ minHeight => 2, flowers => 'yes' ],
		     },
	   Animals => 'EBox::Jungle::Composite::Animals',
	  };
}



sub compositeTest : Test(9)
{
  my ($self) = @_;
  $self->SUPER::providedInstanceTest('composite');  
}


sub compositesTest : Test(8)
{
  my ($self) = @_;
  $self->SUPER::providedInstancesTest('composites');
}


sub _providerInstance
{
  my ($self) =  @_;
  my %modelClassesByName = %{ $self->_classesProvidedByName  };

  my $instance = {};
  bless $instance, 'EBox::Model::CompositeProvider';

  $instance = Test::MockObject::Extends->new($instance);
  $instance->mock('_providedClasses' => sub {
		                          return [values %modelClassesByName]
	                                }
	      );

  $instance->set_isa('EBox::Model::CompositeProvider', 'EBox::GConfModule');

  return $instance;
}


sub _fakeCompositeClasses : Test(setup)
{
  my ($self) = @_;
  $self->_fakeProvidedClasses( parent => 'EBox::Model::Composite' );
}




1;
