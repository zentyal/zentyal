# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Model::ProviderBase
#
#  Base class for provider of models and composites
package EBox::Model::ProviderBase;

use strict;
use warnings;

use EBox::Gettext;
use EBox::Exceptions::MissingArgument;

use constant DEFAULT_INDEX => '';




# Method: providedInstances
#
#
#  Parameters:
#     type - the type of provided classes
#
#   Returns:
#        all the instances of provided classes of the given type
sub providedInstances
{
  my ($self, $type) = @_;

  if (not exists $self->{$type}) {
    $self->_populate($type);
  }

  my @instances;
  foreach my $instancesByIndex (  values %{  $self->{$type}  } ) {
    push @instances, values %{ $instancesByIndex };
  }

  return \@instances;
}

# Method: providedInstance
#
#  Parameters:
#   type  - the type of the provided class
#   path  - path to the instance for retrieval
#
#  Returns:
#      the instance found at the path
sub providedInstance
{
  my ($self, $type, $path) = @_;
  $path or throw EBox::Exceptions::MissingArgument('path');
  $type or throw EBox::Exceptions::MissingArgument('type');

  $self->_assureTypeIsPopulated($type);

  my ($name, $index) = $self->decodePath($path);

  defined $index or
    $index = DEFAULT_INDEX;

  if (not (exists $self->{$type}->{$name}->{$index}) ) {
    my $prIndex = ($index eq DEFAULT_INDEX) ? '[DEFAULT INDEX]' : $index;
    throw EBox::Exceptions::Internal("No object called $name with index $prIndex found in this module");
  }

  return  $self->{$type}->{$name}->{$index};
}


sub _assureTypeIsPopulated
{
  my ($self, $type) = @_;
  if (not exists $self->{$type}) {
    $self->_populate($type);
  }
}

sub _populate
{
  my ($self, $type) = @_;
  
  my @classes = @{  $self->_providedClasses($type) };

  $self->{$type} = {};

  my $defaultIndex = DEFAULT_INDEX;

  foreach my $classSpec (@classes) {
    my $class;
    my @constructionParams;
    my $multiple;

    my $refType = ref $classSpec;
    if (not $refType) {
      $class = $classSpec;
    }
    elsif ($refType eq 'HASH') {
      exists $classSpec->{class} or
	throw EBox::Exceptions::Internal('Missing class field in provided class specification');
      $multiple = $classSpec->{multiple};
      
      $class = $classSpec->{class};

      if (exists $classSpec->{parameters}) {
	@constructionParams = @{ $classSpec->{parameters} };
      }


      if (@constructionParams and $multiple) {
	throw EBox::Exceptions::External(
					 __('A provided class with has multiple instances cannot have construction parameters specified')
					);
      }
    } 
    else {
      throw EBox::Exceptions::Internal("Bad reference type in _providedClasses: $refType")
    } 

    # load class
    eval "use $class";
    if ($@) {
      throw EBox::Exceptions::Internal("Error loading provided class $class: $@");
    }
  
    if (not $multiple) {
      my $name =   $class->nameFromClass; # XXX change to $class->name when possible
      push @constructionParams, (name => $name);
      
      # construct instance
      my $instance =  $self->_newInstance($type, $class, @constructionParams);
      
      $name = $instance->name; # XXX remove when nameFromClass its changed to
                               # name 

      $self->{$type}->{$name} =  {
				  $defaultIndex =>  $instance,
				 };
      
    }

  }

}


#  Method: providedClassIsMultiple
#
#  Parameters:
#      
#     type - type of the provided class
#     name - short name of the provided class
#
#   Returns:
#      wether the provided class can support multiple instances or not
sub providedClassIsMultiple
{
  my ($self, $type, $provided) = @_;

  $self->_assureTypeIsPopulated($type);

  my $defaultIndex = DEFAULT_INDEX;
  if (  exists $self->{$type}->{$provided}->{$defaultIndex} ) {
    return 0;
  } 
  else {
    return 1;
  }

}




#  Method: addInstance
#
#   add a instance of a provided class which can have multiple instances.
#   If the class can't have multiple instances a exeception will be raised
#   
#  Parameters:
#     type - type of provided classes
#     path - path to the instance. It must contain the index to identifiy the instance
#    instance - instance to add

sub addInstance
{
  my ($self, $type, $path, $instance) = @_;
  $instance or throw EBox::Exceptions::MissingArgument('instance');
  $path or throw EBox::Exceptions::MissingArgument('path');
  $type or throw EBox::Exceptions::MissingArgument('type');

  $self->_assureTypeIsPopulated($type);

  my ($providedName, $index) = $self->decodePath($path);
  
  $self->_checkIsMultiple($type, $providedName, $index);


  $self->{$type}->{$providedName}->{$index} = $instance;
}

#  Method: removeInstance
#
#   remove a instance of a provided class which can have multiple instances.
#   If the class can't have multiple instances a exeception will be raised
#   
#  Parameters:
#     type - type of provided classes
#     path - path for the instance to remove.
#             It must contain the index to identifiy the instance

sub removeInstance
{
  my ($self, $type, $path) = @_;
  $path or throw EBox::Exceptions::MissingArgument('path');
  $type or throw EBox::Exceptions::MissingArgument('type');

  $self->_assureTypeIsPopulated($type);

  my ($providedName, $index) = $self->decodePath($path);
  
  $self->_checkIsMultiple($type, $providedName, $index);

  if (exists $self->{$type}->{$providedName}->{$index}) {
    delete $self->{$type}->{$providedName}->{$index};
  }
  else {
    throw EBox::Exceptions::External(__x(
					'Provided object with index {i} soes not exist',
					i => $index,

				       )
				   );
  }
}

#  Method: removeAllInstances
#
#   remove all instances of a provided class
#
#  Parameters:
#     type - type of provided classes
#     providedName - name of the provided class
#
sub removeAllInstances
{
  my ($self, $type, $providedName) = @_;
  $providedName or throw EBox::Exceptions::MissingArgument('providedName');
  $type or throw EBox::Exceptions::MissingArgument('type');

  $self->_assureTypeIsPopulated($type);

  if (not $self->providedClassIsMultiple($type, $providedName)) {
    throw EBox::Exceptions::Internal("$providedName cannot have multiple instances")
  }

  $self->{$type}->{$providedName} = {};
}


sub _checkIsMultiple
{
  my ($self, $type, $provided, $index) = @_;

  $self->_assureTypeIsPopulated($type);

  if (not $self->providedClassIsMultiple($type, $provided)) {
    throw EBox::Exceptions::Internal(
		"$provided cannot have multiple instances of itself"
				    );
  }
 
  if ($index eq DEFAULT_INDEX) {
    thriw EBox::Exceptions::Internal('Invalid index for a multiple instance')
  }

  return 1;
}


# Method: decodePath
#
#   Parameters:
#     path - the path to decode
#
#   Return:
#      list context - a list containing the name of the provided class and
#                     the idnex
#      scalar context - hash with the fields name and index

sub decodePath
{
  my ($self, $path) = @_;
  $path or 
    throw EBox::Exceptions::MissingArgument('path');

  

  my $moduleName = $self->name();
  my $leadingModuleNameRe = "^$moduleName/+";
  $path =~ s{^/+}{};  # remove slash at the begin
  $path =~ s{$leadingModuleNameRe}{};

  my ($provided, $index) = split '/', $path, 2;;

  if (not defined $index) { 
    $index = DEFAULT_INDEX;
  }
  
  $provided =~ s{/+$}{};
  $index =~ s{/+$}{};  

  return wantarray ? ($provided, $index) : {name => $provided, index => $index};
}


# this must be overriden by the provider classes itselves
sub _newInstance
{
  my ($self, $type, $class, @params) = @_;
  my $methodName = 'new' . ucfirst $type . 'Instance';
  if (not $self->can($methodName)) {
    throw EBox::Exceptions::NotImplemented($methodName);
  }

  $self->$methodName($class, @params)
}




sub _providedClasses
{
  my ($self, $type) = @_;
  my $methodName =  $type . 'Classes';
  if (not $self->can($methodName)) {
    throw EBox::Exceptions::NotImplemented($methodName);
  }

  return $self->$methodName();

}


1;
 
