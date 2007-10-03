package EBox::Model::ProviderBase::Test;
use base 'EBox::Test::Class';

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Perl6::Junction qw(any);

use lib '../../..';



sub _classesProvidedByName
{
  throw EBox::Exceptions::NotImplemented();
}


sub className
{
  my ($self, $classDescription) = @_;

  my $refType = ref $classDescription;



  if (not $refType) {
    return $classDescription;
  }
  elsif ($refType eq 'HASH') {
    return $classDescription->{class}
  }
  else {
    die "bad ref type $refType";
  }
}


sub classParameters
{
  my ($self, $classDescription) = @_;

  my $refType = ref $classDescription;
  if (not $refType) {
    return ();
  }
  elsif ($refType eq 'HASH') {
    return @{ $classDescription->{parameters} }
  }
  else {
    die "bad ref type $refType";
  }
}


sub _classParametersNames
{
  my ($self, $classDescription) = @_;
  my %params = $self->classParameters($classDescription);
  return keys %params;
}


sub _fakeProvidedClasses
{
  my ($self, %params) = @_;
  my $parent = delete $params{parent};
  $parent or die 'Missing parent parameter';

  my %modelClassesByName = %{ $self->_classesProvidedByName  };

  foreach my $classDescription (values %modelClassesByName) {
    my $class = $self->className($classDescription);
    my @classParams = $self->_classParametersNames($classDescription);


    # XXX remove mocked name method when name == nameFromClass
    my @isa =($class, $parent);
    my $createIsaCode =  'package ' . $class . "; use base qw(@isa);";
    eval $createIsaCode;
    die "When creating ISA array $@" if  $@;

    Test::MockObject->fake_module($class,
				  new => sub {
				    my ($class, %params) =  @_;

				    if (@classParams) {
				      if (not keys %params) {
					die "no parameters provided to the constructor";
				      }

				      my $anyParam = any (keys %params);
				      foreach my $param (@classParams) {
					if (not ($param eq $anyParam)) {
					  die "Missing constructor parameter: $param";
					} 
				      }

				    }

				    my $self = $parent->new(%params);


				    bless $self, $class;
                                      


				    return $self;
				  }, # end new
				  name => sub {   
				    my ($class) = @_;
				    return $class->nameFromClass(@_) 
				  },

				 );
  } # end of foreach class
}


sub _providerInstance
{
  throw EBox::Exceptions::NotImplemented();
}



sub providedInstancesTest
{
  my ($self, $methodName) = @_;
  $methodName or $methodName = 'providedInstances';

  my %classesProvidedByName = %{  $self->_classesProvidedByName( )};

  my $provider = $self->_providerInstance();


  for (0 ..1) {
    # we do two times the test to assure it works without cached values and with
    # its 
    my @instances;
    lives_ok {
           @instances = @{ $provider->$methodName };
      } "getting instances from provider with method $methodName";
    
    my @classes = map {
      $self->className($_);
    } values %classesProvidedByName;
    
    is @instances, @classes, 'checking wether the number of instances matches the number of provided classes';
    foreach my $class (@classes) {
      my $n = grep { $_->isa($class)  } @instances;
      is $n, 1, "Cheking there is only one instance of  the provided class $class";
      
    }

    
  }

  
}


sub providedInstanceTest
{
  my ($self, $methodName) = @_;
  $methodName or $methodName = 'providedInstance';

  my %classesProvidedByName = %{  $self->_classesProvidedByName( )};

  my $provider = $self->_providerInstance();
  
  dies_ok {
    $provider->$methodName('inexistent');
  }'Expecitng failure when tryng to retrieve a inexistent provided instance';

  
  for (0 ..1) {
    # we do this two times the test to assure it works without cached values and
    # with them
    while ( my ($name, $classDescription) = each %classesProvidedByName) {
      my $class = $self->className($classDescription);

      my $instance;

      lives_ok {
	$instance = $provider->$methodName($name);
      } "getting a instance for provided class id $name";

      isa_ok($instance, $class);
    }

  }

}

1;
