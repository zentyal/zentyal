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

use strict;
use warnings;


sub new
{
        my $class = shift;
        my %opts = @_;
        my $gconfmodule = delete $opts{'gconfmodule'};
	my $directory = delete $opts{'directory'};
	my $tableName = delete $opts{'tablename'};
        my $self = 
		{
			'gconfmodule' => $gconfmodule,
			'gconfdir' => $directory,
			'directory' => "$directory/keys",
			'order' => "$directory/order",
			'leading_text' => 'todo', # TODO
			'tableName' => $tableName
		};


        bless($self, $class);
	

        return $self;
}

# Method: table
#	
#	Override this method to describe your table
#
# Returns:
#
# 	table description. See example.
sub table
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
	
	$self->_checkAllFieldsExist(@_);
	
	$self->validateRow(@_);

	foreach my $field (@{$self->table()->{'tableDescription'}}) {
		my $value = $params{$field->{'fieldName'}};

		if ($field->{'unique'} == 1) {
			$self->_checkFieldIsUnique($field->{'fieldName'}, 
					$value, 
					$field->{'printableName'});	
		}
	}
	
	my $id = $gconfmod->get_unique_id($self->{'leading_text'}, 
				      $dir);
	
	foreach my $field (@{$self->table()->{'tableDescription'}}) {
		my $value = $params{$field->{'fieldName'}};

		my $key = "$dir/$id/$field->{'fieldName'}";
		if ($field->{'type'} eq 'text') {
			
			$gconfmod->set_string($key, $value);

		} elsif ($field->{'type'} eq 'int') {

			$gconfmod->set_int($key, $value);

		} elsif ($field->{'type'} eq 'select') {
		
			$gconfmod->set_string($key, $value);
		
		} elsif ($field->{'type'} eq 'checkbox') {

			$gconfmod->set_bool($key, $value);	

		}
	}

	
	if ($self->table()->{'order'}) {
		$self->_insertPos($id, 0);
	}

	
	my %notifyParams = %{$gconfmod->hash_from_dir("$dir/$id")};
	$notifyParams{'id'}  = $id;
	$notifyParams{'order'} = 0;
	$self->addedRowNotify(%notifyParams);
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

	$self->movedUpRowNotify(%{$self->_hashFromDir($id)});
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

	$self->movedDownRowNotify(%{$self->_hashFromDir($id)});
}

# Method: removeRow
#
#	Remove a row 
#
# Parameters:
# 	
# 	'id' - row id
#
sub removeRow 
{
	my ($self, $id) = @_;

	$self->_checkRowExist($id, '');
	my $row = $self->_hashFromDir($id);
	$self->{'gconfmodule'}->delete_dir("$self->{'directory'}/$id");
	
	if ($self->table()->{'order'}) {
		$self->_removeOrderId($id);
	}

	$self->deletedRowNotify(%{$row});
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
	
	my $tableName = $self->table()->{'tableName'};
	my $dir = $self->{'directory'};
	my $gconfmod = $self->{'gconfmodule'};
	

	$self->validateRow(@_);

	my $oldrow = $gconfmod->hash_from_dir("$dir/$id");
	
	foreach my $field (@{$self->table()->{'tableDescription'}}) {
		my $fieldType = $field->{'type'};
		my $fieldName = $field->{'fieldName'};
		my $value = $params{$fieldName};

		
		# FIXME If we compare stuff as strings we get rid of this ifs
		my $sameValue;
		if ($fieldType eq 'checkbox' or $fieldType eq 'int') {
		
			$sameValue = ($oldrow->{$fieldName} 
					== $params{$fieldName});
		} else {

			$sameValue = ($oldrow->{$fieldName} 
					eq $params{$fieldName});
		}
	
		
		if (($fieldType eq 'text') and $sameValue) {

			next;

		} elsif (($fieldType eq 'int') and $sameValue) {

			next;

		} elsif (($fieldType eq 'select') and $sameValue) {

			next;

		} elsif (($fieldType eq 'checkbox') and $sameValue) {

			next;
		}
		    
		if ($field->{'unique'} == 1) {
			$self->_checkFieldIsUnique($fieldName, 
					$value, 
					$field->{'printableName'});	
		}
		
		my $key = "$dir/$id/$fieldName";
		if ($field->{'type'} eq 'text') {
			
			$gconfmod->set_string($key, $value);

		} if ($field->{'type'} eq 'int') {
			
			$gconfmod->set_int($key, $value);

		
		} elsif ($field->{'type'} eq 'select') {
		
			$gconfmod->set_string($key, $value);
		
		} elsif ($field->{'type'} eq 'checkbox') {

			$gconfmod->set_bool($key, $value);	

		}
	}
	
	$self->updatedRowNotify(%{$self->_hashFromDir($id)});	
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
		$hash->{'id'} = $id;
		#$self->_addSelectOptionsToHash($hash);
		if (%order) {
			$hash->{'order'} = $order{$id};
			$rows[$order{$id}] = $hash;
		} else {
			push(@rows, $hash);
		}
	}


	return \@rows;
}

# Method: setTableName
#
#	Use this method to set the current table name. This method
#	comes in handy to manage several tables with same model
#
# Paramters:
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
# Paramters:
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
	$self->{'order'} = "$dir/keys";
	
}

# Method: tableInfo
#
# 	Resturn the table info. 
#
# Returns:
#
# 	Hash ref containing the table info
#
sub tableInfo
{
	my $self = shift;

	my $table = $self->table();

	foreach my $field (@{$table->{'tableDescription'}}) {
	
		if ($field->{'type'} ne 'select') {
			next;
		}

		$field->{'selectOptions'} = $self->selectOptions($field->{'fieldName'});	
	}

	$table->{'gconfdir'} = $self->{'gconfdir'};

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
	my ($self, $key, $value, $text) = @_;

	my $gconfmod = $self->{'gconfmodule'};
	my $dir = $self->{'directory'};

	unless ($gconfmod->dir_exists($dir)) {
		return 0;
	}

	my @ids = $gconfmod->all_dirs($dir);

	foreach my $id (@ids) {
		my $hash = $gconfmod->hash_from_dir($id);
		if ($hash->{$key} eq $value)  {
			throw EBox::Exceptions::DataExists(
					'data' => $text,
					'value' => $value);

		}
	}

	return 0;
}


sub _checkAllFieldsExist
{
	my $self = shift;
	my %params = @_;

	foreach my $field (@{$self->fields()}) {
		unless (exists $params{$field}) {
			throw Exceptions::MissingArgument($field);
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
