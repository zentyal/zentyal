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

# Group: Public methods

# Method: providedInstances
#
#
#  Parameters:
#     name
#
#   Returns:
#        all the instances of the given type
sub providedInstances
{
  my ($self, $type) = @_;

  if (not exists $self->{$type}) {
    $self->_populate($type);
  }


  return [  values %{  $self->{$type}  } ];
}

# Method: providedInstance
#
#  Parametes:
#   type
#   name
sub providedInstance
{
  my ($self, $type, $name) = @_;

  if (not exists $self->{$type}) {
    $self->_populate($type);
  }

  if (not (exists $self->{$type}->{$name}) ) {
    throw EBox::Exceptions::Internal("No object called $name found in this module");
  }

  return  $self->{$type}->{$name}
}

# Group: Private methods

sub _populate
{
  my ($self, $type) = @_;
  
  my @classes = @{  $self->_providedClasses($type) };

  $self->{$type} = {};


  foreach my $classSpec (@classes) {
    my $class;
    my @constructionParams;

    my $refType = ref $classSpec;
    if (not $refType) {
      $class = $classSpec;
    }
    elsif ($refType eq 'HASH') {
      exists $classSpec->{class} or
	throw EBox::Exceptions::Internal('Missing class field in provided class specification');
      $class = $classSpec->{class};
      @constructionParams = @{ $classSpec->{parameters}  };
    } 
    else {
      throw EBox::Exceptions::Internal("Bad reference type in _providedClasses: $refType")
    } 

    # load class
    eval "use $class";
    if ($@) {
      throw EBox::Exceptions::Internal("Error loading provided class $class: $@");
    }
  
    my $name =   $class->nameFromClass; # XXX change to $class->name when possible
    push @constructionParams, (name => $name);

    # construct instance
    my $instance =  $self->_newInstance($type, $class, @constructionParams);

    $name = $instance->name; # XXX remove when nameFromClass its changed to name
    $self->{$type}->{$name} = $instance;
  }


  
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
 
