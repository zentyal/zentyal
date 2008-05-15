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
use EBox::Model::ModelManager;

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
#      Accessor to the model instances provided by this provider
#
# Parameters:
#
#      name - String model's name, that is, the value returned by
#      method <EBox::Model::DataTable::name>
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



#  Method: addModelInstance
#
#   add a instance of a provided model class which can have multiple
#   instances.  If the class can't have multiple instances a exeception will be
#   raised
#   
#  Parameters:
#     path - path to the instance. It must contain the index to identifiy the instance
#   instance - model instance to add
sub addModelInstance
{
  my ($self, $path, $instance) = @_;
  $self->addInstance(TYPE, $path, $instance);
}

#  Method: removeModelInstance
#
#   remove a instance of a provided model class which can have multiple
#   instances.  If the class can't have multiple instances a exeception will be
#   raised
#   
#  Parameters:
#     path - path to the instance. It must contain the index to identifiy the instance
#   
sub removeModelInstance
{
  my ($self, $path, $instance) = @_;
  $self->removeInstance(TYPE, $path, $instance);
}

#  Method: removeAllModelInstances
#
#   remove all instances of a provided model class
#
#  Parameters:
#     providedName - name of the model provider class
sub removeAllModelInstances
{
  my ($self, $path) = @_;
  $self->removeAllInstances(TYPE, $path);
}



# Method: modelClasses
#
#  This method must be overriden by all subclasses. It is used to register which
#  models are used by the module.
#
#  It must return a list reference with the following items:
#  -  the names of all model classes which does not require additional parameters
#  -  hash reference for other models with the following fields:
#         class      - the name of the class
#         parameters - reference to the list of parameters which we want to 
#                      pass to the model's constructor
sub modelClasses
{
    use Devel::StackTrace;
    my $stack = Devel::StackTrace->new();
    EBox::debug($stack->as_string());
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
#      The 'indexes' must be unique (at least the field 'id' is unique
#      and 'position' as well) and the submodel field name refers to the
#      name of the <EBox::Types::HasMany> field on the previous model
#      in the list.
#
#      If the model template may have more than one instance, the
#      model index must be passed as the first parameter to
#      distinguish from the remainder model instances.
#
#      If the action is 'set' and the selector is just one field you
#      can omit the field name when setting the element as the
#      following example shows:
#
#      $modelProvider->setAttr($attrValue);
#      $modelProvider->setAttr( attr => $attrValue);
#
#      The method call will follow this pattern:
#
#      methodName( ['modelIndex',] '/index1/index2/index3...', ...) if there are more
#      than one index
#
#      methodName( ['modelIndex',] 'index1', ...) if there are just one argument
#
#
sub _exposedMethods
  {

      return {};

  }

sub DESTROY { ; }

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

      # Getting the model instance
      my $model = EBox::Model::ModelManager->instance()->model($path[0]);
      if ( ref ( $model ) eq 'ARRAY' ) {
          # Search for the chosen model
          my $index = shift (@{$paramsRef});
          foreach my $modelInstance (@{$model}) {
              if ( $modelInstance->index() eq $index ) {
                  $model = $modelInstance;
                  last;
              }
          }
      } elsif ( $model->index() ) {
          shift(@{$paramsRef});
      }
      unless ( defined ( $model ) or (ref ( $model ) eq 'ARRAY' )) {
          throw EBox::Exceptions::Internal("Cannot retrieve model $path[0] "
                                           . 'it may be a multiple one or it '
                                           . 'is passed a wrong index');
      }

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
      my $mappedMethodName;
      if (  $subModelsName ) {
          $mappedMethodName = $action . $subModelsName . $model->name();
      } else {
          $mappedMethodName = $action;
      }

      # The parameters
      my @indexValues = ();
#      if ( @{$paramsRef} > 1 ) {
      unless ( ref ( $paramsRef->[0] ) ) {
          if ( defined ( $paramsRef->[0] )) {
              @indexValues = grep { $_ ne '' } split ( '/', $paramsRef->[0], scalar(@indexes));
              # Remove the index param if any
              shift ( @{$paramsRef} );
          }
      }
      my @mappedMethodParams = @indexValues;
      if ( @selectors == 1 and $action eq 'set' ) {
          # If it is a set action and just one selector is supplied,
          # the field name is set as parameter
          push ( @mappedMethodParams, $selectors[0] );
      }
      push ( @mappedMethodParams, @{$paramsRef} );
      if ( @selectors > 0 and $action eq 'get') {
          my $selectorsRef = \@selectors;
          push (@mappedMethodParams, $selectorsRef);
      }

      return $model->$mappedMethodName( @mappedMethodParams );

  }





sub modelsSaveConfig
{
  my ($self) = @_;

  foreach my $model ( @{ $self->models() } ) {
    if ($model->can('backupFiles')) {
      $model->backupFiles();
    }

  }

}

sub modelsRevokeConfig
{
  my ($self) = @_;

  foreach my $model ( @{ $self->models() } ) {
    if ($model->can('restoreFiles')) {
      $model->restoreFiles();
    }
  }

}



sub _filesArchive
{
  my ($self, $dir) = @_;
  return "$dir/modelsFiles.tar";
}

sub backupFilesInArchive
{
  my ($self, $dir) = @_;

  my @filesToBackup;
  foreach my $model ( @{ $self->models() } ) {
    if ($model->can('backupFilesPaths')) {
      push @filesToBackup, @{ $model->backupFilesPaths() };
    }
  }

  @filesToBackup or
    return;

  my $archive = $self->_filesArchive($dir);


  my $firstFile  = shift @filesToBackup;
  my $archiveCmd = "tar  -C / -cf $archive --atime-preserve --absolute-names --preserve --same-owner $firstFile";
  EBox::Sudo::root($archiveCmd);

  # we append the files one per one bz we don't want to overflow the command
  # line limit. Another approach would be to use a file catalog however I think
  # that for only a few files (typical situation for now) the append method is better
  foreach my $file (@filesToBackup) {
    $archiveCmd = "tar -C /  -rf $archive --atime-preserve --absolute-names --preserve --same-owner $file";
    EBox::Sudo::root($archiveCmd);
    
  }
}


sub restoreFilesFromArchive
{
  my ($self, $dir) = @_;
  my $archive = $self->_filesArchive($dir);

  ( -f $archive) or
    return;

  my $restoreCmd = "tar  -C / -xf $archive --atime-preserve --absolute-names --preserve --same-owner";
  EBox::Sudo::root($restoreCmd);
}

1;
