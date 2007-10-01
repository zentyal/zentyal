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

use EBox;
use EBox::Global;
use EBox::Exceptions::DataNotFound;
use Error qw(:try);

use strict;
use warnings;

# Singleton variable
my $_instance = undef;


sub _new
{
    my $class = shift;

    my $self = {};

    $self->{'notifyActions'} = {}; 
    bless($self, $class);

    $self->_setUpModels();

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
#   model - model's name 
#   
# Return:
#
#  An object of type <EBox::Model::DataTable>
#
sub model
{
    my ($self, $model) = @_;

    if (exists $self->{'models'}->{$model}) {
        return $self->{'models'}->{$model};
    } else {
        return undef;
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
                $models{$modelDepName} = 
                    $modelDep->table()->{'printableTableName'};
            }
        }
    }

    # Fetch dependencies from models which are not declaring dependencies
    # in types and instead they are using notifyActions
    if (exists $self->{'notifyActions'}->{$modelName}) {
        foreach my $observer (keys %{$self->{'notifyActions'}->{$modelName}}) {
            my $observerModel = $self->model($observer);
            if ($observerModel->isUsingId($modelName, $rowId)) {
                $models{$observer} = 
                    $observerModel->table()->{'printableTableName'};
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

    return unless (exists $self->{'notifyActions'}->{$model});
    
    for my $observer (@{$self->{'notifyActions'}->{$model}}) {
        EBox::debug("Notifying $observer");
        $model->notifyForeignModelAction($model, $action, $row);
    }

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
# Exceptions:
#
# <EBox::Exceptions::DataNotFound> if the model does not exist
sub removeRowsUsingId 
{
    my ($self, $modelName, $rowId) =  @_;

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

        for my $fieldName (@{$modelDepHash->{$modelDepName}}) {
            my %rowsDeleted;
            for my $row (@{$modelDep->findAllValue($fieldName => $rowId)}) {
                next if (exists $rowsDeleted{$row->{'id'}});
                $modelDep->removeRow($row->{'id'}, 1);
                $rowsDeleted{$row->{'id'}} = 1;
            }
        }
    }
    while (my ($modelDepName, $fieldName) = each %{$modelDepHash}) {
        my $modelDep = $self->model($modelDepName);
        next unless(defined($modelDep));


    }

}

# Private methods

# Method: _setUpModels
#
# 	(PRIVATE)
#
# 	Fetch models from all classes implementing the interface
# 	<EBox::Model::ModelProvider> and creates it dependencies.
sub _setUpModels
{
    my ($self) = @_;

    # Fetch models
    my $global = EBox::Global->getInstance();
    my $classStr = 'EBox::Model::ModelProvider';
    my @modules = @{$global->modInstancesOfType($classStr)};
    my %models; 
    for my $module (@modules) {
        try {
            for my $model (@{$module->models()}) {
                $models{$model->table()->{'tableName'}} = $model;
            }
        } otherwise {
            EBox::warn("Skipping $module to fetch model");
        };
    }

    # Set up dependencies. Fetch all select types and check if
    # they depend on other model. 
    for my $model (keys %models) {
    	my $tableDesc = $models{$model}->table()->{'tableDescription'};
    	my $localModelName = $models{$model}->table()->{'tableName'};
        for my $type (@{$self->_fetchSelectTypes($tableDesc)}) {
            my $foreignModel;
            try {
                $foreignModel = $type->foreignModel();
            } otherwise {
                EBox::warn("Skipping " . $type->fieldName . " to fetch model");
            };
            next unless (defined($foreignModel));
            my $foreignModelName = $foreignModel->table()->{'tableName'};
            my %currentHasOne =
                    %{$self->_modelsWithHasOneRelation($foreignModelName)};
	    push (@{$currentHasOne{$localModelName}}, $type->fieldName());
            $self->{'hasOneReverse'}->{$foreignModelName} = \%currentHasOne; 
        }
    }

    # Set up action notifications
    for my $model (keys %models) {
        my $table = $models{$model}->table();
        my $observerModel = $table->{'tableName'};
        next unless (exists $table->{'notifyActions'});
        for my $observableModel  (@{$table->{'notifyActions'}}) {
            push (@{$self->{'notifyActions'}->{$observableModel}},
                $observerModel)
        }
    }

    use Data::Dumper;
    EBox::debug("notify actions: \n" . Dumper($self->{'notifyAction'}));
    $self->{'models'} = \%models;
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
#   model - string containing the model
#
# Return:
#
#   Hash ref containing the models
sub _modelsWithHasOneRelation
{
    my ($self, $model) = @_;
    
    return {} unless (exists($self->{'hasOneReverse'}->{$model}));

    return $self->{'hasOneReverse'}->{$model};
}


# Method: _fetchSelectTypes
#
# 	(PRIVATE)
#
#   Given a table description it returns all its types which are
#   <EBox::Types::Select>
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
sub _fetchSelectTypes
{
    my ($self, $tableDescription) = @_;

    my @selectTypes;
    foreach my $type (@{$tableDescription}) { 
        if ($type->type() eq 'union') {
            for my $subtype (@{$type->subtypes()}) {
                push (@selectTypes, $subtype) if ($subtype->type() eq 'select');
            }
        } elsif ($type->type() eq 'select') {
            push (@selectTypes, $type);
        }
    }
    
    return \@selectTypes;
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

1;


