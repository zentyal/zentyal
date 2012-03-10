# Copyright (C) 2008-2012 eBox Technologies S.L.
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

# Class: Manager
#
#   This class is used to coordinate all the available models and composites
#   along Zentyal. It allows us to do things like specifiying relations
#   amongst different models.
#
#
#
package EBox::Model::Manager;

use strict;
use warnings;

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataInUse;
use Error qw(:try);

# Constant
use constant MAX_INT => 32767;

# Singleton variable
my $_instance = undef;

sub _new
{
    my $class = shift;

    my $self = {};

    # TODO: differentiate between RO and RW instances
    $self->{models} = {};
    $self->{composites} = {};

    $self->{'notifyActions'} = {};
    $self->{'reloadActions'} = {};
    $self->{'hasOneReverse'} = {};

    bless($self, $class);

    $self->_setUp();

# FIXME: implement this
#    $self->_setRelationship();

    return $self;
}

# Method: instance
#
#   Return a singleton instance of class <EBox::Model::Manager>
#
#
# Returns:
#
#   object of class <EBox::Model::Manager>
#
sub instance
{
    unless(defined($_instance)) {
        $_instance = EBox::Model::Manager->_new();
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

    unless ($path) {
        throw EBox::Exceptions::MissingArgument(q{model's path});
    }

    my ($moduleName, $modelName, @parameters) = grep { $_ ne '' } split ( '/', $path);

    if (not $moduleName) {
        throw EBox::Exceptions::Internal('Invalid path');
    }

    if ((not $modelName) and $path =~ m:/:) {
        throw EBox::Exceptions::Internal('One element is given and ' .
                                         'slashes are given. The valid format ' .
                                         'requires no slashes, sorry');
    }

    unless (defined ($modelName)) {
        $modelName = $moduleName;
        # Infer the module name
        $moduleName = $self->_inferModuleFromModel($modelName);
    }

    # FIXME: RW/RO
    my $module = EBox::Global->modInstance($moduleName);
    return $self->_model($module, $modelName);
}

sub models
{
    my ($self, $module) = @_;

    my $name = $module->{name};
    return [ map { $self->_model($module, $_) } keys %{$self->{models}->{$name}} ];
}

sub _model
{
    my ($self, $module, $modelName) = @_;

    my $moduleName = $module->{name};
    unless (exists $self->{models}->{$moduleName}->{$modelName}) {
        # Second try as a report model
        $modelName = "Report::$modelName";
        unless (exists $self->{models}->{$moduleName}->{$modelName}) {
            throw EBox::Exceptions::DataNotFound(data  => 'model',
                                                 value => $modelName);
        }
    }

    unless (defined $self->{models}->{$moduleName}->{$modelName}) {
        # FIXME: parameters logic currently disabled
        #if (@parameters and $parameters[0] ne '*') {
        #    # There are at least one parameter
        #    return $self->_chooseModelUsingParameters($path);
        #} else {
        #    my $nModels = @{$self->{'models'}->{$moduleName}->{$modelName}};
        #    if ((@parameters and $parameters[0] eq '*') or $nModels > 1) {
        #        return $self->{'models'}->{$moduleName}->{$modelName};
        #    } else {
        #        return
        #            $self->{'models'}->{$moduleName}->{$modelName}->[0];
        #    }
        #}

        my $global = EBox::Global->getInstance();

        my $class = $global->_className($moduleName) . '::Model::' . $modelName;
        eval "use $class";
        $self->{models}->{$moduleName}->{$modelName} = $class->new(confmodule => $module,
                                                                   directory => $modelName);
    }

    return $self->{models}->{$moduleName}->{$modelName};
}

# FIXME: check if this is really needed, it is only used in TS and logs
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
                $models{$modelDepName} = $modelDep->table()->{'printableTableName'};
            }
        }
    }

    # Fetch dependencies from models which are not declaring dependencies
    # in types and instead they are using notifyActions
    if (exists $self->{'notifyActions'}->{$modelName}) {
        foreach my $observer (@{$self->{'notifyActions'}->{$modelName}}) {
            my $observerModel = $self->model($observer);
            if ($observerModel->isUsingId($modelName, $rowId)) {
                $models{$observer} = $observerModel->printableContextName();
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
#   model - <EBox::Model::DataTable> model name where the action took place
#   action - string represting the action:
#	     [ add, del, edit, moveUp, moveDown ]
#
#   row  - <EBox::Model::Row> row modified
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

    throw EBox::Exceptions::MissingArgument('model') unless (defined($model));
    throw EBox::Exceptions::MissingArgument('action') unless (defined($action));
    throw EBox::Exceptions::MissingArgument('row') unless (defined($row));

    my $strToRet = '';
    for my $observerName (@{$self->{'notifyActions'}->{$model}}) {
        EBox::debug("Notifying $observerName");
        my $observerModel = $self->model($observerName);
        $strToRet .= $observerModel->notifyForeignModelAction($model, $action, $row) .  '<br>';
        # FIXME: integrate this
        # my $observerComposite = $self->composite($observerName);
        # $strToRet .= $observerComposite->notifyModelAction($model, $action, $row) .  '<br>';
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
            for my $id (@{$modelDep->findAllValue($fieldName => $rowId)}) {
                next if (exists $rowsDeleted{$id});
                $modelDep->removeRow($id, 1);
                $deletedNum++;
                $rowsDeleted{$id} = 1;
            }
        }
        if ($deletedNum > 0) {
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

# Group: Private methods

sub _setUp
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    foreach my $moduleName (@{$global->modNames()}) {
        my $info = $global->readModInfo($moduleName);
        my %models = map { $_ => undef } @{$info->{models}};
        $self->{models}->{$moduleName} = \%models;
        my %composites = map { $_ => undef } @{$info->{composites}};
        $self->{composites}->{$moduleName} = \%composites;
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
        my $parent       = $self->{'childOf'}->{$childName}->{'parent'};
        my $childIsComposite = $self->{'childOf'}->{$childName}->{'childIsComposite'};

        my $child;
        if ($childIsComposite) {
            $child = $self->composite($childName);
        } else {
            $child = $self->model($childName);
        }

        $child->setParent($parent);
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

    for my $model (@{$provider->models()}) {
        my $moduleName = $provider->name();
        my $modelName = $model->tableName();
        $modelName or
            throw EBox::Exceptions::Internal("Invalid model name $modelName");

        push (@{$self->{'models'}->{$moduleName}->{$modelName}}, $model);
    }
    for my $model (@{$provider->reloadModelsOnChange()}) {
        push (@{$self->{'reloadActions'}->{$model}}, $provider->name());
    }

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
                my $isComposite;
                try {
                    $foreignModel = $type->foreignModel();
                    $isComposite  = $type->foreignModelIsComposite();
                } otherwise {
                    my ($exc) = @_;
                    EBox::warn("Skipping " . $type->fieldName() . " to fetch model");
                    EBox::warn("Error: $exc");
                };
                next unless (defined($foreignModel) and $foreignModel ne '');

                $self->{'childOf'}->{$foreignModel} = {
                    parent => $model,
                    childIsComposite => $isComposite,
                };
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
#	(PRIVATE)
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
        my $typeName = $type->type();
        if ($typeName eq 'union') {
            for my $subtype (@{$type->subtypes()}) {
                my $subtypeName = $subtype->type();
                if ($subtypeName eq 'select') {
                    push (@selectTypes, $subtype);
                } elsif ($subtypeName eq 'hasMany') {
                    push (@hasManyTypes, $subtype);
                }
            }
        } elsif ($typeName eq 'select') {
            push (@selectTypes, $type);
        } elsif ($typeName eq 'hasMany') {
            push (@hasManyTypes, $type);
        }
    }

    return { 'select' => \@selectTypes,
             'hasMany' => \@hasManyTypes };
}

# Method: _oneToOneDependencies
#
#	(PRIVATE)
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
#	model name => field name which references
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
#	(PRIVATE)
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

    unless (defined ($returningModule)) {
        # XXX We use this for flow control. It's wrong, in the meantime
        #     we set the exception as silent
        throw EBox::Exceptions::DataNotFound(data => 'compositeName',
                                             value => $compName,
                                             silent => 1);
    }

    return $returningModule;
}


# Method: _chooseModelUsingParameters
#
#	(PRIVATE)
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

    # Check arguments
    unless (defined ($path)) {
        throw EBox::Exceptions::MissingArgument('composite');
    }

    my ($moduleName, $compName, @indexes) = grep { $_ ne '' } split ( '/', $path);
    if (not defined ($compName) and $path =~ m:/:) {
        throw EBox::Exceptions::Internal('One composite element is given and '
                                         . 'slashes are given. The valid format '
                                         . 'requires no slashes');
    }

    unless (defined ($compName)) {
        $compName = $moduleName;
        # Try to infer the module name from the compName
        $moduleName = $self->_inferModuleFromComposite($compName);
    }

    # FIXME: RW/RO
    my $module = EBox::Global->modInstance($moduleName);
    return $self->_composite($module, $compName);
}

sub composites
{
    my ($self, $module) = @_;

    my $name = $module->{name};
    return [ map { $self->_composite($module, $_) } keys %{$self->{composites}->{$name}} ];
}

sub _composite
{
    my ($self, $module, $compName) = @_;

    my $moduleName = $module->{name};
    unless (exists $self->{composites}->{$moduleName}->{$compName}) {
        # Second try as a report composite
        $compName = "Report::$compName";
        unless (exists $self->{composites}->{$moduleName}->{$compName}) {
            throw EBox::Exceptions::DataNotFound(data  => 'composite',
                                                 value => $compName,
                                                 silent => 1);
        }
    }

    unless (defined $self->{composites}->{$moduleName}->{$compName}) {
        # FIXME: indexes logic currently disabled
        # if (@indexes > 0 and $indexes[0] ne '*') {
        #    # There are at least one index
        #    return $self->_chooseCompositeUsingIndex($moduleName, $compName, \@indexes);
        # } else {
        #    if (@{$self->{composites}->{$moduleName}->{$compName}} == 1) {
        #        return $self->{composites}->{$moduleName}->{$compName}->[0];
        #    } else {
        #        return $self->{composites}->{$moduleName}->{$compName};
        #    }
        # }

        my $global = EBox::Global->getInstance();

        my $class = $global->_className($moduleName) . '::Composite::' . $compName;
        eval "use $class";
        $self->{composites}->{$moduleName}->{$compName} = $class->new(confmodule => $module);
    }

    return $self->{composites}->{$moduleName}->{$compName};
}

# Method: removeComposite
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

    unless (defined ($moduleName) and defined ($compositeName)) {
        throw EBox::Exceptions::Internal("Path bad formed $compositePath, "
                                         . 'it should follow the pattern /modName/compName[/index]');
    }

    my $composites = $self->{composites}->{$moduleName}->{$compositeName};
    if (@indexes > 0) {
        for my $idx (0 .. $#$composites) {
            my $composite = $composites->[$idx];
            if ( $composite->index() eq $indexes[0] ) {
                splice ( @{$composites}, $idx, 1 );
                last;
            }
        }
    } else {
        delete ($self->{composites}->{$moduleName}->{$compositeName});
    }
}

# FIXME: see if this is really needed after the changes
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
                                        . join ('/', @{$indexesRef}),
                                         silent => 1);
}


1;
