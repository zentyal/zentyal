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


use constant TYPE => 'composite';

sub _classesProvidedByName
{
  return  {
	   Plants => {
		      class => 'EBox::Jungle::Composite::Plants',
		      parameters => [ minHeight => 2, flowers => 'yes' ],
		     },
	   Animals => 'EBox::Jungle::Composite::Animals',
	   # multiple instances model
	   Tribes => {
		      class => 'EBox::Jungle::Composite::Tribes',
		      multiple => 1,
		     },
	  };
}



sub compositeTest : Test(9)
{
  my ($self) = @_;
  $self->SUPER::providedInstanceTest('composite','addCompositeInstance');  
}


sub compositesTest : Test(5)
{
  my ($self) = @_;
  $self->SUPER::providedInstancesTest('composites', 'addCompositeInstance');
}

sub addAndRemoveInstancesTest : Test(15)
{
  my ($self) = @_;
  $self->SUPER::addAndRemoveInstancesTest(
					  getterMethod => 'composite',
					  addMethod   => 'addCompositeInstance',
					  removeMethod => 'removeCompositeInstance',
					 );
}

sub removeAllInstancesTest  : Test(2)
{
  my ($self) = @_;
  $self->SUPER::removeAllInstancesTest(
				       getAllMethod => 'composites',
				       addMethod    => 'addCompositeInstance',
				       removeAllMethod => 'removeAllCompositeInstances',
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
  bless $instance, 'EBox::Model::CompositeProvider';

  $instance = Test::MockObject::Extends->new($instance);
  $instance->mock('_providedClasses' => sub {
		                          return [values %modelClassesByName]
	                                }
	      );
  $instance->mock( 'name' =>   sub { return 'moduleName'  }  );

  $instance->set_isa('EBox::Model::CompositeProvider', 'EBox::GConfModule');

  return $instance;
}


sub _providedInstance
{
  my ($self, $provider, $class) = @_;

  my $provider = $self->_providerInstance();

  my %modelClassesByName = %{ $self->_classesProvidedByName  };
  my ($classSpec) = grep {
    my $c = $self->className($_);
    $c eq $class;

  } values %modelClassesByName;

  my @params;
  if (ref $classSpec eq 'HASH') {
    if (exists $classSpec->{parameters}) {
      @params = @{ $classSpec->{parameters}  };
    }
  }

  my $instance = $provider->newCompositeInstance(
					     $class,
					     name => $class->nameFromClass,
					      @params,

					    );
}

sub _fakeCompositeClasses : Test(setup)
{
  my ($self) = @_;
  $self->_fakeProvidedClasses( parent => 'EBox::Model::Composite' );
}




1;
