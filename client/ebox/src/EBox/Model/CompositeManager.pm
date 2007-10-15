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
#     composite - String the composite model's name
#
# Returns:
#
#     <EBox::Model::Composite> - the composite object
#
# Exceptions:
#
#     <EBox::Exceptions::DataNotFound> - thrown if the composite does
#     not exist
#
sub composite
{

    my ($self, $compositeName) = @_;

    # Re-read from the modules if the model manager has changed
    if ( $self->_hasChanged() ) {
        $self->_setUpComposites();
        $self->{'version'} = $self->_version();
    }


    if ( exists $self->{composites}->{$compositeName}) {
        return $self->{composites}->{$compositeName};
    } else {
        throw EBox::Exceptions::DataNotFound( data  => 'composite',
                                              value => $compositeName,
                                            );
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

    EBox::debug("$model has taken action '$action' on row $row->{'id'}");

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
        $self->_markAsChanged();
    }


    return $strToRet;

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
        $self->{composites}->{$composite->name()} = $composite;
    }
    for my $model (@{$provider->reloadCompositesOnChange()}) {
        push ( @{$self->{'reloadActions'}->{$model}}, $provider->name());
    }

}

# Method: _markAsChanged
#
# 	(PRIVATE)
#
#   Mark the composite manager as changed. This is done when a change is
#   done in the composites to allow interprocess coherency.
#
#
sub _markAsChanged
{

    my ($self) = @_;

    my $gl = EBox::Global->getInstance();

    my $oldVersion = $self->_version();
    $oldVersion = 0 unless ( defined ( $oldVersion ));
    $oldVersion++;
    $gl->set_int('composite_manager/version', $oldVersion);

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

    EBox::debug('cached: ' . $self->{version});
    EBox::debug('gconf: ' . $self->_version());
    EBox::debug('pid: ' . $$);

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

    return $gl->get_int('composite_manager/version');

}

1;
