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

# Class: EBox::Model::ModelProvider
#
#   Interface meant to be used for classes providing models
package EBox::Model::ModelProvider;

use base 'EBox::Model::ProviderBase';

use strict;
use warnings;

use EBox::Gettext;

use constant TYPE => 'model';

# Method: models 
# 
#   This method must be overriden in case your module needs no
#   standard-behaviour when creating model instances. In that case the method
#   modelClasses is ignored.
#   
#   In most cases you will not need to override it
#
# Returns:
#
#	array ref - containing instances of the models
sub models 
{
  my ($self) = @_;
  return $self->providedInstances(TYPE);
}

# Method: reloadModelsOnChange
#
#    This method indicates the model manager to call again
#    <EBox::Model::ModelProvider::models> method when an action is
#    performed on a model.
#
# Returns:
#
#    array ref - containing the model name (or context name) when the
#    model provider want to be notified
#
sub reloadModelsOnChange
{

    return [];

}

# Method: model
#
#
# Parameters:
#          name - model's name
#
# Returns:
#   a instance of the model requested
sub model
{
  my ($self, $name) = @_;
  return  $self->providedInstance(TYPE, $name);
}



# internal utility function, invokes the model constructor
sub newModelInstance
{
  my ($self, $class, %params) = @_;
  my $directory = delete $params{name};

    my $instance = $class->new(
			          gconfmodule => $self,
			          directory   => $directory,
			          %params,
			      );

  return $instance;
}


# Method: modelClasses
#
#  This method must be overriden by all subclasses. It is used to rgister which
#  models are use by the module.
#
#  It must return a list reference with the following items:
#  -  the names of all model classes which does not require additional parameters
#  -  hash reference for other models with the following fields:
#         class      - the name of the class
#         parameters - reference to the list of parameters which we want to 
#                      pass to the model's constructor
sub modelClasses
{
  throw EBox::Exceptions::NotImplemented('modelClasses');
}



# Method: _exposedMethods
#
#      Get the list of exposed method to manage the models. It could
#      be very useful for Perl scripts on local or using SOAP protocol
#
# Returns:
#
#      hash ref - the list of the exposes method in a hash ref every
#      component which has the following description:
#
#      methodName => { action   => '[add|set|get|del]',
#                      path     => [ 'modelName', 'submodelFieldName1', 'submodelFieldName2',... ],
#                      indexes  => [ 'indexFieldNameModel', 'indexFieldNameSubmodel1' ],
#                      [ selector => [ 'field1', 'field2'...] ] # Only available for set/get actions
#
#      The indexes must be unique (at least the field 'id' is unique
#      and 'position' as well) and the submodel field name refers to the
#      name of the <EBox::Types::HasMany> field on the previous model
#      in the list
#
#      The method call will follow this pattern:
#
#      methodName( '/index1/index2/index3...', ...) if there are more
#      than one index
#
#      methodName( 'index1', ...) if there are just one argument
#
#
sub _exposedMethods
  {

      return {};

  }


# Method: AUTOLOAD
#
#       It does a mapping among the exposed methods and the autoload
#       methods created at the DataTable class
#
# Parameters:
#
#       params - array the parameters from the undefined method
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown if the method is not
#       exposed
#
sub AUTOLOAD
  {

      my ($self, @params) = @_;

      my $methodName = our $AUTOLOAD;

      $methodName =~ s/.*:://;

      # Ignore DESTROY callings
      if ( $methodName eq 'DESTROY' ) {
          return;
      }

      my $exposedMethods = $self->_exposedMethods();
      if ( exists $exposedMethods->{$methodName} ) {
          return $self->_callExposedMethod($exposedMethods->{$methodName}, \@params);
      } else {
          throw EBox::Exceptions::Internal("Undefined method $methodName");
      }

  }

# Group: Private methods

# Method: _callExposedMethod
#
#     This method does the mapping between the exposed method and the
#     autoload method parsed by the DataTable class
#
# Parameters:
#
#     methodDescription - hash ref the method description as it is
#     explained by <EBox::Model::ModelProvider::_exposedMethods>
#     header
#
#     params - array ref the parameters from the undefined method
#
sub _callExposedMethod
  {

      my ($self, $methodDesc, $paramsRef) = @_;

      my @path = @{$methodDesc->{path}};
      my @indexes = @{$methodDesc->{indexes}} if exists ($methodDesc->{indexes});
      my $action = $methodDesc->{action};
      my @selectors = @{$methodDesc->{selector}} if exists ($methodDesc->{selector});

      my $model = EBox::Model::ModelManager->instance()->model($path[0]);

      # Set the indexField for every model with index
      if ( @indexes > 0 ) {
          unless ( $indexes[0] eq 'id' or
                   $indexes[0] eq 'position') {
              $model->setIndexField($indexes[0]);
          }
          my $submodel = $model;
          foreach my $idx (1 .. $#indexes) {
              my $hasManyField = $submodel->fieldHeader($path[$idx]);
              my $submodelName = $hasManyField->foreignModel();
              $submodel = EBox::Model::ModelManager->instance()->model($submodelName);
              unless ( $indexes[$idx] eq 'id' or
                       $indexes[$idx] eq 'position') {
                  $submodel->setIndexField($indexes[$idx]);
              }
          }
      }

      # Submodel in the method name
      my $subModelsName = "";
      # Remove the model name
      shift (@path);
      foreach my $field (reverse @path) {
          $subModelsName .= ucfirst ( $field ) . 'To';
      }

      # The name
      my $mappedMethodName = $action . $subModelsName . $model->name();

      # The parameters
      my @indexValues = grep { $_ ne '' } split ( '/', $paramsRef->[0]);
      # Remove the index param
      shift ( @{$paramsRef} );
      my @mappedMethodParams = @indexValues;
      push ( @mappedMethodParams, @{$paramsRef} );
      if ( @selectors > 0 and $action eq 'get') {
          my $selectorsRef = \@selectors;
          push (@mappedMethodParams, $selectorsRef);
      };

      return $model->$mappedMethodName( @mappedMethodParams );

  }

1;
