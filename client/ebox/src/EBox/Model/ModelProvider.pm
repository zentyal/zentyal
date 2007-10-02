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

use strict;
use warnings;

use EBox::Gettext;

# Group: Public methods

sub new 
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: models 
# 
#   This method must be overriden in case of your module provides any model
#
# Returns:
#
#	array ref - containing instances of the models
sub models 
{
    return [];
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
#      The indexes must be unique (at least the field 'id' is unique)
#      and the submodel field name refers to the name of the
#      <EBox::Types::HasMany> field on the previous model in the list
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
          unless ( $indexes[0] eq 'id' ) {
              $model->setIndexField($indexes[0]);
          }
          my $submodel = $model;
          foreach my $idx (1 .. $#indexes) {
              my $hasManyField = $submodel->fieldHeader($path[$idx]);
              my $submodelName = $hasManyField->foreignModel();
              $submodel = EBox::Model::ModelManager->instance()->model($submodelName);
              $submodel->setIndexField($indexes[$idx]);
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
      my @mappedMethodParams = @{$paramsRef};
      if ( @selectors > 0 and $action eq 'get') {
          my $selectorsRef = \@selectors;
          push (@mappedMethodParams, $selectorsRef);
      };

      return $model->$mappedMethodName( @mappedMethodParams );

  }

1;
