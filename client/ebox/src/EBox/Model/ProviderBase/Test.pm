package EBox::Model::ProviderBase::Test;
use base 'EBox::Test::Class';

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Perl6::Junction qw(any);

use lib '../../..';

use constant DEFAULT_INDEX => '';


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
    if (exists $classDescription->{parameters} ) {
      return @{ $classDescription->{parameters}  }
    }
    else {
      return ();
    }
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


sub _providedInstance
{
  my ($provider, $class) = @_;
  throw EBox::Exceptions::NotImplemented();
}


sub _oneInstanceClassesProvidedByName
{
  my ($self) = @_;
  return $self->_filterInstanceClassesByMultiple(0);
}

sub _multipleInstanceClassesProvidedByName
{
  my ($self) = @_;
  return $self->_filterInstanceClassesByMultiple(1);
 
}


sub _filterInstanceClassesByMultiple
{
  my ($self, $multipleWanted) = @_;
  $multipleWanted = $multipleWanted ? 1 : 0;

 my %classesProvidedByName = %{  $self->_classesProvidedByName( )};
  my %selectedClasses;
  while (my ($name, $classSpec) = each %classesProvidedByName) {
    my $multiple = 0;

    if (not (ref $classSpec)) {
      $multiple = 0;
    }
    elsif (ref $classSpec eq 'HASH') {
      $multiple = $classSpec->{multiple} ? 1 : 0;
    } 
    else {
      die 'incorrect class spec';
    }

    if ($multiple == $multipleWanted) {
      $selectedClasses{$name} = $classSpec;
    }
  }

  return \%selectedClasses;
}


sub addAndRemoveInstancesTest 
{
  my ($self, %params) = @_;
  my $getterMethod = $params{getterMethod};
  my $addMethod    = $params{addMethod};
  my $removeMethod = $params{removeMethod};

  my $provider = $self->_providerInstance();




  my @indexes = ('simpleIndex', 'multi/index');

  $self->_addAndRemoveInstancesTestForUnique(
					       %params,
					       provider => $provider,
					       indexes => \@indexes,
					      );

  $self->_addAndRemoveInstancesTestForMultiple(
					       %params,
					       provider => $provider,
					       indexes => \@indexes,
					      );
}

sub _addAndRemoveInstancesTestForUnique
{
  my ($self, %params) = @_;
  my $getterMethod = $params{getterMethod};
  my $addMethod    = $params{addMethod};
  my $removeMethod = $params{removeMethod};
  my $provider     = $params{provider};
  my @indexes      = @{ $params{indexes}  };

  my %oneInstanceClasses = %{ $self->_oneInstanceClassesProvidedByName };

  my ($name, $classSpec) = each %oneInstanceClasses;
  my $class = $self->className($classSpec);

  my $instance = $self->_providedInstance($provider, $class);

  my $path = "$name/" . $indexes[0]; 

  dies_ok {
    $provider->$addMethod($path, $instance)
  } 'checking wether a provided class without multiple propierty cannot add instances';

}


sub _addAndRemoveInstancesTestForMultiple
{
  my ($self, %params) = @_;
  my $getterMethod = $params{getterMethod};
  my $addMethod    = $params{addMethod};
  my $removeMethod = $params{removeMethod};
  my $provider     = $params{provider};
  my @indexes      = @{ $params{indexes}  };

  my $moduleName = $provider->name;
  
  my %multipleClasses = %{ $self->_multipleInstanceClassesProvidedByName };
  while (my ($name, $classSpec) = each %multipleClasses) {
    my $class = $self->className($classSpec);
    foreach my $index (@indexes) {
      my $path = "$name/$index";
      dies_ok {  $provider->$getterMethod($path) }
	'checking wether request for a non-added component raises exception';
      
      my $instance = $self->_providedInstance($provider, $class);

      lives_ok {
	$provider->$addMethod($path, $instance)
      } 'adding new instance';

      my $retreviedInstance; 
      lives_ok {
	$retreviedInstance = $provider->$getterMethod($path);      
      } 'getting new inserted instance';
      is $retreviedInstance, $instance, 'checking the retrevied instance';
      
    }
  }

  while (my ($name, $classSpec) = each %multipleClasses) {
    my $class = $self->className($classSpec);
    foreach my $index (@indexes) {
      my $path = "$moduleName/$name/$index";

      lives_ok {
	$provider->$removeMethod($path);
      } "removing instance with path $path";

      dies_ok {
	$provider->$removeMethod($path);
      } "checking wether we can't remove $path again";

      dies_ok {
	$provider->$getterMethod($path);
      } "checking that instance with path $path does not longer  exists";
    }
  }

  
}


sub removeAllInstancesTest
{
  my ($self, %params) = @_;
  my $getAllMethod = $params{getAllMethod};
  my $addMethod    = $params{addMethod};
  my $removeAllMethod = $params{removeAllMethod};

  my $provider = $self->_providerInstance();
  my $moduleName = $provider->name;
  
  # add instances
  my %multipleClasses = %{ $self->_multipleInstanceClassesProvidedByName };

  my @indexes = ('simpleIndex', 'multi/index');

  while (my ($name, $classSpec) = each %multipleClasses) {
    my $class = $self->className($classSpec);
    my @paths = map { "$name/$_" } @indexes;

    foreach my $path (@paths) {
      my $instance = $self->_providedInstance($provider, $class);
      $provider->$addMethod($path, $instance)
    }



    lives_ok {
      $provider->$removeAllMethod($name);
    } 'removing all instances';


    my $nInstances = grep {
      $_->isa($class)
    }  @{ $provider->$getAllMethod };

    is $nInstances, 0, 'checking wether all instances were removed';
  }
}






sub providedInstancesTest
{
  my ($self, $methodName, $addMethod) = @_;
  $methodName or $methodName = 'providedInstances';

  my $provider = $self->_providerInstance();
  my %expectedClasses;


  # setup one instance provided..
  my %oneInstanceClasses = %{ $self->_oneInstanceClassesProvidedByName };

  %expectedClasses = map {
    my $class = $self->className($_);
    ($class => 1) # one instance of class
  } values %oneInstanceClasses;


  # setup one instance provided..
  my %multipleInstanceClasses = %{ $self->_multipleInstanceClassesProvidedByName };
  # add multiple-instance provideds
  my @indexes = ('simpleIndex', 'multi/index');
  while (my ($name, $spec) = each %multipleInstanceClasses) {
    my $class = $self->className($spec);

    my @paths = map { "$name/$_" } @indexes;
    
    foreach my $path (@paths) {
      # add instance 
      my $instance = $self->_providedInstance($provider, $class);
      $provider->$addMethod($path, $instance);
    }

    $expectedClasses{$class} = scalar @paths;
  }

  # tests begin...


  my @instances;
  lives_ok {
    @instances = @{ $provider->$methodName };
  } "getting instances from provider with method $methodName";
  
  
  my  $totalInstances = 0;
  foreach (values %expectedClasses) {
    $totalInstances += $_;
  }
  
  is @instances, $totalInstances, 'checking wether the number of instances matches the number of provided classes';

  
  foreach my $class (keys %expectedClasses) {
    my $n = grep { $_->isa($class)  } @instances;
    is $n, $expectedClasses{$class}, 
      "checking there is the expected number of instances of  the provided class $class";
    
  }

    


  
}


sub providedInstanceTest
{
  my ($self, $methodName, $addMethod) = @_;
  $methodName or $methodName = 'providedInstance';

  # test t
  my $provider = $self->_providerInstance();

  my %oneInstanceClasses      = %{ $self->_oneInstanceClassesProvidedByName };
  my %multipleInstanceClasses = %{ $self->_multipleInstanceClassesProvidedByName };

  my @paths;
  push @paths , keys %oneInstanceClasses;

  my @indexes = ('simpleIndex', 'multi/index');
  while (my ($name, $spec) = each %multipleInstanceClasses) {
    my $class = $self->className($spec);

    my @p = map {
      "$name/$_"
    } @indexes;
    
    foreach my $path (@p) {
      # add instance 
      my $instance = $self->_providedInstance($provider, $class);
      $provider->$addMethod($path, $instance);
      # update path array
      push @paths, $path;
    }
  }


  # deviant argument test
  dies_ok {
    $provider->$methodName('inexistent');
  }'Expecitng failure when tryng to retrieve a inexistent provided instance';

  
  # straight tests
  my %allClassesByName = %{ $self->_classesProvidedByName };

  foreach my $path (@paths) {
    my ($name, $index) = $provider->decodePath($path);
    my $class = $self->className($allClassesByName{$name});
    
    my $instance;
    
    lives_ok {
      $instance = $provider->$methodName($path);
    } "getting a instance for provided class id $name";
    
    isa_ok($instance, $class);
  }



}


sub decodePathTest :Test(26)
{
  my ($self) = @_;

  my $provider   = $self->_providerInstance();
  my $moduleName = $provider->name;

  my @goodCases = (
		   [ 'gibon'  =>  ('gibon', DEFAULT_INDEX) ],
		   [ '/gibon'  =>  ('gibon', DEFAULT_INDEX) ],
		   [ 'gibon/'  =>  ('gibon', DEFAULT_INDEX) ],

		   ['gibon/ceniciento' => ('gibon', 'ceniciento')],
		   ['gibon/ceniciento/' => ('gibon', 'ceniciento')],
		   ['/gibon/ceniciento' => ('gibon', 'ceniciento')],
		   ["$moduleName/gibon/ceniciento/" => ('gibon', 'ceniciento')],
		   ["/$moduleName/gibon/ceniciento/" => ('gibon', 'ceniciento')],

		   ['gibon/manos/negras' => ('gibon', 'manos/negras')],
		   ['/gibon/manos/negras' => ('gibon', 'manos/negras')],
		   ['gibon/manos/negras/' => ('gibon', 'manos/negras')],
		   ["$moduleName/gibon/manos/negras/" => ('gibon', 'manos/negras')],
		   ["/$moduleName/gibon/manos/negras" => ('gibon', 'manos/negras')],
		  );


  foreach my $case (@goodCases) {
    my ($path, $expectedName, $expectedIndex) = @{ $case  };

    my ($name, $index) = $provider->decodePath($path);

    is $name, $expectedName, "Checking decoded provided name for path $path";
    is $index, $expectedIndex, "Checking decoded provided index for path $path";
    
  }

}


sub providedClassIsMultipleTest 
{
  my ($self, $type) = @_;

  my $provider = $self->_providerInstance();

  my %oneInstanceClasses = %{ $self->_oneInstanceClassesProvidedByName };
  foreach my $name (keys %oneInstanceClasses) {
    ok (not $provider->providedClassIsMultiple($type, $name)), 'checking wether a  non-multiple provided element is detected as such';
  }


  my %multipleClasses = %{ $self->_multipleInstanceClassesProvidedByName };
  foreach my $name (keys %multipleClasses) {
    ok  $provider->providedClassIsMultiple($type, $name), 'checking wether a multiple provided element is detected as such';
  }
}



1;
