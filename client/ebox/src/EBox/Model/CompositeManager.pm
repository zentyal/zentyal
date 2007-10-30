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

# Class: EBox::Model::CompositeManager
#
#   This class is used to coordinate all the available composite
#   models along eBox. It allows us to have a centralized place where
#   all composite models are instanced.
#

# FIXME: Not just index by name but also by ebox module to allow name repetition

package EBox::Model::CompositeManager;

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::DataNotFound;
use EBox::Global;

# Constants:
use constant VERSION_KEY => 'composite_manager/version';

# Singleton variable
my $_instance = undef;

# Group: Public methods

# Method: Instance
#
#     Get the singleton instance of the composite manager.
#     *(Static method)*
#
# Returns:
#
#     <EBox::Model::CompositeManager> - the instance of the composite
#     manager
#
sub Instance
  {

      my ($class) = @_;

      unless ( defined ( $_instance )) {
          $_instance = $class->_new();
      }

      return $_instance;

  }

# Method: composite
#
#     Given a composite name it returns an instance of this composite
#
# Parameters:
#
#     composite - String the composite model's name, it can follow one
#     of these patterns:
#
#        'compositeName' - used only if the compositeName is unique
#        within eBox framework and no execution parameters are
#        required to its creation
#
#        '/moduleName/compositeName[/index1] - used when a name space
#        is required or parameters are set on runtime.
#
# Returns:
#
#     <EBox::Model::Composite> - the composite object if just one
#     composite instance is required
#
#     array ref - containing <EBox::Model::Composite> instances if
#     more than one composite corresponds to the given composite name.
#
# Exceptions:
#
#     <EBox::Exceptions::DataNotFound> - thrown if the composite does
#     not exist given the composite parameter
#
#     <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#     argument is missing
#
#     <EBox::Exceptions::Internal> - thrown if the composite parameter
#     does not follow the given patterns
#
sub composite
{

    my ($self, $path) = @_;

    # Re-read from the modules if the model manager has changed
    if ( $self->_hasChanged() ) {
        $self->_setUpComposites();
        $self->{'version'} = $self->_version();
    }

    # Check arguments
    unless ( defined ( $path )) {
        throw EBox::Exceptions::MissingArgument('composite');
    }

    my ($moduleName, $compName, @indexes) = grep { $_ ne '' } split ( '/', $path);
    if ( not defined ( $compName ) and $path =~ m:/: ) {
        throw EBox::Exceptions::Internal('One composite element is given and '
                                         . 'slashes are given. The valid format '
                                         . 'requires no slashes');
    }

    unless ( defined ( $compName )) {
        $compName = $moduleName;
        # Try to infer the module name from the compName
        $moduleName = $self->_inferModuleFromComposite($compName);
    }

    if ( exists $self->{composites}->{$moduleName}->{$compName} ) {
        if ( @indexes > 0 and $indexes[0] ne '*' ) {
            # There are at least one index
            return $self->_chooseCompositeUsingIndex($moduleName, $compName, \@indexes);
        } else {
            if ( @{$self->{composites}->{$moduleName}->{$compName}} == 1 ) {
                return $self->{composites}->{$moduleName}->{$compName}->[0];
            } else {
                return $self->{composites}->{$moduleName}->{$compName};
            }
        }
    } else {
        throw EBox::Exceptions::DataNotFound( data  => 'composite',
                                              value => $compName,
                                            );
    }

}

# Method: addComposite
#
#       Add a composite instance to the manager
#
# Parameters:
#
#       compositePath - String the composite path to add
#
#       composite - <EBox::Model::Composite> the composite instance
#
sub addComposite
{
    my ($self, $compositePath, $composite) = @_;

    my ($moduleName, $compositeName, @indexes) = grep { $_ ne '' } split ('/', $compositePath);

    unless ( defined ( $moduleName ) and defined ( $compositeName )) {
        throw EBox::Exceptions::Internal("Path bad formed $compositePath, "
                                         . 'it should follow the pattern /modName/compName[/index]');
    }

    push ( @{$self->{composites}->{$moduleName}->{$compositeName}},
           $composite);

    return;

}

# Method: addComposite
#
#       Remove a (some) composite(s) instance from the manager
#
# Parameters:
#
#       compositePath - String the composite path to add
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - thrown if the path is bad
#       formed
#
sub removeComposite
{
    my ($self, $compositePath) = @_;

    my ($moduleName, $compositeName, @indexes) = grep { $_ ne '' } split ('/', $compositePath);

    unless ( defined ( $moduleName ) and defined ( $compositeName )) {
        throw EBox::Exceptions::Internal("Path bad formed $compositePath, "
                                         . 'it should follow the pattern /modName/compName[/index]');
    }

    my $composites = $self->{composites}->{$moduleName}->{$compositeName};
    if ( @indexes > 0 ) {
        for my $idx (0 .. $#$composites) {
            my $composite = $composites->[$idx];
            if ( $composite->index() eq $indexes[0] ) {
                splice ( @{$composites}, $idx, 1 );
                last;
            }
        }
    } else {
        delete ( $self->{composites}->{$moduleName}->{$compositeName} );
    }

}


# Method: modelActionTaken
#
#	This method is used to let composites know when other model has
#	taken an action.
#
# Parameters:
#
#   (POSITIONAL)
#
#   model - String model name where the action took place
#   action - String represting the action:
#   	     [ add, del, edit, moveUp, moveDown ]
#
#   row  - hash ref row modified
#
# Returns:
#
#   String - any i18ned string given by other modules when a change is done
#
# Exceptions:
#
# <EBox::Exceptions::DataNotFound> if the model does not exist
# <EBox::Exceptions::MissingArgument> if argument is missing
#
sub modelActionTaken
{
    my ($self, $model, $action, $row) = @_;

    throw EBox::Exceptions::MissingArgument("model") unless (defined($model));
    throw EBox::Exceptions::MissingArgument("action") unless (defined($action));
    throw EBox::Exceptions::MissingArgument("row") unless (defined($row));

    if ( defined $row->{'id'} ) {
        EBox::debug("$model has taken action '$action' on row $row->{'id'}");
    } else {
        EBox::debug("$model has taken action '$action' on row");
    }

    # return unless (exists $self->{'notifyActions'}->{$model});

    my $modelManager = EBox::Model::ModelManager->instance();
    my $strToRet = '';
    for my $observerName (@{$self->{'notifyActions'}->{$model}}) {
        EBox::debug("Notifying $observerName composite");
        my $observerComposite = $self->composite($observerName);
        $strToRet .= $observerComposite->notifyModelAction($model, $action, $row) .
          '<br>';
    }

    if ( exists $self->{'reloadActions'}->{$model} ) {
        $self->markAsChanged();
    }


    return $strToRet;

}

# Method: markAsChanged
#
# 	(PUBLIC)
#
#   Mark the composite manager as changed. This is done when a change is
#   done in the composites to allow interprocess coherency.
#
#
sub markAsChanged
{

    my ($self) = @_;

    my $gl = EBox::Global->getInstance();

    my $oldVersion = $self->_version();
    $oldVersion = 0 unless ( defined ( $oldVersion ));
    $oldVersion++;
    $gl->set_int(VERSION_KEY, $oldVersion);

}

# Group: Private methods

# Constructor for the singleton variable
sub _new
  {

      my ($class) = @_;

      my $self = {};
      bless ($self, $class);

      $self->{version} = $self->_version();
      $self->_setUpComposites();

      return $self;

  }

# Method: _setUpComposites
#
#     Fetch composites from all classes which implements the interface
#     <EBox::Model::CompositeProvider>
#
sub _setUpComposites
  {

      my ($self) = @_;

      my $global = EBox::Global->getInstance();

      $self->{composites} = {};
      $self->{reloadActions} = {};
      my @modules = @{$global->modInstancesOfType('EBox::Model::CompositeProvider')};
      foreach my $module (@modules) {
          $self->_setUpCompositesFromProvider($module);
      }

  }

# Method: _setUpCompositesFromProvider
#
#   Fetch composites from a <EBox::Model::CompositeProvider> interface
#   instances and creates its dependencies
#
# Parameters:
#
#   compositeProvider - <EBox::Model::CompositeProvider> the composite
#   provider class
#
sub _setUpCompositesFromProvider
{
    my ($self, $provider) = @_;

    foreach my $composite (@{$provider->composites()}) {
        push ( @{$self->{composites}->{$provider->name()}->{$composite->name()}},
               $composite);
    }
    for my $model (@{$provider->reloadCompositesOnChange()}) {
        push ( @{$self->{'reloadActions'}->{$model}}, $provider->name());
    }

}

# Method: _inferModuleFromComposite
#
#
# Parameters:
#
#      compositeName - String the composite's name
#
# Returns:
#
#      String - the module's name if any
#
sub _inferModuleFromComposite
{

    my ($self, $compName) = @_;

    my $composites = $self->{composites};
    my $returningModule = undef;
    foreach my $module (keys %{$composites}) {
        foreach my $compKind ( keys %{$composites->{$module}} ) {
            if ( $compKind eq $compName ) {
                if ( defined ( $returningModule )) {
                    throw EBox::Exceptions::Internal('Cannot infere the module '
                                                     . 'since more than one module '
                                                     . 'contain this composite. '
                                                     . 'A namespace is required for '
                                                     . $compName);
                }
                $returningModule = $module;
            }
        }
    }

    unless ( defined ($returningModule) ) {
        throw EBox::Exceptions::DataNotFound( data => 'compositeName',
                                              value => $compName);
    }

    return $returningModule;

}

# Method: _chooseCompositeUsingIndex
#
#
# Parameters:
#
#       moduleName - String the module's name
#       compositeName - String the composite's name
#
#       indexes - array ref containing the indexes to distinguish
#       among composite instances
#
# Returns:
#
#       <EBox::Model::Composite> - the chosen composite
#
# Exceptions:
#
#       <EBox::Exceptions::DataNotFound> - thrown if no composite can
#       be found with the given parameters
#
sub _chooseCompositeUsingIndex
{

    my ($self, $moduleName, $compositeName, $indexesRef) = @_;

    my $composites = $self->{composites}->{$moduleName}->{$compositeName};

    foreach my $composite (@{$composites}) {
        # Take care, just checkin first index
        if ( $composite->index() eq $indexesRef->[0] ) {
            return $composite;
        }
    }

    # No match
    throw EBox::Exceptions::DataNotFound(data => 'compositeInstance',
                                         value => "/$moduleName/$compositeName/"
                                        . join ('/', @{$indexesRef}));


}

# Method: _hasChanged
#
# 	(PRIVATE)
#
#   Mark the model manager as changed. This is done when a change is
#   done in the models to allow interprocess coherency. 
#
#
sub _hasChanged
{

    my ($self) = @_;

    return $self->{'version'} < $self->_version();

}

# Method: _version
#
#       (PRIVATE)
#
#   Get the data version
#
# Returns:
#
#       Int - the data version from the model manager
#
#       undef - if there is no data version
#
sub _version
{

    my $gl = EBox::Global->getInstance();

    return $gl->get_int(VERSION_KEY);

}

1;
