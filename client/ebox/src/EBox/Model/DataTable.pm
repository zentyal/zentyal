# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::NotImplemented;

use Clone qw(clone);

use strict;
use warnings;

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

        my $self =
		{
			'gconfmodule' => $gconfmodule,
			'gconfdir' => $directory,
			'directory' => "$directory/keys",
			'order' => "$directory/order",
		        'table' => undef,
			'cachedVersion' => undef
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
      $self->{'table'} = $self->_table();
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
#	the table fields. It will be called whenever a row
#	is added/updated
#
# Arguments:
#
# 	hash containing fields names and their values	
#
# Returns:
#
#	Nothing
#
# Exceptions:
#
# 	You must throw an excpetion whenever a field value does not
# 	fullfill your requirements
#
sub validateRow
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

# Method: addRow
#
#	Add a new row 
#
# Parameters:
#
#	named parameters containing the expected fields for each row
sub addRow
{
	my $self = shift;
	my %params = @_;

	my $tableName = $self->table()->{'tableName'};
	my $dir = $self->{'directory'};
	my $gconfmod = $self->{'gconfmodule'};

	$self->validateRow(@_);

	my @userData;
	foreach my $type (@{$self->table()->{'tableDescription'}}) {
		my $data = clone($type);
		$data->setMemValue(\%params);

		if ($data->unique()) {
			$self->_checkFieldIsUnique($data);
		}

		push (@userData, $data);

	}

	# Check if the new row is unique
	if ( $self->rowUnique() ) {
	  $self->_checkRowIsUnique(undef, \@userData);
	}

	my $leadingText = substr( $self->table()->{'tablename'}, 0, 4);
	# Changing text to be lowercase
	$leadingText = "\L$leadingText";

	my $id = $gconfmod->get_unique_id(
					  $leadingText,
					  $dir
					 );

	foreach my $data (@userData) {
		$data->storeInGconf($gconfmod, "$dir/$id");
	      }

	if ($self->table()->{'order'}) {
		$self->_insertPos($id, 0);
	}

#	my $row = {};
#	$row->{'id'} = $id;
#	$row->{'order'} = $self->_rowOrder($id);
#	$row->{'values'} = \@userData;

	$self->addedRowNotify($self->row($id));
	
	$self->_increaseStoredVersion();
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
#               - 'valueHash' => hash ref containing the same objects as
#                                'values' but indexed by 'fieldName'
#
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
	foreach my $type (@{$self->table()->{'tableDescription'}}) {
		my $data = clone($type);
		$data->restoreFromHash($gconfData);
	
		# TODO Rework the union select options thing
		#      this code just sucks. Modify Types to do something
		#      nicer 
		if ($data->type() eq 'union') {
			foreach my $subtype (@{$data->subtypes()}) {
				next unless ($subtype->type() eq 'select');
				$subtype->addOptions(
					$self->_selectOptions(
						$subtype->fieldName()));	

			}
		}
		if ($data->type() eq 'select') {
			$data->addOptions(
				$self->_selectOptions($data->fieldName()));	
		}
		
		push (@values, $data);
		$row->{'valueHash'}->{$type->fieldName()} = $data;
	}
	
	$row->{'id'} = $id;
	$row->{'order'} = $self->_rowOrder($id);
	$row->{'values'} = \@values;

	return $row;
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

	$self->movedUpRowNotify($self->row($id));
	
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

	$self->movedDownRowNotify($self->row($id));
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

# Method: removeRow
#
#	Remove a row
#
# Parameters:
#
# 	'id' - row id
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - throw if any mandatory
#       argument is missing
#
sub removeRow
{
	my ($self, $id) = @_;

	throw EBox::Exceptions::MissingArgument("Missing row identifier to remove")
	  unless defined ( $id );

	$self->_checkRowExist($id, '');
	my $row = $self->row($id);
	$self->{'gconfmodule'}->delete_dir("$self->{'directory'}/$id");

	if ($self->table()->{'order'}) {
		$self->_removeOrderId($id);
	}

	$self->deletedRowNotify($row);

	$self->_increaseStoredVersion();
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
	my $self = shift;
	my %params = @_;

	my $id = delete $params{'id'};
	$self->_checkRowExist($id, '');
	
	my $dir = $self->{'directory'};
	my $gconfmod = $self->{'gconfmodule'};
	
	$self->validateRow(@_);
	
	my $oldrow = $self->row($id);
	my @newValues = @{$self->table()->{'tableDescription'}};

	# Check if the new row is unique
	if ( $self->rowUnique() ) {
	  $self->_checkRowIsUnique($id, \@newValues);
	}

	my @oldValues = @{$oldrow->{'values'}};
	my $modified = undef;
	for (my $i = 0; $i < @newValues ; $i++) {
		my $newData = clone($newValues[$i]);
		$newData->setMemValue(\%params);
		
		if ($oldValues[$i]->isEqualTo($newData)) {
			next;
		}

		if ($newData->unique()) {
			$self->_checkFieldIsUnique($newData);
		}

		$newData->storeInGconf($gconfmod, "$dir/$id");
		$modified = 1;
	}

	$oldrow->{'values'} = \@newValues;

	if ($modified) {
		$self->_increaseStoredVersion();
	}

	$self->updatedRowNotify($oldrow);	
}

sub _addSelectOptionsToHash
{
	my ($self, $hash) = @_;
	
	my $desc = $self->table()->{'tableDescription'};
	unless (defined($desc)) {
		throw Excepetions::Internal('table description not defined');
	}
	foreach my $field (@{$desc}) {
		$self->{'fieldDesc'}->{$field->{'fieldName'}} = $field; ;
	}
	
	foreach my $field (keys %{$hash}) {
	
		if ($self->{'fieldDesc'}->{$field}->{'type'} ne 'select') {
			next;
		}

		$hash->{$field} = $self->selectOptions($field, $hash->{'id'});
	}
		
}
sub _storedVersion
{
	my ($self) = @_;
	
	my $gconfmod = $self->{'gconfmodule'};
	my $storedVerKey = $self->{'directory'} . '/version';
	
	return ($gconfmod->get_int($storedVerKey));
}



# Method: rows
#
# 	Return a list containing the table rows 	
#
# Returns:
#
#	Array ref containing the rows 
sub rows
{
	my $self = shift;
	
	# The method which takes care of loading the rows
	# from gconf is _rows(). 
	#
	# rows() tries to cache the data to avoid extra access
	# to gconf
	my $gconfmod = $self->{'gconfmodule'};
	my $storedVersion = $self->_storedVersion();
	my $cachedVersion = $self->{'cachedVersion'};

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

	return $self->{'cachedRows'};
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

sub _increaseStoredVersion
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
		throw Exceptions::MissingArgument('dir');
	}

	$self->{'directory'} = "$dir/keys";
	$self->{'order'} = "$dir/order";

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

    return $self->{'directory'};

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

	foreach my $data (@{$table->{'tableDescription'}}) {

		push (@parameters, $data->fields());

		if ($data->type() eq 'union') {
			foreach my $subtype (@{$data->subtypes()}) {
				next unless ($subtype->type() eq 'select');
				$subtype->addOptions(
					$self->selectOptions(
						$subtype->fieldName()));	

			}
		}
		if ($data->type() eq 'select') {
			$data->addOptions(
				$self->selectOptions($data->fieldName()));	
		}

	}



	my $paramsArray = '[' . "'" . pop(@parameters) . "'";
	foreach my $param (@parameters) {
		$paramsArray .= ', ' . "'" . $param . "'";
	}
	$paramsArray .= ']';
	
	$table->{'gconfdir'} = $self->{'gconfdir'};
	$table->{'paramArrayString'} = $paramsArray;
	
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
		throw Excepetions::Internal('table description not defined');
	}
	
	my @tableHead = @{$self->table()->{'tableDescription'}};
	my @tableFields = map { $_->{'fieldName'} } @tableHead;

	$self->{'fields'} = \@tableFields;
	
	return \@tableFields;
}

# Private helper functions
#
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

    my @rowIds = $self->{'gconfmodule'}->all_dirs($self->{'directory'});

    foreach my $aRowId (@rowIds) {
      # Compare if the row identifier is different
      next if (defined ($rowId)) and ($aRowId == $rowId);

      my $hash = $self->{'gconfmodule'}->hash_from_dir($aRowId);
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
	$self->_increaseStoredVersion();
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

1;

