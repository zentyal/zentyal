# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

#   This class is used to coordinate all the available models and composites
#   along Zentyal. It allows us to do things like specifiying relations
#   amongst different models.

package EBox::Model::Manager;

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::MissingArgument;
use TryCatch;

# Constant
use constant MAX_INT => 32767;

# Singleton variable
my $_instance = undef;

sub _new
{
    my $class = shift;

    my $self = {};

    $self->{models} = {};
    $self->{composites} = {};
    $self->{foreign} = {};

    $self->{modByModel} = {};
    $self->{modByComposite} = {};
    $self->{parentByComponent} = {};

    $self->{notifyActions} = {};
    $self->{revModelDeps} = {};

    bless($self, $class);

    $self->_setupInfo();

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
    unless (defined ($_instance)) {
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
    my ($self, $path, $readonly) = @_;

    return $self->_componentByPath('model', $path, $readonly);
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
    my ($self, $path, $readonly) = @_;

    return $self->_componentByPath('composite', $path, $readonly);
}

# Method: component
#
#     Given a component name it returns an instance of this component
#     No need to specify if it's a model or a composite
#
sub component
{
    my ($self, $path, $readonly) = @_;

    if ($self->_modelExists($path)) {
        return $self->model($path, $readonly);
    } elsif ($self->_compositeExists($path)) {
        return $self->composite($path, $readonly);
    } else {
        throw EBox::Exceptions::Internal("Component $path does not exist");
    }
}

# Method: componentExists
#
#     Check if a model or composite exists
#
sub componentExists
{
    my ($self, $path) = @_;

    return ($self->_modelExists($path) or $self->_compositeExists($path));
}

sub models
{
    my ($self, $module) = @_;

    return $self->_components('model', $module);
}

sub composites
{
    my ($self, $module) = @_;

    return $self->_components('composite', $module);
}

sub _components
{
    my ($self, $kind, $module) = @_;

    my $name = $module->{name};
    return [ map { $self->_component($kind, $module, $_) } keys %{$self->{"${kind}s"}->{$name}} ];
}

sub _componentByPath
{
    my ($self, $kind, $path, $readonly) = @_;

    # Check arguments
    unless (defined ($path)) {
        throw EBox::Exceptions::MissingArgument('component');
    }

    my ($moduleName, $compName, @other) = grep { $_ ne '' } split ( '/', $path);
    if (@other) {
        throw EBox::Exceptions::DataNotFound(data => $kind, value => $path, silent => 1);
    }
    if (not defined ($compName) and $path =~ m:/:) {
        throw EBox::Exceptions::Internal("Component name can't contain slashes, valid formats are: 'component' or 'module/component'");
    }

    unless (defined ($compName)) {
        $compName = $moduleName;
        # Try to infer the module name from the compName
        my $key = 'modBy' . ucfirst($kind);
        unless (defined ($self->{$key}->{$compName})) {
            throw EBox::Exceptions::DataNotFound(data  => $kind, value => $compName, silent => 1);
        }
        my @modules = keys %{$self->{$key}->{$compName}};
        if (@modules == 1) {
            $moduleName = $modules[0];
        } else {
            throw EBox::Exceptions::Internal("Can't guess module because $compName belongs to more than one module (@modules)");
        }
    }

    my $module = EBox::Global->getInstance($readonly)->modInstance($moduleName);
    return $self->_component($kind, $module, $compName);
}

sub _component
{
    my ($self, $kind, $module, $name) = @_;

    my $key = "${kind}s";
    my $moduleName = $module->{name};
    my $access = $module->{ro} ? 'ro' : 'rw';

    unless ($self->{knownModules}->{$moduleName}) {
        $self->_setupInfo();
    }

    unless (exists $self->{$key}->{$moduleName}->{$name}) {
        throw EBox::Exceptions::DataNotFound(data  => $kind, value => $name, silent => 1);
    }

    unless (defined $self->{$key}->{$moduleName}->{$name}->{instance}->{$access}) {
        my $global = EBox::Global->getInstance();

        my $class = $global->_className($moduleName) . '::' . ucfirst($kind) . "::$name";
        eval "use $class";
        if ($@) {
            throw EBox::Exceptions::Internal("Error loading $class: $@");
        }

        my $parent = undef;
        my $parentName = $self->{parentByComponent}->{$moduleName}->{$name};
        if ($parentName) {
            $parent = $self->component("$moduleName/$parentName");
        }

        my %params = (confmodule => $module, parent => $parent, directory => $name);
        my $instance = $class->new(%params);

        if ($kind eq 'composite') {
            my $components = $self->{composites}->{$moduleName}->{$name}->{components};
            unless (@{$components}) {
                $components = $instance->componentNames();
            }
            my @instances;
            foreach my $cname (@{$components}) {
                unless ($cname =~ m{/}) {
                    $cname = "$moduleName/$cname";
                }
                my $component = $self->component($cname, $module->{ro});
                push (@instances, $component);
            }
            $instance->{components} = \@instances;
        }

        $self->{$key}->{$moduleName}->{$name}->{instance}->{$access} = $instance;
    }

    return $self->{$key}->{$moduleName}->{$name}->{instance}->{$access};
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
    $modelName =~ s{^/}{};
    $modelName =~ s{/$}{};
    if (exists $self->{'notifyActions'}->{$modelName}) {
        foreach my $observer (@{$self->{'notifyActions'}->{$modelName}}) {
            my $observerModel = $self->model($observer);
            if ($observerModel->isIdUsed($modelName, $rowId)) {
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
#   model -  model name, with module path, where the action took place
#   action - string represting the action:
#	     [ add, del, edit ]
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
        my $observerModel = $self->model($observerName);
        my @confDirs = @{ $self->configDirsForModel($observerModel) };
        foreach my $dir (@confDirs) {
            $observerModel->setDirectory($dir);
            my $observerStr = $observerModel->notifyForeignModelAction($model, $action, $row) .  '<br>';
            $strToRet .= $observerStr if $observerStr;
        }
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
#       oldRow - <EBox::Model::Row> the old row
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

# Method: addModel
#
#       Adds an already instanced model to the manager.
#
# Parameters:
#
#       model - instance of the model
#
sub addModel
{
    my ($self, $model) = @_;

    my $module = $model->parentModule();
    my $moduleName = $module->name();
    my $modelName = $model->modelName();
    unless (exists $self->{models}->{$moduleName}->{$modelName}) {
        $self->{models}->{$moduleName}->{$modelName} = { instance => { rw => undef, ro => undef }, parent => undef };
    }
    if ($module->isReadOnly()) {
        $self->{models}->{$moduleName}->{$modelName}->{instance}->{ro} = $model;
    } else {
        $self->{models}->{$moduleName}->{$modelName}->{instance}->{rw} = $model;
    }
    $self->{modByModel}->{$modelName}->{$moduleName} = 1;
}

# Method: removeModel
#
#       Remove a model from the manager
#
# Parameters:
#
#       module - name of the module
#       model  - name of the model
#
sub removeModel
{
    my ($self, $module, $model) = @_;

    delete $self->{models}->{$module}->{$model};
    delete $self->{modByModel}->{$model}->{$module};
}

# Group: Private methods

sub _setupInfo
{
    my ($self) = @_;

    my $global = EBox::Global->instance();
    my @modNames = @{$global->modNames()};
    my %knownModules = map { $_ => 1 } @modNames;
    $self->{knownModules} = \%knownModules;

    foreach my $moduleName (@modNames) {
        my $info = $global->readModInfo($moduleName);
        $self->_setupModelInfo($moduleName, $info);
        $self->_setupCompositeInfo($moduleName, $info);
        $self->_setupForeignInfo($moduleName, $info);
        $self->_setupModelDepends($moduleName, $info);
        $self->_setupNotifyActions($moduleName, $info);
    }
}

sub _setupModelInfo
{
    my ($self, $moduleName, $info) = @_;

    return unless exists $info->{models};

    $self->{models}->{$moduleName} = {};
    foreach my $model (@{$info->{models}}) {
        $self->{models}->{$moduleName}->{$model} = { instance => { rw => undef, ro => undef }, parent => undef };

        unless (exists $self->{modByModel}->{$model}) {
            $self->{modByModel}->{$model} = {};
        }
        $self->{modByModel}->{$model}->{$moduleName} = 1;
    }
}

sub _setupCompositeInfo
{
    my ($self, $moduleName, $info) = @_;

    return unless exists $info->{composites};

    $self->{composites}->{$moduleName} = {};
    foreach my $composite (keys %{$info->{composites}}) {
        my $components = $info->{composites}->{$composite};
        $self->{composites}->{$moduleName}->{$composite} = { instance => undef, components => $components};
    }

    foreach my $composite (keys %{$info->{composites}}) {
        my $components = $info->{composites}->{$composite};
        foreach my $component (@{$components}) {
            if (exists $self->{models}->{$moduleName}->{$component}) {
                $self->{models}->{$moduleName}->{$component}->{parent} = $composite;
            } elsif (exists $self->{composites}->{$moduleName}->{$component}) {
                $self->{composites}->{$moduleName}->{$component}->{parent} = $composite;
            }
        }

        unless (exists $self->{modByComposite}->{$composite}) {
            $self->{modByComposite}->{$composite} = {};
        }
        $self->{modByComposite}->{$composite}->{$moduleName} = 1;
    }
}

sub _setupForeignInfo
{
    my ($self, $moduleName, $info) = @_;

    return unless exists $info->{foreign};

    $self->{foreign}->{$moduleName} = {};
    foreach my $component (keys %{$info->{foreign}}) {
        my $foreings = $info->{foreign}->{$component};
        $self->{foreign}->{$moduleName}->{$component} = $foreings;

        foreach my $foreign (@{$foreings}) {
            $self->{parentByComponent}->{$moduleName}->{$foreign} = $component;
        }
    }
}

sub _setupModelDepends
{
    my ($self, $moduleName, $info) = @_;

    my $depends = $info->{modeldepends};
    foreach my $model (keys %{$depends}) {
        my $fullPath = $moduleName . '/' . $model;
        my $modelDeps = $depends->{$model};
        foreach my $modelDep (keys %{$modelDeps}) {
            my $deps = $modelDeps->{$modelDep};
            unless (exists $self->{revModelDeps}->{$modelDep}) {
                $self->{revModelDeps}->{$modelDep} = {};
            }
            $self->{revModelDeps}->{$modelDep}->{$fullPath} = $deps;
        }
    }
}

sub _setupNotifyActions
{
    my ($self, $moduleName, $info) = @_;

    my $notify = $info->{notifyactions};
    foreach my $model (keys %{$notify}) {
        my $observerPath = '/' . $moduleName . '/' . $model . '/';
        foreach my $notifier (@{ $notify->{$model} }) {
            # XXX change when we change the yaml to the more intuitive notifier
            # - >watcher format
            if (not exists $self->{notifyActions}->{$notifier}) {
                $self->{notifyActions}->{$notifier} = [];
            }

            push @{ $self->{notifyActions}->{$notifier} }, $observerPath;
        }

#        $self->{notifyActions}->{$contextName} = $notify->{$model};
    }
}

sub _modelExists
{
    my ($self, $model) = @_;

    my ($mod, $comp) = split ('/', $model);
    if ($comp and $self->{modByModel}->{$comp}->{$mod}) {
        return 1;
    } else {
        $comp = $mod;
        foreach my $module (keys %{$self->{modByModel}}) {
            if ($self->{modByModel}->{$comp}->{$module}) {
                return 1;
            }
        }
    }
    return 0;
}

sub _compositeExists
{
    my ($self, $composite) = @_;

    my ($mod, $comp) = split ('/', $composite);
    if ($comp and $self->{modByComposite}->{$comp}->{$mod}) {
        return 1;
    } else {
        $comp = $mod;
        foreach my $module (keys %{$self->{modByComposite}}) {
            if ($self->{modByComposite}->{$comp}->{$module}) {
                return 1;
            }
        }
    }
    return 0;
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

    $model =~ s{^/}{};
    $model =~ s{/$}{};

    unless (exists $self->{revModelDeps}->{$model}) {
        return {};
    }

    return $self->{revModelDeps}->{$model};
}

# FIXME: Is this needed?
sub markAsChanged
{
}

sub _modelHasMultipleInstances
{
    my ($self, $module, $component) = @_;

    while ($component) {
        if (exists $self->{parentByComponent}->{$module}->{$component}) {
            return 1;
        }

        if (exists $self->{models}->{$module}->{$component}
            or exists $self->{composites}->{$module}->{$component}->{parent}) {
            if (exists $self->{models}->{$module}->{$component}->{parent}) {
                $component = $self->{models}->{$module}->{$component}->{parent};
            } elsif (exists $self->{composites}->{$module}->{$component}->{parent}) {
                $component = $self->{composites}->{$module}->{$component}->{parent};
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }
}

sub configDirsForModel
{
    my ($self, $model) = @_;
    my $module = $model->parentModule();
    my $modelName = $model->name();

    if (not $self->_modelHasMultipleInstances($module->name(), $modelName)) {
        # no multiple instances, return normal directory
        return [ $model->directory() ];
    }

    my $baseKey = $module->_key('');

    my $pattern = $baseKey . '/*/'. $modelName .  '/*';
    my @matched =  $module->{redis}->_redis_call('keys', $pattern) ;
    if (not @matched) {
        # probably no dirs yet set
        return [];
    }

    my %dirs;
    my $regex = qr{^$baseKey/(.*/$modelName)/};
    foreach my $match (@matched) {
        $match =~ m{$regex};
        $dirs{$1} = 1;
    }

    return [keys %dirs];
}

1;
