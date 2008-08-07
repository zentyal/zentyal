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

# Class: ModelManager
#
#   This class is used to coordinate all the available models 
#   along eBox. It allows us to do things like specifiying relations
#   amongst different models.
#
#
#
package EBox::Model::ModelManager;

use strict;
use warnings;

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use Error qw(:try);

# Constant
use constant MAX_INT => 32767;

# Singleton variable
my $_instance = undef;


sub _new
{
    my $class = shift;

    my $self = {};

    $self->{'notifyActions'} = {}; 
    bless($self, $class);

    $self->{'version'} = $self->_version();
    $self->_setUpModels();
    $self->_setRelationship();

    return $self;
}

# Method: instance
#
#   Return a singleton instance of class <EBox::ModelManager>
#
#
# Returns:
#
#   object of class <EBox::ModelManager>
sub instance
{
    my ($self) = @_;

    unless(defined($_instance)) {
        $_instance = EBox::Model::ModelManager->_new();
    }

    return $_instance;
}

# Method: model
#
#   Return model instance
#
# Parameters:
#
#   (POSITIONAL)
#
#   path - String determines the model's name following this pattern:
#
#          'modelName' - used only if the modelName is unique within
#          eBox framework and no execution parameters are required to
#          its creation
#
#          '/moduleName/modelName[/index1/index2]' - used in
#          new calls and common models which requires a name space and
#          parameters not set on compilation time
#
# Returns:
#
#  An object of type <EBox::Model::DataTable> - if just one model
#  instance is alive
#
#  array ref - containing <EBox::Model::DataTable> instances if more
#  than model corresponds to the given path
#
# Exceptions:
#
#   <EBox::Exceptions::DataNotFound> - thrown if the given path does
#   not correspond with any stored model instance
#
#   <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#   argument is missing
#
#   <EBox::Exceptions::Internal> - thrown if the path argument is
#   bad-formed
#
sub model
{
    my ($self, $path) = @_;


    unless (  $path ) {
        throw EBox::Exceptions::MissingArgument('path');
    }

    my ($moduleName, $modelName, @parameters) = grep { $_ ne '' } split ( '/', $path);
    
    if (not $moduleName) {
        throw EBox::Exceptions::Internal('Invalid path');
    }

    if ( ( not $modelName ) and $path =~ m:/: ) {
        throw EBox::Exceptions::Internal('One element is given and ' .
                                         'slashes are given. The valid format ' .
                                         'requires no slashes, sorry');
    }

    # Re-read from the modules if the model manager has changed

    if ( $self->_hasChanged() ) {
        $self->_setUpModels();
        $self->{'version'} = $self->_version();
        $self->_setRelationship();

    }

    unless ( defined ( $modelName )) {
        $modelName = $moduleName;
        # Infer the module name
        $moduleName = $self->_inferModuleFromModel($modelName);
    }

    if ( exists $self->{'models'}->{$moduleName}->{$modelName} ) {
        if (@parameters and $parameters[0] ne '*') {
            # There are at least one parameter
            return $self->_chooseModelUsingParameters($path);
        } else {
            my $nModels = @{$self->{'models'}->{$moduleName}->{$modelName}};
            if ((@parameters and $parameters[0] eq '*') or $nModels > 1) {
                return $self->{'models'}->{$moduleName}->{$modelName};
            } else {
                return 
                    $self->{'models'}->{$moduleName}->{$modelName}->[0];
            }
        }
    } else {
        throw EBox::Exceptions::DataNotFound( data  => 'model',
                                              value => $path);
    }

}

# Method: addModel
#
#   Add a new model instance to the model manager. It marks the model
#   manager as changed
#
# Parameters:
#
#   path - String the path to index the model within the model manager
#   following this pattern: /moduleName/modelName[/param1/param2...]
#
#   model - <EBox::Model::DataTable> the model instance
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - thrown if the path is not correct
#
sub addModel
{
    my ($self, $path, $model) = @_;

    my ($modName, $modelName, @parameters) = grep { $_ ne '' } split ( '/', $path);

    if ( not defined ($modelName) ) {
        throw EBox::Exceptions::Internal("No valid path $path to add a model");
    }

    push ( @{$self->{'models'}->{$modName}->{$modelName}}, $model);

    $self->markAsChanged();
    $self->{'version'} = $self->_version();

}

# Method: removeModel
#
#   Remove a or some model instances from the model manager. It marks the
#   model manager as changed
#
# Parameters:
#
#   path - String the path to index the model within the model manager
#   following this pattern: /moduleName/modelName[/param1/param2...]
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - thrown if the path is not correct
#
#   <EBox::Exceptions::DataNotFound> - thrown if the given path does
#   not correspond with any model
#
sub removeModel
{

    my ($self, $path) = @_;

    my ($modName, $modelName, @parameters) = grep { $_ ne '' } split ('/', $path);

    if ( not defined ($modelName) ) {
        throw EBox::Exceptions::Internal("No valid path $path to add a model");
    }

    unless ( exists ( $self->{'models'}->{$modName}->{$modelName} )) {
        throw EBox::Exceptions::DataNotFound( data  => 'path',
                                              value => $path);
    }

    my $models = $self->{'models'}->{$modName}->{$modelName};
    if ( @parameters == 0 ) {
        # Delete every model instance with this name
        delete $self->{'models'}->{$modName}->{$modelName};
    } else {
        for my $idx (0 .. $#$models) {
            if ( $models->[$idx]->contextName() eq $path ) {
                splice ( @{$models}, $idx, 1);
                last;
            }
        }
    }

    $self->markAsChanged();
    $self->{'version'} = $self->_version();

}


# Method: modelsUsingId 
#
#   Given a row id of a model, it returns the models which
#   are currently referencing it
#
# Parameters: 
#
#   (POSITIONAL)
#
#   model - model string 
#   rowId - string containing the row's id
#
# Returns:
#
#   
#
# Exceptions:
#
# <EBox::Exceptions::DataNotFound> if the model does not exist
sub modelsUsingId 
{
    my ($self, $modelName, $rowId) =  @_;
    
    my $model = $self->model($modelName);
    unless (defined($model)) {
        throw EBox::Exceptions::DataNotFound(
                'data' => 'model name',
                'value' => $modelName);
    }

    # Fetch dependencies based on types
    my %models;
    my $modelDepHash = $self->_oneToOneDependencies($modelName);

    foreach my $modelDepName (keys %{$modelDepHash}) {
        my $modelDep = $self->model($modelDepName);
        next unless(defined($modelDep));

        for my $fieldName (@{$modelDepHash->{$modelDepName}}) {
            if (defined($modelDep->findValue($fieldName => $rowId))) {
                $models{$modelDepName} = 
                    $modelDep->table()->{'printableTableName'};
            }
        }
    }

    # Fetch dependencies from models which are not declaring dependencies
    # in types and instead they are using notifyActions
    if (exists $self->{'notifyActions'}->{$modelName}) {
        foreach my $observer (@{$self->{'notifyActions'}->{$modelName}}) {
            my $observerModel = $self->model($observer);
            if ($observerModel->isUsingId($modelName, $rowId)) {
                $models{$observer} =
#                    $observerModel->table()->{'printableTableName'};
                  $observerModel->printableContextName();
            }
        }
    }

    return \%models;
}

# Method: modelActionTaken 
#
#	This method is used to let models know when other model has
#	taken an action. 
#
#	It will automatically call the model in which descrption they
#	request to be warned about the current action and model.
#	
#
# Parameters: 
#
#   (POSITIONAL)
#
#   model - model name where the action took place 
#   action - string represting the action: 
#   	     [ add, del, edit, moveUp, moveDown ]
#
#   row  - row modified 
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

    # if ( defined $row->{'id'} ) {
    #    EBox::debug("$model has taken action '$action' on row $row->{'id'}");
    # } else {
    #    EBox::debug("$model has taken action '$action' on row");
    # }
    # return '' unless (exists $self->{'notifyActions'}->{$model});

    my $strToRet = '';
    for my $observerName (@{$self->{'notifyActions'}->{$model}}) {
        EBox::debug("Notifying $observerName");
        my $observerModel = $self->model($observerName);
        $strToRet .= $observerModel->notifyForeignModelAction($model, $action, $row) .
          '<br>';
    }

    if ( exists $self->{'reloadActions'}->{$model} ) {
        $self->markAsChanged();
    }

    return $strToRet;

}

# Method: removeRowsUsingId 
#
#   Given a row id of a model, remove rows from models referencing it 
#
# Parameters: 
#
#   (POSITIONAL)
#
#   model - model object 
#   rowId - string containing the row's id
#
# Returns:
#
#   String - the i18ned string informing about the changes done in
#   other models
#
# Exceptions:
#
# <EBox::Exceptions::DataNotFound> if the model does not exist
sub removeRowsUsingId 
{
    my ($self, $modelName, $rowId) =  @_;

    my $strToShow = '';

    my $model = $self->model($modelName);
    unless (defined($model)) {
        throw EBox::Exceptions::DataNotFound(
                'data' => 'model name',
                'value' => $modelName);
    }

    my $modelDepHash = $self->_oneToOneDependencies($modelName);

    foreach my $modelDepName (keys %{$modelDepHash}) {
        my $modelDep = $self->model($modelDepName);
        next unless(defined($modelDep));

        my $deletedNum = 0;
        for my $fieldName (@{$modelDepHash->{$modelDepName}}) {
            my %rowsDeleted;
            for my $row (@{$modelDep->findAllValue($fieldName => $rowId)}) {
                next if (exists $rowsDeleted{$row->{'id'}});
                $modelDep->removeRow($row->{'id'}, 1);
                $deletedNum++;
                $rowsDeleted{$row->{'id'}} = 1;
            }
        }
        if ( $deletedNum > 0 ) {
            $strToShow .= $modelDep->automaticRemoveMsg($deletedNum);
        }
    }
    while (my ($modelDepName, $fieldName) = each %{$modelDepHash}) {
        my $modelDep = $self->model($modelDepName);
        next unless(defined($modelDep));
    }

    return $strToShow;

}

# Method: warnIfIdIsUsed
#
#       Check from a model if any model is using this row
#
# Parameters:
#
#       modelName - String the model which the action is going to be
#       performed
#
#       id - String the row identifier
#
# Exceptions:
#
#       <EBox::Exceptions::DataInUse> - thrown if the id is used by
#       any other model
#
sub warnIfIdIsUsed
{
    my ($self, $modelName, $id) = @_;

    my $tablesUsing;

    for my $name  (values %{$self->modelsUsingId($modelName, $id)}) {
        $tablesUsing .= '<br> - ' .  $name ;
    }

    if ($tablesUsing) {
        throw EBox::Exceptions::DataInUse(
                __('The data you are removing is being used by
                    the following sections:') . '<br>' . $tablesUsing);
    }
}

# Method: warnOnChangeOnId
#
#       Check from a model if any model is using a row that is
#       changing
#
# Parameters:
#
#       modelName - String the model which the action is going to be
#       performed
#
#       id - String the row identifier
#
#       changedData - hash ref the types that has been changed
#
#       oldRow - hash ref the old row with the content as
#       <EBox::Model::DataTable::row> return value
#
# Exceptions:
#
#       <EBox::Exceptions::DataInUse> - thrown if the id is used by
#       any other model
#
sub warnOnChangeOnId
{

    my ($self, $modelName, $id, $changeData, $oldRow) = @_;

    my $tablesUsing;

    for my $name (keys %{$self->modelsUsingId($modelName, $id)}) {
        my $model = $self->model($name);
        my $issue = $model->warnOnChangeOnId(modelName => $modelName,
                                             id => $id,
                                             changedData => $changeData,
                                             oldRow => $oldRow);
        if ($issue) {
            $tablesUsing .= '<br> - ' .  $issue ;
        }
    }

    if ($tablesUsing) {
        throw EBox::Exceptions::DataInUse(
                  __('The data you are modifying is being used by
			the following sections:') . '<br>' . $tablesUsing);
    }
}

# Method: markAsChanged
#
# 	(PUBLIC)
#
#   Mark the model manager as changed. This is done when a change is
#   done in the models to allow interprocess coherency.
#
sub markAsChanged
{

    my ($self) = @_;

    my $gl = EBox::Global->getInstance();

    my $oldVersion = $self->_version();
    $oldVersion = 0 unless ( defined ( $oldVersion ));
    $oldVersion = ($oldVersion + 1) % MAX_INT;
    $gl->st_set_int('model_manager/version', $oldVersion);

}

# Group: Private methods

# Method: _setUpModels
#
# 	(PRIVATE)
#
# 	Fetch models from all classes implementing the interface
# 	<EBox::Model::ModelProvider> and creates it dependencies.
sub _setUpModels
{
    my ($self) = @_;

    $self->{'models'} = {};
    $self->{'reloadActions'} = {};
    $self->{'notifyActions'} = {};
    $self->{'hasOneReverse'} = {};

    # Fetch models
    my $global = EBox::Global->getInstance();
    my $classStr = 'EBox::Model::ModelProvider';
    my @modules = @{$global->modInstancesOfType($classStr)};
    my %models;
    for my $module (@modules) {
        $self->_setUpModelsFromProvider($module);
    }
}

# Method: _setRelationship
#
#   (PRIVATE)
#
#   Set the relationship between models and submodels
#
sub _setRelationship
{
    my ($self) = @_;

    # Set parent models given by hasMany relationships
    for my $childName (keys %{$self->{'childOf'}}) {
        $self->model($childName)->setParent($self->{'childOf'}->{$childName});
    }


}

# Method: _setUpModelsFromProvider
#
#   (PRIVATE)
#
#    Fetch models from a <EBox::Model::ModelProvider> interface
#    instances and creates its dependencies
#
# Parameters:
#
#    modelProvider - <EBox::Model::ModelProvider> the model provider
#    class
#
sub _setUpModelsFromProvider
{
    my ($self, $provider) = @_;

    try {
        for my $model (@{$provider->models()}) {
	    my $moduleName = $provider->name();
	    my $modelName = $model->tableName();
	    $modelName or 
		throw EBox::Exceptions::Internal("Invalid model name $modelName");

            push ( @{$self->{'models'}->{$moduleName}->{$modelName}}, $model);
        }
        for my $model (@{$provider->reloadModelsOnChange()}) {
            push ( @{$self->{'reloadActions'}->{$model}}, $provider->name());
        }
    } otherwise {
        my ($exc) = @_;
        EBox::warn('Skipping ' . $provider->printableName() . ' to fetch model');
        EBox::warn("Error: $exc");
    };

    # Set up dependencies. Fetch all select types and check if
    # they depend on other model.
    for my $modelKind (keys %{$self->{'models'}->{$provider->name()}}) {
        foreach my $model ( @{$self->{'models'}->{$provider->name()}->{$modelKind}} ) {
            my $tableDesc = $model->table()->{'tableDescription'};
            my $localModelName = $model->contextName();
            my $dependentTypes = $self->_fetchDependentTypes($tableDesc);
            for my $type (@{$dependentTypes->{'select'}}) {
                my $foreignModel;
                try {
                    $foreignModel = $type->foreignModel();
                } otherwise {
                    my ($exc) = @_;
                    EBox::warn("Skipping " . $type->fieldName() . " to fetch model");
                    EBox::warn("Error: $exc");
                };
                next unless (defined($foreignModel));
                my $foreignModelName = $foreignModel->contextName();
                my %currentHasOne =
                  %{$self->_modelsWithHasOneRelation($foreignModelName)};
                push (@{$currentHasOne{$localModelName}}, $type->fieldName());
                $self->{'hasOneReverse'}->{$foreignModelName} = \%currentHasOne;
            }
            for my $type (@{$dependentTypes->{'hasMany'}}) {
                my $foreignModel;
                try {
                    $foreignModel = $type->foreignModel();
                } otherwise {
                    my ($exc) = @_;
                    EBox::warn("Skipping " . $type->fieldName() . " to fetch model");
                    EBox::warn("Error: $exc");
                };
                next unless (defined($foreignModel) and $foreignModel ne '');
                $self->{'childOf'}->{$foreignModel} = $model;
            }

        }
    }

    # Set up action notifications
    foreach my $modelKind ( keys %{$self->{'models'}->{$provider->name()}} ) {
        foreach my $model (@{$self->{'models'}->{$provider->name()}->{$modelKind}}) {
            my $table = $model->table();
            my $observerModel = $model->contextName();
            next unless (exists $table->{'notifyActions'});
            for my $observableModel (@{$table->{'notifyActions'}}) {
                push (@{$self->{'notifyActions'}->{$observableModel}},
                      $observerModel);
            }
        }
    }

}

# Method: _modelsWithHasOneRelation
#
#   (PRIVATE)
#
#   Given a model, it returns which modules have a  "has one" relationship
#
# Parameters:
#
#   (POSITIONAL)
#   modelName - String containing the model context name
#
# Return:
#
#   Hash ref containing the models
sub _modelsWithHasOneRelation
{
    my ($self, $modelName) = @_;
    
    return {} unless (exists($self->{'hasOneReverse'}->{$modelName}));

    return $self->{'hasOneReverse'}->{$modelName};
}


# Method: _fetchDependentTypes
#
# 	(PRIVATE)
#
#   Given a table description it returns  types which depends on other
#   modules. Those are:
#
#       <EBox::Types::Select>
#       <EBox::Types::HasMany>
#
# Parameters:
#
#   (POSITIONAL)
#   
#   tableDescription - ref containing the table description
#   
# Return:
#
#   Array ref containing the types
#
sub _fetchDependentTypes
{
    my ($self, $tableDescription) = @_;

    my @selectTypes;
    my @hasManyTypes;
    foreach my $type (@{$tableDescription}) { 
        if ($type->type() eq 'union') {
            for my $subtype (@{$type->subtypes()}) {
                 if ($subtype->type() eq 'select') {
                    push (@selectTypes, $subtype);
                }
                if ($subtype->type() eq 'hasMany') {
                    push (@hasManyTypes, $subtype);
                }
            }
        } elsif ($type->type() eq 'select') {
            push (@selectTypes, $type);
        } elsif ($type->type() eq 'hasMany') {
            push (@hasManyTypes, $type);
        }
    }
    
    return { 'select' => \@selectTypes,
             'hasMany' => \@hasManyTypes };
}



# Method: _oneToOneDependencies
#
# 	(PRIVATE)
#
#   Given a model, it returns which models depends on it.
#
# Parameters:
#
#   (POSITIONAL)
#   
#   model - model's name 
#   
# Return:
#
#  hash refs containing pairs of:
#
#  	model name => field name which references
#
sub _oneToOneDependencies
{
    my ($self, $model) = @_;

    unless (exists $self->{'hasOneReverse'}->{$model}) {
        return {};    
    }

    return $self->{'hasOneReverse'}->{$model};

}

# Method: _inferModuleFromModel
#
# 	(PRIVATE)
#
#   Given a model, it returns from which module the model belongs
#   to. It will return a value only if one module has the model and no
#   parameters are required. Otherwise an exception will be raised.
#
# Parameters:
#
#   (POSITIONAL)
#
#   modelName - String model's name
#
# Returns:
#
#   An instance of <EBox::Model::DataTable>
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - thrown if the module belogns to
#   more than module
#
#   <EBox::Exceptions::DataNotFound> - thrown if the model's name is
#   not in any module namespace
#
sub _inferModuleFromModel
{

    my ($self, $modelName) = @_;

    my $models = $self->{'models'};
    my $returningModule = undef;
    foreach my $module (keys %{$models}) {
        foreach my $modelKind ( keys %{$models->{$module}} ) {
            if ( $modelKind eq $modelName ) {
                if ( defined ( $returningModule )) {
                    throw EBox::Exceptions::Internal('Cannot infere the module since ' .
                                                     'more than one module has the model. ' .
                                                     "A module namespace is required for $modelName");
                }
                $returningModule = $module;
            }
        }
    }

    unless ( defined ($returningModule) ) {
        throw EBox::Exceptions::DataNotFound( data  => 'modelName',
                                              value => $modelName);
    }

    return $returningModule;

}

# Method: _chooseModelUsingParameters
#
# 	(PRIVATE)
#
#   Given a bunch of model instances, choose one using the given run
#   parameters.
#
# Parameters:
#
#   (POSITIONAL)
#
#   path - String the context name for the model
#
# Returns:
#
#   An instance of <EBox::Model::DataTable>
#
# Exceptions:
#
#   <EBox::Exceptions::DataNotFound> - thrown if it cannot determine which
#   model must be returned by using the given parameters
#
sub _chooseModelUsingParameters
{

    my ($self, $path) = @_;

    my ($moduleName, $modelName) = grep { $_ ne '' } split ( '/', $path);

    my $models = $self->{'models'}->{$moduleName}->{$modelName};

    foreach my $model (@{$models}) {
        if ( $model->contextName() eq $path ) {
            return $model;
        }
    }
    # No coincidence
    throw EBox::Exceptions::DataNotFound(data => 'modelInstance',
                                         value => $path);

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

    my $actualVersionNotDefined = not defined $self->{'version'};
    my $gconfVersionNotDefined  = not defined $self->_version();

    if ($actualVersionNotDefined and $gconfVersionNotDefined) {
        return undef;
    }
    elsif ($actualVersionNotDefined or $gconfVersionNotDefined) {
        return 1;
    }

    return ($self->{'version'} != $self->_version());
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

    return $gl->st_get_int('model_manager/version');

}

1;


