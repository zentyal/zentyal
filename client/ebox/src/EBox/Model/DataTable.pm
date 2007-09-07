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

package EBox::Model::DataTable;

use EBox::Model::ModelManager;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::NotImplemented;

use Error qw(:try);
use POSIX qw(ceil);
use Clone qw(clone);

use strict;
use warnings;

# TODO
# 	
#	Factor findValue, find, findAll and findAllValue
#
#	Use callback for selectOptions
#	
# 	Fix issue with menu and generic controllers
#
#	Fix issue with values and printableValues fetched
#	from foreing tables


#
# Caching:
# 	
# 	To speed up the process of returning rows, the access to the
# 	data stored in gconf is now cached. To keep data coherence amongst
# 	the several apache processes, we add a mark in the gconf structure
# 	whenever a write operation takes place. This mark is fetched by
# 	a process returning its rows, if it has changed then it has
# 	a old copy, otherwise its cached data can be returned.
#
# 	Note that this caching process is very basic. Next step could be
# 	caching at row level, and keeping coherence at that level, modifying
# 	just the affected rows in the memory stored structure.
#

sub new
{
        my $class = shift;
        my %opts = @_;
        my $gconfmodule = delete $opts{'gconfmodule'};
	my $directory = delete $opts{'directory'};
	my $domain = delete $opts{'domain'};

        my $self =
		{
			'gconfmodule' => $gconfmodule,
			'gconfdir' => $directory,
			'directory' => "$directory/keys",
			'order' => "$directory/order",
		        'table' => undef,
			'cachedVersion' => undef,
			'domain' => $domain,
			'pageSize' => 10
		};

        bless($self, $class);

        return $self;
}

# Method: table
#
#       Get the table description. It must NOT be overrided.
#
# Returns:
#
#       hash ref with the table description
#
sub table
  {

    my ($self) = @_;

    # It's a singleton method
    unless( defined( $self->{'table'} ) ){
      $self->_setDomain();
      $self->{'table'} = $self->_table();
      $self->_restoreDomain();
      # Set the needed controller and undef setters
      $self->_setControllers();
      # This is useful for submodels
      $self->{'table'}->{'gconfdir'} = $self->{'gconfdir'};
      # Make fields accessible by their names
      for my $field (@{$self->{'table'}->{'tableDescription'}}) {
      	my $name = $field->fieldName();
	$self->{'table'}->{'tableDescriptionByName'}->{$name} = $field;
      }
      # Some default values
      unless (defined($self->{'table'}->{'class'})) {
	$self->{'table'}->{'class'} = 'dataTable';
      }
      $self->_setDefaultMessages();
    }

    return $self->{'table'};

  }


# Method: _table
#
#	Override this method to describe your table.
#       This method is (PROTECTED)
#
# Returns:
#
# 	table description. See example on <EBox::Network::Model::GatewayDataTable::_table>.
#
sub _table
{

	throw EBox::Exceptions::NotImplemented();

}

# Method: modelName 
#
#	Return the model name which is set by the key 'tableName' when
#	a model table is described
#
# Returns:
#
#	string containing the model name
#
sub modelName
{
	my ($self) = @_;
	return $self->table()->{'tableName'};
}

# Method: name
#
#       Return the same that <EBox::Model::DataTable::modelName>
#
sub name
  {

      my ($self) = @_;

      return $self->modelName();

  }

# Method: fieldHeader 
#
#	Return the instanced type of a given header field
#
# Arguments:
#
# 	fieldName - field's name
#
# Returns:
#
#	instance of a type derivated of <EBox::Types::Abstract>
sub fieldHeader
{
	my ($self, $name) = @_;

	unless (defined($name)) {
		throw EBox::Exceptions::MissingArgument(
					"field's name")
	}

	unless (exists ($self->table()->{'tableDescriptionByName'}->{$name})) {
          	throw EBox::Exceptions::DataNotFound( data => __('field'),
                                                value => $name);
	}

	return $self->table()->{'tableDescriptionByName'}->{$name};
}

# Method: optionsFromForeignModel 
#
#	This method is used to fetch an array of hashes containing
#	pairs of value and printableValue.
#
#	It's a convenience method to be used by <EBox::Types::Select> types
#	when using foreing modules.
#
#	It's implemented here, because it has to do some caching
#	due to performance reasons.
#
# Arguments:
#
# 	field - field's name  
#
# Returns:
#
#	Array ref of hashes containing:
#		
#	value - row's id
#	printableValue - field's printableValue
#
#	Example:
#	[{ 'value' => 'obj001', 'printableValue' => 'administration'}]
sub optionsFromForeignModel 
{
	my ($self, $field) = @_;
	
	unless (defined($field)) {
		throw EBox::Exceptions::MissingArgument("field's name")
	}
	
	my $cache = $self->{'optionsCache'};
	if ($self->_isOptionsCacheDirty($field)) {
		EBox::debug("cache is dirty");
		my @options;
		for my $row (@{$self->printableValueRows()}) {
			push (@options, {
					'value' => $row->{'id'},
					'printableValue' => $row->{$field}
					});
		}
		$cache->{$field}->{'values'} = \@options;
		$cache->{$field}->{'cachedVersion'} = $self->_cachedVersion();
	}

	return $cache->{$field}->{'values'};
}


# Method: selectOptions
#
#	Override this method to return your select options
#	for the given select
#
# Arguments:
#
# 	select - select's name
#
# Returns:
#
#	Array ref containing hash ref with value, printable
#	value and selected status
#
#	example:
#
#	[ 
#	  { value => '1', printableValue => '1'},
#         { value => '2', printableValue => '2'} 
#	]
sub selectOptions 
{
	
	throw EBox::Exceptions::NotImplemented();
	
}

# Method: validateRow
#
#	Override this method to add your custom checks for
#	the table fields. The parameters are passed just like they are
#	received from the CGI. If you want to check on typed data use
#	<EBox::Model::DataTable::validateTypedRow> instead.
#
#	It will be called whenever a row is added/updated.
#
# Arguments:
#
#       action - String containing the action to be performed
#                after validating this row.
#                Current options: 'add', 'update'
# 	params - hash ref containing fields names and their values
#
# Returns:
#
#	Nothing
#
# Exceptions:
#
# 	You must throw an exception whenever a field value does not
# 	fulfill your requirements
#
sub validateRow
{

}

# Method: validateTypedRow
#
#	Override this method to add your custom checks for
#	the table fields. The parameters are passed like data types.
#
#	It will be called whenever a row is added/updated
#
# Arguments:
#
#       action - String containing the action to be performed
#                after validating this row.
#                Current options: 'add', 'update'
#
# 	params - hash ref containing the typed parameters subclassing
# 	from <EBox::Types::Abstract> , the key will be the field's name
#
# Returns:
#
#	Nothing
#
# Exceptions:
#
# 	You must throw an exception whenever a field value does not
# 	fulfill your requirements
#
sub validateTypedRow
{

}

# Method: addedRowNotify
#	
#	Override this method to be notified whenever
#	a new row is added
#
# Arguments:
#
# 	hash containing fields and values of the new row
#
sub addedRowNotify 
{

}

# Method: deletedRowNotify
#	
#	Override this method to be notified whenever
#	a new row is deleted 
#
# Arguments:
#
# 	hash containing fields and values of the deleted row
#
sub deletedRowNotify 
{

}

# Method: movedUpRowNotify
#	
#	Override this method to be notified whenever
#	a  row is moved up 
#
# Arguments:
#
# 	hash containing fields and values of the moved row
#
sub movedUpRowNotify 
{

}

# Method: movedDownRowNotify
#	
#	Override this method to be notified whenever
#	a  row is moved down
#
# Arguments:
#
# 	hash containing fields and values of the moved row
#
sub movedDownRowNotify 
{

}

# Method: updatedDownRowNotify
#	
#	Override this method to be notified whenever
#	a  row is updated 
#
# Arguments:
#
# 	hash containing fields and values of the moved row
#
sub updatedRowNotify 
{

}

# Method: notifyForeignModelAction 
#	
#	This method is used to let models know when other model has
#	taken an action.
#
#	To be notified your table description must contain:
#	an entry 'notifyAction' => [ ModelName1, ModelName2]
#	where ModelName is the model you are interested of receiving
#	notifications.
#
#	If you are interested on some action on a module you should
#	override this method to take the actions you need on response to
#	the foreign module action
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
sub notifyForeingModelAction 
{

}

# Method: addRow
#
#	Add a new row 
#
# Parameters:
#
#	named parameters containing the expected fields for each row
#
# Returns:
#
#   just added row's id
sub addRow
{
	my $self = shift;
	my %params = @_;

	my $tableName = $self->tableName();
	my $dir = $self->{'directory'};
	my $gconfmod = $self->{'gconfmodule'};

	$self->validateRow('add', @_);

	my @userData;
	my $userData;
	foreach my $type (@{$self->table()->{'tableDescription'}}) {
		my $data = clone($type);
		$data->setMemValue(\%params);

		if ($data->unique()) {
			$self->_checkFieldIsUnique($data);
		}

		push (@userData, $data);
		$userData->{$data->fieldName()} = $data;
	}

	$self->validateTypedRow('add', $userData);

	# Check if the new row is unique
	if ( $self->rowUnique() ) {
	  $self->_checkRowIsUnique(undef, \@userData);
	}

	my $leadingText = substr( $tableName, 0, 4);
	# Changing text to be lowercase
	$leadingText = "\L$leadingText";

	my $id;
	if (exists ($params{'id'}) and length ($params{'id'}) > 0) {
		$id = $params{'id'};
	 } else {
	 	$id = $gconfmod->get_unique_id( $leadingText, $dir);
	 }

	foreach my $data (@userData) {
		$data->storeInGConf($gconfmod, "$dir/$id");
		$data = undef;
    }

	if ($self->table()->{'order'}) {
		$self->_insertPos($id, 0);
	}

#	my $row = {};
#	$row->{'id'} = $id;
#	$row->{'order'} = $self->_rowOrder($id);
#	$row->{'values'} = \@userData;

	$gconfmod->set_bool("$dir/$id/readOnly", $params{'readOnly'});

        $self->setMessage($self->message('add'));
	$self->addedRowNotify($self->row($id));
	$self->_notifyModelManager('add', $self->row($id));
	
	$self->_setCacheDirty();

	return $id;
}

# Method: row
#
#	Return a given row
#
# Parameters:
#
# 	id - row id
#
# Returns:
#
#	Hash reference containing:
#
#		- 'id' =>  row id
#		- 'order' => row order
#		- 'values' => array ref containing objects
#			    implementing <EBox::Types::Abstract> interface
#       - 'valueHash' => hash ref containing the same objects as
#          'values' but indexed by 'fieldName'
#
#       - 'plainValueHash' => hash ref containing the fields and their
#          value
#
#       - 'printableValueHash' => hash ref containing the fields and
#          their printable value
sub row
{
	my ($self, $id)  = @_;
	
	my $dir = $self->{'directory'};
	my $gconfmod = $self->{'gconfmodule'};
	my $row = {};
	
	unless (defined($id)) {
		return undef;
	}

	unless ($gconfmod->dir_exists("$dir/$id")) {
		return undef;
	}


	my @values;
	$self->{'cacheOptions'} = {};
	my $gconfData = $gconfmod->hash_from_dir("$dir/$id");
	$row->{'readOnly'} = $gconfData->{'readOnly'};
	foreach my $type (@{$self->table()->{'tableDescription'}}) {
		my $data = clone($type);
		$data->restoreFromHash($gconfData);
		$data->setRow($row);
		$data->setModel($self);
	
		# TODO Rework the union select options thing
		#      this code just sucks. Modify Types to do something
		#      nicer 
		if ($data->type() eq 'union') {
                    # FIXME: Check if we can avoid this
			$row->{'plainValueHash'}->{$data->selectedType} =
				$data->value();
			$row->{'printableValueHash'}->{$data->selectedType} =
				$data->printableValue();
		}
	
		if ($data->type eq 'hasMany') {
			my $fieldName = $data->fieldName();
			$data->setDirectory("$dir/$id/$fieldName");
		}
		
		push (@values, $data);
		$row->{'valueHash'}->{$type->fieldName()} = $data;
		$row->{'plainValueHash'}->{$type->fieldName()} = $data->value();
		$row->{'plainValueHash'}->{'id'} = $id;
		$row->{'printableValueHash'}->{$type->fieldName()} =
							$data->printableValue();
		$row->{'printableValueHash'}->{'id'} = $id;
	}
	
	$row->{'id'} = $id;
	$row->{'order'} = $self->_rowOrder($id);
	$row->{'values'} = \@values;


	return $row;
}

# Method: isRowReadOnly
#
# 	Given a row it returns if it is read-only or not
#
# Parameters:
# 	(POSITIONAL)
#
# 	id - row's id
#
# Returns:
#
# 	boolean - true if it is read-only, otherwise false
#
sub isRowReadOnly
{
	my ($self, $id) = @_;

	my $row = $self->row($id);
	return undef unless ($row);

	return $row->{'readOnly'};
}

sub _selectOptions
{
	my ($self, $field) = @_;

	my $cached = $self->{'cacheOptions'}->{$field};

	$self->{'cacheOptions'}->{$field} = $self->selectOptions($field);
	return $self->{'cacheOptions'}->{$field};
	
}

sub moveUp
{
	my ($self, $id) = @_;
	
	my %order = $self->_orderHash();

	my $pos = $order{$id};
	if ($order{$id} == 0) {
		return;
	}

	$self->_swapPos($pos, $pos - 1);

        $self->setMessage($self->message('moveUp'));
	$self->movedUpRowNotify($self->row($id));
	$self->_notifyModelManager('moveUp', $self->row($id));
	
}

sub moveDown
{
	my ($self, $id) = @_;
	
	my %order = $self->_orderHash();
	my $numOrder = keys %order;

	my $pos = $order{$id};
	if ($order{$id} == $numOrder -1) {
		return;
	}

	$self->_swapPos($pos, $pos + 1);

        $self->setMessage($self->message('moveDown'));
	$self->movedDownRowNotify($self->row($id));
	$self->_notifyModelManager('moveDown', $self->row($id));
}	

sub _reorderCachedRows
{
	my ($self, $posa, $posb) = @_;


	unless ($self->{'cachedRows'})  {
		return;
	}

	my $storedVersion = $self->_storedVersion();
	if ($self->{'cachedVersion'} + 1  != $storedVersion) {
		return;
	}
	
	my $rows = $self->{'cachedRows'};
	
	my $auxrow = @{$rows}[$posa];
	my $ordera = @{$rows}[$posa]->{'order'};
	$auxrow->{'order'} = @{$rows}[$posb]->{'order'};
	@{$rows}[$posb]->{'order'} = $ordera;
	@{$rows}[$posa] = @{$rows}[$posb];
	@{$rows}[$posb] = $auxrow;

	$self->{'cachedRows'} = $rows;
	$self->{'cachedVersion'} = $storedVersion;
}

# TODO Split into removeRow and removeRowForce
#

# Method: removeRow
#
#	Remove a row
#
# Parameters:
#
#	(POSITIONAL)
#	
# 	'id' - row id
#	'force' - boolean to skip integrations checks of the row to remove
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - throw if any mandatory
#       argument is missing
#
sub removeRow
{
	my ($self, $id, $force) = @_;

	# If force != true and automaticRemove is enabled it means
	# the model has to automatically check if the row which is 
	# about to removed is referenced elsewhere. In that
	# case throw a DataInUse exceptions to iform the user about
	# the effects its actions will have.
	if ((not $force) and $self->table()->{'automaticRemove'}) {
		$self->_warnIfIdIsUsed($id);
		$self->warnIfIdUsed($id);
	}

	unless (defined($id)) {
		throw EBox::Exceptions::MissingArgument(
					"Missing row identifier to remove")
	}
	
	$self->_checkRowExist($id, '');
	my $row = $self->row($id);
	
	# Workaround: It seems that deleting a dir in gconf doesn't work
	# ok sometimes and it keeps available after deleting it for a while.
	# To workaround this issue we mark the row with "removed"
	$self->{'gconfmodule'}->set_bool("$self->{'directory'}/$id/removed", 1);
	
	$self->{'gconfmodule'}->delete_dir("$self->{'directory'}/$id");
	$self->_setCacheDirty();
	


	if ($self->table()->{'order'}) {
		$self->_removeOrderId($id);
	}
	
    $self->setMessage($self->message('del'));
	$self->deletedRowNotify($row);
	$self->_notifyModelManager('del', $row);

	$self->_setCacheDirty();

	# If automaticRemove is enabled then remove all rows using referencing
	# this row in other models
	if ($self->table()->{'automaticRemove'}) {
		my $manager = EBox::Model::ModelManager->instance();
		$manager->removeRowsUsingId($self->table()->{'tableName'}, 
					$id);
	}


}

# Method: warnIfIdUsed 
#
#	This method must be overriden in case you want to warn the user
#	when a row is going to be deleted. Note that models manage this
#	situation automatically, this method is intended for situations
#	where the use of the model is done in a non-standard way.
#
#	Override this method and raise a <EBox::Exceptions::DataInUse>
#	excpetions to warn the user
#
# Parameters:
#
#	(POSITIONAL)
#	
# 	'id' - row id
sub warnIfIdUsed
{

}

# Method: warnOnChangeOnId 
#
#	FIXME
#
# Parameters:
#
#	(POSITIONAL)
#	
# 	'id' - row id
#	'changeData' - array ref of data types which are going to be changed
#
# Returns:
#
# 	A i18ned string explaining what happens if the requested action
# 	takes place
sub warnOnChangeOnId
{

}

# Method: isIdUsed 
#
#	TODO
#
#	(POSITIONAL)
#	
#	'modelName' - model's name
# 	'id' - row id
sub isIdUsed
{

}

# Method: setRow
#
#	Set an existing row 
#
# Parameters:
#
#	named parameters containing the expected fields for each row
sub setRow
{
	my ($self, $force, %params) = @_;

	my $id = delete $params{'id'};
	$self->_checkRowExist($id, '');
	
	my $dir = $self->{'directory'};
	my $gconfmod = $self->{'gconfmodule'};
	
	$self->validateRow('update', @_);
	
	my $oldrow = $self->row($id);
	#my @newValues = @{$self->table()->{'tableDescription'}};
        # We can only set those types which have setters
        my @newValues = @{$self->setterTypes()};

	# Check if the new row is unique
	if ( $self->rowUnique() ) {
	  $self->_checkRowIsUnique($id, \@newValues);
	}

	my @oldValues = @{$oldrow->{'values'}};

	my @changedData;
	my $changedData;
	for (my $i = 0; $i < @newValues ; $i++) {
		my $newData = clone($newValues[$i]);
		$newData->setMemValue(\%params);
		$changedData->{$newData->fieldName()} = $newData;	

		if ($oldValues[$i]->isEqualTo($newData)) {
			next;
		}

		if ($newData->unique()) {
			$self->_checkFieldIsUnique($newData);
		}

		push (@changedData, $newData);
	
	}

	$self->validateTypedRow('update', $changedData);

	# If force != true atomaticRemove is enabled it means
	# the model has to automatically check if the row which is 
	# about to be changed is referenced elsewhere and this change
	# produces an inconsistent state
	 if ((not $force) and $self->table()->{'automaticRemove'}) {
		$self->_warnOnChangeOnId($id, \@changedData);
	}

	my $modified = undef;
	for my $data (@changedData) {
		$data->storeInGConf($gconfmod, "$dir/$id");
		$modified = 1;
	}

	$oldrow->{'values'} = \@newValues;

	if ($modified) {
		$self->_setCacheDirty();
	}

        $self->setMessage($self->message('update'));
	$self->updatedRowNotify($oldrow);

}

sub _storedVersion
{
	my ($self) = @_;
	
	my $gconfmod = $self->{'gconfmodule'};
	my $storedVerKey = $self->{'directory'} . '/version';
	
	return ($gconfmod->get_int($storedVerKey));
}

sub _cachedVersion
{
	my ($self) = @_;
	
	return $self->{'cachedVersion'};
}


# Method: rows
#
# 	Return a list containing the table rows 	
#
# Parameters:
#
# 	filter - string to filter result
# 	
# Returns:
#
#	Array ref containing the rows 
sub rows
{
	my ($self, $filter, $page)  = @_;
	
	# The method which takes care of loading the rows
	# from gconf is _rows(). 
	#
	# rows() tries to cache the data to avoid extra access
	# to gconf
	my $gconfmod = $self->{'gconfmodule'};
	my $storedVersion = $self->_storedVersion();
	my $cachedVersion = $self->_cachedVersion();;

	if (not defined($storedVersion)) {
		$storedVersion = 0;
	}
	
	if (not defined($cachedVersion)) {
		$self->{'cachedRows'} = $self->_rows();
		$self->{'cachedVersion'} = 0;
	} else {
		if ($storedVersion != $cachedVersion) {
			$self->{'cachedRows'} = $self->_rows();
			$self->{'cachedVersion'} = $storedVersion;
		}
	}

	if ( $self->order() == 1) {
	  return $self->_filterRows($self->{'cachedRows'}, $filter, 
	  			$page);
	} else {
	  return $self->_filterRows(
	  			$self->_tailoredOrder($self->{'cachedRows'}),
	  			$filter, $page);
	}
}

# Method: printableValueRows
#
# 	Return a list containing the table rows and the printable value
# 	of every field
#
# Returns:
#
#	Array ref containing the rows 
sub printableValueRows 
{
	my $self = shift;

	my @hasManyFields;
   	foreach my $type (@{$self->table()->{'tableDescription'}}) {
		if ($type->type() eq 'hasMany') {
	 		push (@hasManyFields, $type->fieldName())
		}
	}
	
	
	my @values = map { $_->{'printableValueHash'} } @{$self->rows()};
	return \@values unless (@hasManyFields > 0);
	
	my $manager = EBox::Model::ModelManager->instance();
	foreach my $row (@values) {
		for my $field (@hasManyFields) {
			next  unless (exists $row->{$field}->{'model'});
			my $model = $manager->model($row->{$field}->{'model'});
			next unless (defined($model));
			my $olddir = $model->directory();
    			$model->setDirectory($row->{$field}->{'directory'});
    			$row->{$field}->{'values'} = 
					$model->printableValueRows();
			$model->setDirectory($olddir);
		}
	}

        return \@values;
}

sub _rows
{
	my $self = shift;
	my $gconfmod = $self->{'gconfmodule'};
	
	my  %order;
	if ($self->table()->{'order'}) {
		my @order = @{$gconfmod->get_list($self->{'order'})};	
		my $i = 0;
		foreach my $id (@order) {
			$order{$id} = $i;
			$i++;
		}
	}
	
	my @rows;
	for my $id (@{$gconfmod->all_dirs_base($self->{'directory'})}) {
		my $hash = $gconfmod->hash_from_dir("$self->{'directory'}/$id");
		# Workaround: It seems that deleting a dir in gconf 
		# doesn't work  ok sometimes and it keeps available after 
		# deleting it for a while.
		# To workaround this issue we skip those rows marked with
		# "removed" key
		next if (exists $hash->{'removed'});
	
		my $row = $self->row($id);
		if (%order) {
			$hash->{'order'} = $order{$id};
			$rows[$order{$id}] = $row;
		} else {
			push(@rows, $row);
		}
	}


	return \@rows;
}

sub _setCacheDirty
{
	my $self = shift;

	my $gconfmod = $self->{'gconfmodule'};
	my $storedVerKey = $self->{'directory'} . '/version';
	my $storedVersion = $gconfmod->get_int($storedVerKey);
	my $newVersion;

	if (defined($storedVersion)) {
		$newVersion = $storedVersion + 1;
	} else {
		$newVersion = 1;
	}

	$gconfmod->set_int($storedVerKey, $newVersion);
}

sub _increaseStoredAndCachedVersion
{
	my $self = shift;

	my $gconfmod = $self->{'gconfmodule'};
	my $storedVerKey = $self->{'directory'} . '/version';
	my $storedVersion = $gconfmod->get_int($storedVerKey);
	my $newVersion;

	if (defined($storedVersion)) {
		$newVersion = $storedVersion + 1;
	} else {
		$newVersion = 1;
	}

	$gconfmod->set_int($storedVerKey, $newVersion);
	$self->{'cachedVersion'} = $newVersion;
}

# Method: _tailoredOrder
#
#       Function to be overriden by the subclasses in order to do
#       ordering in a different way as normal order is done.  It's
#       functional if only if <EBox::Model::DataTable::order> is set
#       to 1.
#
# Parameters:
#
#       rows - an array ref with the hashes with the rows to order
#
# Returns:
#
#       an array ref with the order from the current model with a
#       hash ref of every row
#
sub _tailoredOrder # (rows)
  {
	return $_[1];
	
  }


# Method: setTableName
#
#	Use this method to set the current table name. This method
#	comes in handy to manage several tables with same model
#
# Parameters:
#
# 	tablename - string containing the name
#
sub setTableName
{
	my ($self, $name) = @_;

	unless ($name) {
		throw Exceptions::MissingArgument('name');
	}

	$self->{'tablename'} = $name;

	
}

# Method: setDirectory
#
#	Use this method to set the current directory. This method
#	comes in handy to manage several tables with same model
#
# Parameters:
#
# 	directory - string containing the name
#
sub setDirectory
{
	my ($self, $dir) = @_;

	unless ($dir) {
		throw EBox::Exceptions::MissingArgument('dir');
	}

	my $olddir = $self->{'gconfdir'};
	return if ($dir eq $olddir);
	
	# If there's a directory change we try to keep cached the last
	# directory as it is likely we are asked again for it
	my $cachePerDir = $self->{'cachePerDirectory'};
	$cachePerDir->{$olddir}->{'cachedRows'} = $self->{'cachedRows'};
	$cachePerDir->{$olddir}->{'cachedVersion'} = $self->{'cachedVersion'};

	if ($cachePerDir->{$dir}) {
		$self->{'cachedRows'} = $cachePerDir->{$dir}->{'cachedRows'};
		$self->{'cachedVersion'} =
					$cachePerDir->{$dir}->{'cachedVersion'};
	} else {
		$self->{'cachedRows'} = undef;
		$self->{'cachedVersion'} = undef;
	}

	$self->{'gconfdir'} = $dir;
	$self->{'directory'} = "$dir/keys";
	$self->{'order'} = "$dir/order";
	$self->{'table'}->{'gconfdir'} = $dir;

}

# Method: tableName
#
#        Get the table name associated to this model
#
# Returns:
#
#        String - containing the table name
#
sub tableName
  {

    my ($self) = @_;

    return $self->table()->{'tableName'};

  }

# Method: printableModelName
#
#       Get the i18ned model name
#
# Returns:
#
#       String - the localisated model name
#
sub printableModelName
  {

      my ($self) = @_;

      return $self->table()->{'printableTableName'};

  }

# Method: printableName
#
#       Get the i18ned name
#
# Returns:
#
#       What <EBox::Model::DataTable::printableModelName> returns
#
sub printableName
  {

      my ($self) = @_;

      return $self->printableModelName();

  }

# Method: directory
#
#        Get the current directory. This method is handy to manage
#        several tables with the same model
#
# Returns:
#
#        String - Containing the directory
#
sub directory
  {

    my ($self) = @_;

    return $self->{'gconfdir'};

  }


# Method: menuNamespace 
#
#	Fetch the menu namespace which this model belongs to
#
# Returns:
#
#        String - Containing namespace 
#
sub menuNamespace 
{
	my ($self) = @_;


	if (exists $self->table()->{'menuNamespace'}) {
            return $self->table()->{'menuNamespace'};
	} elsif ( defined ( $self->modelDomain() )) {
            # This is autogenerated menuNamespace got from the model
            # domain and the table name
            return $self->modelDomain() . '/View/' . $self->tableName();
        } else {
            return undef;
	}
}

# Method: order
#
#     Get the keys order in an array ref
#
# Returns:
#
#     array ref - the key order where each element is the key
#     identifier
#
sub order
  {

    my ($self) = @_;

    return $self->{'gconfmodule'}->get_list( $self->{'order'} );

  }

# Method: rowUnique
#
#     Get if the model must have each row different
#
# Returns:
#
#     true  - if each row is unique
#     false - otherwise
#
sub rowUnique
  {

    my ($self) = @_;

    return $self->table()->{'rowUnique'};

  }

# Method: action
#
#       Accessor to the URLs where the actions are published to be
#       run.
#
# Parameters:
#
#       actionName - String the action name
#
# Returns:
#
#       String - URL where the action will be called
#
# Exceptions:
#
#       <EBox::Exceptions::DataNotFound> - thrown if the action name
#       has not defined action
#
sub action
  {

      my ($self, $actionName) = @_;

      my $actionsRef = $self->table()->{actions};

      if ( exists ($actionsRef->{$actionName}) ){
          return $actionsRef->{$actionName};
      } else {
          throw EBox::Exceptions::DataNotFound( data => __('Action'),
                                                value => $actionName);
      }

  }

# Method: printableRowName
#
#     Get the printable row name
#
# Returns:
#
#     String - containing the i18n name for the row
#
sub printableRowName
  {

    my ($self) = @_;

    return $self->table()->{'printableRowName'};

  }

# Method: help
#
#     Get the help message from the model
#
# Returns:
#
#     String - containing the i18n help message
#
sub help
  {

    my ($self) = @_;

    return $self->table()->{'help'};

  }

# Method: message
#
#     Get a message depending on the action parameter
#
#     Current actions are:
#
#      add - when a row is added
#      del - when a row is deleted
#      update - when a row is updated
#      moveUp - when a row is moved up
#      moveDown - when a row is moved down
#
# Parameters:
#
#     action - String the action from where to get the message. There
#     are one default message per action. If the action is undef
#     returns the current message to show. *(Optional)* Default value:
#     undef
#
# Returns:
#
#     String - the message to show
#
sub message
  {
      my ($self, $action) = @_;

      if ( defined ( $action ) ) {
          return $self->table()->{'messages'}->{$action};
      } else {
          return $self->table()->{'message'};
      }

  }

# Method: popMessage
#
#     Get the message to show and *delete* it afterwards.
#
# Returns:
#
#     String - the message to show
#
sub popMessage
  {
      my ($self, $action) = @_;

      my $msg = $self->message();
      $self->setMessage('');

      return $msg;

  }


# Method: setMessage
#
#     Set the message to show the user
#
# Parameters:
#
#     newMessage - String the new message to show
#
sub setMessage
  {

      my ($self, $newMessage) = @_;

      $self->table()->{'message'} = $newMessage;

  }

# Method: modelDomain
#
#     Get the domain where the model is handled. That is, the eBox
#     module which the model belongs to
#
# Returns:
#
#     String - the model domain, the first letter is upper-case
#
sub modelDomain
  {

      my ($self) = @_;

      return $self->table()->{'modelDomain'};

  }

# Method: tableInfo
#
# 	Return the table info.
#
# Returns:
#
# 	Hash ref containing the table info
#
sub tableInfo
{
	my $self = shift;

	my $table = $self->table();
	my @parameters;

#	foreach my $data (@{$table->{'tableDescription'}}) {
#
#		push (@parameters, $data->fields());

#		if ($data->type() eq 'union') {
#			foreach my $subtype (@{$data->subtypes()}) {
#				next unless ($subtype->type() eq 'select');
#				$subtype->addOptions(
#					$self->selectOptions(
#						$subtype->fieldName()));	
#
#			}
#		}
#		if ($data->type() eq 'select') {
#			$data->addOptions(
#				$self->selectOptions($data->fieldName()));	
#		}

#	}

	# Add default actions to actions
#	my $defAction = $table->{'defaultController'};
#	if ($defAction) {
#		foreach my $action (@{$table->{'defaultActions'}}) {
#			$table->{'actions'}->{$action} = $defAction;
#		}
#	}
#

#	my $fieldsWithOutSetter = $self->fieldsWithUndefSetter();
#	my @paramsWithSetter = grep {!$fieldsWithOutSetter->{$_}} @parameters;
#	push (@paramsWithSetter, 'filter', 'page');
#	my $paramsArray = '[' . "'" . pop(@paramsWithSetter) . "'";
#	foreach my $param (@paramsWithSetter) {
#		$paramsArray .= ', ' . "'" . $param . "'";
#	}
#	$paramsArray .= ']';

#	$table->{'gconfdir'} = $self->{'gconfdir'};
#	$table->{'paramArrayString'} = $paramsArray;

	return $table;
}

# Method: fields 
#
# 	Return a list containing the fields which compose each row	
#
# Returns:
#
#	Array ref containing the fields
sub fields
{
	my $self = shift;

	if ($self->{'fields'}) {
		return $self->{'fields'};
	}
	
	unless (defined($self->table()->{'tableDescription'})) {
		throw EBox::Exceptions::Internal('Table description not defined');
	}
	
	my @tableHead = @{$self->table()->{'tableDescription'}};
	my @tableFields = map { $_->{'fieldName'} } @tableHead;

	$self->{'fields'} = \@tableFields;
	
	return \@tableFields;
}

# Method: fieldsWithUndefSetter
#
# 	Return a hash containing the fields which compose each row	
#	and dont have a defined Setter
#
# Returns:
#
#	Hash ref containing the field names as keys
#
sub fieldsWithUndefSetter
{
	my $self = shift;

	if ($self->{'fields'}) {
		return $self->{'fields'};
	}
	
	unless (defined($self->table()->{'tableDescription'})) {
		throw Excepetions::Internal('table description not defined');
	}
	
	my @tableHead = @{$self->table()->{'tableDescription'}};
	my %tableFields;
	for my $type (@tableHead) {
		$tableFields{$type->fieldName()} = 1 unless $type->HTMLSetter();
	}
	
	return \%tableFields;
}

# Method: setterTypes 
#
# 	Return a list containing those fields which have defined setters 
#
# Returns:
#
#	Array ref containing the fields
sub setterTypes
{
	my ($self) = @_ ;

	if ($self->{'fields'}) {
		return $self->{'fields'};
	}
	
	unless (defined($self->table()->{'tableDescription'})) {
		throw Excepetions::Internal('table description not defined');
	}
	
	my @tableHead = @{$self->table()->{'tableDescription'}};
	my @types =  grep { defined($_->HTMLSetter) } @tableHead;

	return \@types;
}

# Method: setFilter
#
# 	Set the the string used to filter the return of rows
#
# Parameters:
#	(POSITIONAL)
#	filter - string containing the filter
#
sub setFilter
{
	my ($self, $filter) = @_;
	$self->{'filter'} = $filter;
}

# Method: filter
#
#	Return the string used to filter the return of rows
#
# Returns:
#
#	string - containing the value
sub filter
{
	my ($self) = @_;
	return $self->{'filter'};
}  

# Method: pages 
#
#	Return the number of pages
#
# Parameters:
#
# 	$rows - hash ref containing the rows, if undef it will use
# 		those returned by rows()
# Returns:
#
#	integer - containing the value
sub pages 
{
	my ($self, $filter) = @_;
	
	my $pageSize = $self->pageSize();
	unless (defined($pageSize)) {
		return 1;
	}

	my $rows = $self->rows($filter);
	
	my $nrows = @{$rows};
	EBox::debug("nrows $nrows");
	
	if ($nrows == 0) {
		return 0;
	} else {
		return  ceil($nrows / $pageSize) - 1;
	}

}

# Method: find
#
#	Return the first row which matches the value of the given
#	field against the data returned by the method printableValue()
#
#	If you want to match against value use
#	<EBox::Model::DataTable::findValue>
#
# Parameters:
#
# 	fieldName => value
#
# 	Example:
#
# 	find('default' => 1);
#
# Returns:
#
# 	Hash ref containing the printable values of the matched row 
#	
#	undef if there was not any match
# 	
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub find
{
    my ($self, $fieldName, $value) = @_;
	
    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, undef, 1)};

    if (@matched) {
        return $matched[0];
    } else {
        return undef;
    }
}

# Method: findAll
#
#	Return all the rows which matches the value of the given
#	field against the data returned by the method printableValue()
#
#	If you want to match against value use
#	<EBox::Model::DataTable::findValue>
#
# Parameters:
#
# 	fieldName => value
#
# 	Example:
#
# 	find('default' => 1);
#
# Returns:
#
# 	Array ref of hash refs  containing the printable 
# 	values of the matched row 
# 	
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub findAll
{
    my ($self, $fieldName, $value) = @_;
	
    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, 1, 1)};

    return \@matched;

}

# Method: findValue
#
#	Return the first row which matches the value of the given
#	field against the data returned by the method value()
#
#	If you want to match against value use
#	<EBox::Model::DataTable::find>
# Parameters:
#
# 	fieldName => value
#
# 	Example:
#
# 	find('default' => 1);
#
# Returns:
#
# 	Hash ref containing the printable values of the matched row 
#	
#	undef if there was not any match
# 	
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub findValue
{
    my ($self, $fieldName, $value) = @_;
	
    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, undef, undef)};

    if (@matched) {
        return $matched[0];
    } else {
        return undef;
    }
}

# Method: findAll
#
#	Return all the rows which matches the value of the given
#	field against the data returned by the method value()
#
#	If you want to match against value use
#	<EBox::Model::DataTable::find>
#
#
# Parameters:
#
# 	fieldName => value
#
# 	Example:
#
# 	find('default' => 1);
#
# Returns:
#
# 	Array ref of hash refs  containing the printable 
# 	values of the matched row 
# 	
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
sub findAllValue
{
    my ($self, $fieldName, $value) = @_;
	
    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my @matched = @{$self->_find($fieldName, $value, 1, undef)};

    return \@matched;

}

# Method: Viewer
#
#       Class method to return the viewer from this model. This method
#       can be overriden
#
# Returns:
#
#       String - the path to the Mason template which acts as the
#       viewer from this kind of model.
#
sub Viewer
  {

      return '/ajax/tableBody.mas';

  }

# Method: pageSize
# 	
# 	Return the number of rows per page
#
# Returns:
#	
#	int - page size
sub pageSize
{
	my ($self) = @_;

	return $self->{'pageSize'}
}

# Method: setPageSize
# 	
# 	set the number of rows per page
#
# Parameters:
#
# 	rows - number of rows per page
# 	
# Returns:
#	
#	int - page size
sub setPageSize
{
	my ($self, $rows) = @_;
	
	unless (defined ($rows)) {
		throw EBox::Exceptions::MissingArgument("Missing field rows"); 
	}

	$self->{'pageSize'} = $rows;
	
}

# Method: changeViewJS
#
# 	Return the javascript function to change view to
# 	add a row
#
# Parameters:
#
#	(NAMED)
#	changeType - changeAdd or changeList	
#	editId - edit id
# 	page - page number
#       isFilter - boolean indicating if comes from filtering
#
#
# Returns:
#
# 	string - holding a javascript funcion
sub changeViewJS
{
	my ($self, %args) = @_;

        my ($type, $editId, $page, $isFilter) = ($args{changeType},
                                                 $args{editId},
                                                 $args{page},
                                                 $args{isFilter},
                                                );
	
	my  $function = 'changeView("%s", "%s", "%s", "%s",'.
			'"%s", %s, %s)';

	my $table = $self->table();
	return  sprintf ($function, 
			 $table->{'actions'}->{'changeView'},
			 $table->{'tableName'},
			 $table->{'gconfdir'},
			 $type,
			 $editId,
			 $page,
                         $isFilter
                        );
}

# Method: addNewRowJS
#
# 	Return the javascript function for addNewRow
#
# Parameters:
#	
#	(POSITIONAL)
# 	page - page number
#
# Returns:
#
# 	string - holding a javascript funcion
sub addNewRowJS
{
	my ($self, $page) = @_;
	
	my  $function = 'addNewRow("%s", "%s", %s, "%s",'.
			'undefined, %s)';

	my $table = $self->table();
	my $fields = $self->_paramsWithSetterJS();
	$fields =~ s/'/\"/g;
	return  sprintf ($function, 
			 $table->{'actions'}->{'add'},
			 $table->{'tableName'},
			 $fields,
			 $table->{'gconfdir'},
			 $page);
}

# Method: changeRow 
#
# 	Return the javascript function for changeRow 
#
# Parameters:
#	
#	(POSITIONAL)
#	editId - row id to edit
# 	page - page number
#
# Returns:
#
# 	string - holding a javascript funcion
sub changeRowJS
{
	my ($self, $editId, $page) = @_;
	
	my  $function = 'changeRow("%s", "%s", %s, "%s",'.
			'"%s", %s)';

	my $table = $self->table();
	my $fields = $self->_paramsWithSetterJS();
	$fields =~ s/'/\"/g;
	return  sprintf ($function, 
			 $table->{'actions'}->{'editField'},
			 $table->{'tableName'},
			 $fields,
			 $table->{'gconfdir'},
			 $editId,
			 $page);
}

# Method: actionClicked 
#
# 	Return the javascript function for actionClicked
#
# Parameters:
#	
#	(POSITIONAL)
#	action - move or del
#	editId - row id to edit
#	direction - up or down
# 	page - page number
#
# Returns:
#
# 	string - holding a javascript funcion
sub actionClickedJS
{
	my ($self, $action, $editId, $direction, $page) = @_;
	
	unless ($action eq 'move' or $action eq 'del') {
		throw EBox::Exceptions::External("Wrong action $action");
	}
	
	if ($action eq 'move' 
	    and not ($direction eq 'up' or $direction eq 'down')) {
		
		throw EBox::Exceptions::External("Wrong action $direction");
	}
	
	my  $function = 'actionClicked("%s", "%s", "%s", "%s",'.
			'"%s", "%s", %s)';

	if ($direction) {
		$direction = "dir=$direction";
	} else {
		$direction = "";
	}	

	my $table = $self->table();
	my $fields = $self->_paramsWithSetterJS();
	$fields =~ s/'/\"/g;
	return  sprintf ($function, 
			 $table->{'actions'}->{$action},
			 $table->{'tableName'},
			 $action,
			 $editId,
			 $direction,
			 $table->{'gconfdir'},
			 $page);
}

# Group: Protected methods

# Method: _setDefaultMessages
#
#      Set the default messages done by possible actions
#
sub _setDefaultMessages
  {

      my ($self) = @_;

      # Table is already defined
      my $table = $self->{'table'};

      $table->{'messages'} = {} unless ( $table->{'messages'} );
      my $rowName = $self->printableRowName();

      my %defaultMessages =
        (
         'add'       => __x('{row} added', row => $rowName),
         'del'       => __x('{row} deleted', row => $rowName),
         'update'    => __x('{row} updated', row => $rowName),
         'moveUp'    => __x('{row} moved up', row => $rowName),
         'moveDown'  => __x('{row} moved down', row => $rowName),
        );

      foreach my $action (keys (%defaultMessages)) {
          unless ( exists $table->{'messages'}->{$action} ) {
              $table->{'messages'}->{$action} = $defaultMessages{$action};
          }
      }


  }

# Group: Private helper functions

# Method: _find
#
#	(PRIVATE)
#	
#	Used by find and findAll to find rows in a table	
#
# Parameters:
#
#	(POSITIONAL)
#	
#	fieldName - the name of the field to match
#	value - value we want to match
#	allMatches -   1 or undef to tell the method to return just the
#		first match or all of them
#
#	printableValue - if 1 match against printableValue, undef against value
# 	Example:
#
# 	find('default',  1, undef);
#
# Returns:
#
#	An array of hash ref containing the rows with their printable
#	values
# 	
sub _find 
{
    my ($self, $fieldName, $value, $allMatches, $printableValue) = @_;

    unless (defined ($fieldName)) {
        throw EBox::Exceptions::MissingArgument("Missing field name"); 
    }

    my $rows = $self->rows();

    my @matched;
    foreach my $row (@{$rows}) {
    	my $values;
	if ($printableValue) {
        	$values = $row->{'printableValueHash'};  
	} else {
		$values = $row->{'plainValueHash'};
	}
        next unless (exists $values->{$fieldName});
        next unless ($values->{$fieldName} eq $value);
        push (@matched, $values);
        return (\@matched) unless ($allMatches);
    }

    return \@matched;
}

sub _checkFieldIsUnique
{
	my ($self, $newData) = @_;


	my $gconfmod = $self->{'gconfmodule'};
	my $dir = $self->{'directory'};

	unless ($gconfmod->dir_exists($dir)) {
		return 0;
	}

	my @ids = $gconfmod->all_dirs($dir);

	foreach my $id (@ids) {
		my $hash = $gconfmod->hash_from_dir($id);

		if ($newData->compareToHash($hash))  {
			throw EBox::Exceptions::DataExists(
					'data' => $newData->printableName(),
					'value' => $newData->printableValue());

		}
	}

	return 0;
}

# Check the new row to add/set is unique
# rowId can be undef if the call comes from an addition
# An array ref of types is passing in
# throw <EBox::Exceptions::DataExists> if not unique
sub _checkRowIsUnique # (rowId, row_ref)
  {

    my ($self, $rowId, $row_ref) = @_;

    my $rowIds_ref = $self->{'gconfmodule'}->all_dirs_base($self->{'directory'});

    foreach my $aRowId (@{$rowIds_ref}) {
      # Compare if the row identifier is different
      next if (defined ($rowId)) and ($aRowId eq $rowId);

      my $hash = $self->{'gconfmodule'}->hash_from_dir($self->{'directory'} . '/' . $aRowId);
      # Check every field
      my $equal = 'equal';
      foreach my $field (@{$row_ref}) {
	next if ($field->compareToHash($hash));
	$equal = undef;
	last;
      }
      if ($equal) {
	throw EBox::Exceptions::DataExists(
					   'data'  => $self->printableRowName(),
					   'value' => ''
					  );
      }
    }

  }



sub _checkAllFieldsExist
{
	my ($self, $params) = @_;

	my $types = $self->table()->{'tableDescription'};

	foreach my $field (@{$types}) {

		unless ($field->paramExist($params)) {
			throw
			 Exceptions::MissingArgument($field->printableName());
		}
	}
}

sub _checkRowExist
{
	my ($self, $id, $text) = @_;

	my $gconfmod = $self->{'gconfmodule'};
	my $dir = $self->{'directory'};

	unless ($gconfmod->dir_exists("$dir/$id")) {
		throw EBox::Exceptions::DataNotFound(
				data => $text,
				value => $id);
	}
}

sub _insertPos
{
	my ($self, $id, $pos) = @_;

	my $gconfmod = $self->{'gconfmodule'};

	my @order = @{$gconfmod->get_list($self->{'order'})};

	if (@order == 0) {
		push (@order, $id);
	} elsif ($pos == 0) {
		@order = ($id, @order);
	} elsif ($pos == (@order - 1)) {
		push (@order, $id);
	} else {
		splice (@order, $pos, 1, ($id, $order[$pos]));
	}

	
	$gconfmod->set_list($self->{'order'}, 'string', \@order);
}

sub _removeOrderId
{
	my ($self, $id) = @_;

	my $gconfmod = $self->{'gconfmodule'};
	my @order = @{$gconfmod->get_list($self->{'order'})};

	@order = grep (!/$id/, @order);
	
	$gconfmod->set_list($self->{'order'}, 'string', \@order);
}

sub _swapPos
{
	my ($self, $posA, $posB ) = @_;

	my $gconfmod = $self->{'gconfmodule'};
	my @order = @{$gconfmod->get_list($self->{'order'})};

	my $temp = $order[$posA];
	$order[$posA] =  $order[$posB];
	$order[$posB] = $temp;
	
	$gconfmod->set_list($self->{'order'}, 'string', \@order);
	$self->_setCacheDirty();
	$self->_reorderCachedRows($posA, $posB);
}

sub _orderHash
{
	my $self = shift;
	my $gconfmod = $self->{'gconfmodule'};
	
	my  %order;
	if ($self->table()->{'order'}) {
		my @order = @{$gconfmod->get_list($self->{'order'})};	
		my $i = 0;
		foreach my $id (@order) {
			$order{$id} = $i;
			$i++;
		}
	}

	return %order;

}

sub _rowOrder
{
	my ($self, $id) = @_;
	
	unless (defined($id)) {
		return;
	}

	my %order = $self->_orderHash();

	return $order{$id};
}

sub _hashFromDir
{
	my ($self, $id) = @_;

	my $gconfmod = $self->{'gconfmodule'};
	my $dir = $self->{'directory'};

	unless (defined($id)) {
		return;
	}

	my $row = $gconfmod->hash_from_dir("$dir/$id");
	$row->{'id'} = $id;
	$row->{'order'} = $self->_rowOrder($id);

	return $row;
}

sub _removeHasManyTables
{
	my ($self, $id) = @_;
	
	foreach my $type (@{$self->table()->{'tableDescription'}}) {
		my $dir = "$id/" . $type->fieldName();
		next unless ($self->{'gconfmodule'}->dir_exists($dir));
		$self->{'gconfmodule'}->delete_dir("$id/$dir");
	}

}

# FIXME This method must be in ModelManager
sub _warnIfIdIsUsed
{
	my ($self, $id) = @_;
	
	my $manager = EBox::Model::ModelManager->instance();
	my $modelName = $self->modelName();
	my $tablesUsing;
	
	for my $name  (values %{$manager->modelsUsingId($modelName, $id)}) {
		$tablesUsing .= '<br> - ' .  $name ;
	}

	if ($tablesUsing) {
		throw EBox::Exceptions::DataInUse(
			__('The data you are removing is being used by
			the following tables:') . '<br>' . $tablesUsing);
	}
}

# FIXME This method must be in ModelManager
sub _warnOnChangeOnId 
{
	my ($self, $id, $changeData) = @_;
	
	my $manager = EBox::Model::ModelManager->instance();
	my $modelName = $self->modelName();
	my $tablesUsing;
	
	for my $name  (keys %{$manager->modelsUsingId($modelName, $id)}) {
		my $model = $manager->model($name);
		my $issue = $model->warnOnChangeOnId($id, $changeData);
		if ($issue) {
			$tablesUsing .= '<br> - ' .  $issue ;
		}
	}

	if ($tablesUsing) {
		throw EBox::Exceptions::DataInUse(
			__('The data you are modifying is being used by
			the following tables:') . '<br>' . $tablesUsing);
	}
}

# Method: _setDomain
#
# 	Set the translation domain to the one stored in the model, if any
sub _setDomain
{
	my ($self) = @_;

	my $domain = $self->{'domain'};
	if ($domain) {
		$self->{'oldDomain'} = settextdomain($domain);
	}
}

# Method: _restoreDomain
#
# 	Restore the translation domain privous to _setDomain
sub _restoreDomain
{
	my ($self) = @_;

	my $domain = $self->{'oldDomain'};
	if ($domain) {
		settextdomain($domain);
	}
}

sub _notifyModelManager
{
	my ($self, $action, $row) = @_;

	my $manager = EBox::Model::ModelManager->instance();
	my $modelName = $self->modelName();

	$manager->modelActionTaken($modelName, $action, $row);
}

sub _filterRows
{
	my ($self, $rows, $filter, $page) = @_;

	# Filter using regExp
	my @newRows;
	if (defined($filter) and length($filter) > 0) {
		my @words = split (/\s+/, $filter);
		my $totalWords = scalar(@words);
		for my $row (@{$rows}) {
			my $values = $row->{'printableValueHash'};
			my $nwords = $totalWords;
			my %wordFound;		
			for my $key (keys %{$values}) {
				next if (ref $values->{$key});
				my $rowFound;
				for my $regExp (@words) {
					if (not exists $wordFound{$regExp} 
					    and $values->{$key} =~ /$regExp/) {
						$nwords--;
						$wordFound{$regExp} = 1;
						unless ($nwords) {
							push(@newRows, $row);
							$rowFound = 1;
							last;
						}
					}

				}
				last if $rowFound;
			}
		}
	} else {
		@newRows = @{$rows};
	}
	
	# Paging
	unless (defined($page) and defined($self->pageSize())) {
		return \@newRows;
	}
	

	my $pageSize = $self->pageSize();
	my $tpages;
	if (@newRows == 0) {
		$tpages = 0;
	} else {
		$tpages = ceil(@newRows / $pageSize) - 1;
	}

        if ($page < 0) { $page = 0; }
        if ($page > $tpages) { $page = $tpages; }
	
	
	my $index;
	if ($tpages > 0 and defined($pageSize) and $pageSize > 0) {
		$index = $page * $pageSize;
	} else {
		$index = 0;
		$pageSize = @{$rows} - 1;
	}
	my $offset = $index + $pageSize;
	if ($page == $tpages) {
		$offset = @newRows - 1;
	}
	
	if ($tpages > 0) {
		return [@newRows[$index ..  $offset]];
	} else {
		return \@newRows;
	}
}

# Set the default controller to that actions which do not have a
# custom controller
sub _setControllers
  {

      my ($self) = @_;

      # Table is already defined
      my $table = $self->{'table'};

      my $defAction = $table->{'defaultController'};
      if ( (not defined ( $defAction )) and defined ( $self->modelDomain() )) {
          # If it is not a defaultController, we try to guess it from
          # the model domain and its name
          $defAction = '/ebox/' . $self->modelDomain() . '/Controller/' .
            $self->tableName();
      }
      if ($defAction) {
          foreach my $action (@{$table->{'defaultActions'}}) {
              # Do not overwrite existing actions
              unless ( exists ( $table->{'actions'}->{$action} )) {
                  $table->{'actions'}->{$action} = $defAction;
              }
          }
      }

  }

# Method: _paramsWithSetterJS
#
#      Return the string which defines an array with that parameters
#      which have a setter defined
#
# Returns:
#
#      String - the string ready to print on a JavaScript file
#
sub _paramsWithSetterJS
  {

      my ($self) = @_;

      my $table = $self->table();
      my @parameters;
      foreach my $type ( @{$table->{'tableDescription'}}) {
          push ( @parameters, $type->fields());
      }

      my $fieldsWithOutSetter = $self->fieldsWithUndefSetter();
      my @paramsWithSetter = grep {!$fieldsWithOutSetter->{$_}} @parameters;
      push (@paramsWithSetter, 'filter', 'page');
      my $paramsArray = '[' . "'" . pop(@paramsWithSetter) . "'";
      foreach my $param (@paramsWithSetter) {
          $paramsArray .= ', ' . "'" . $param . "'";
      }
      $paramsArray .= ']';

      return $paramsArray;

  }

# Method: _isOptionsCacheDirty
#
#	Check if the options cache is dirty. In case of being empty
#	we return empty too
#
sub _isOptionsCacheDirty
{
	my ($self, $field) = @_;

	unless (defined($field)) {
		throw EBox::Exceptions::MissingArgument("field's name")
	}
	
	return 1 unless (exists $self->{'optionsCache'}->{$field});
	
	my $cachedVersion = 
		$self->{'optionsCache'}->{$field}->{'cachedVersion'};

	return ($cachedVersion ne $self->_cachedVersion());
}

1;
