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

package EBox::Model::DataMultiTable;

use strict;
use warnings;

use EBox::Exceptions::InvalidType;

# Constructor: new
#
#       Constructor for <EBox::Model::DataMultiTable>
#
# Parameters:
#
#
# Exceptions:
sub new
  {

    my $class = shift;
    my %params = @_;

    my $self = {};

    bless( $self, $class );
    return $self;

  }


# Method: tableModel
#
#      Get a table model given its identifier.
#      It should be implemented
#
# Parameters:
#
#      id - the table's identifier
#
# Returns:
#
#      <EBox::Model::DataTable> - the required table model
#
# Exceptions:
#
#      - <EBox::Exceptions::DataNotFound> - throw if the rule model
#      does NOT exist
#
sub tableModel # (id)
  {

    throw EBox::Exceptions::NotImplemented();

  }

# Method: selectOptions
#
#      Get the selectable options to choose a table to handle with.
#      This method should be override
#
# Returns:
#
#     array ref - a list with hash ref with the following elements:
#                - id - the table identifier
#                - printableId - the table's printable identifier
#
sub selectOptions
  {

    throw EBox::Exceptions::NotImplemented();

  }

# Method: multiTable
#
#      Get the multi table description. It must NOT be overrided.
#
# Returns:
#
#      hash ref with the table description
#
sub multiTable
  {

    my ($self) = @_;

    # It's a singleton method
    unless( defined( $self->{multiTable} ) ){
      $self->{multiTable} = $self->_multiTable();
    }

    return $self->{multiTable};

  }

# Method: _multiTable
#
#	Override this method to describe your multi table.
#       This method is (PROTECTED)
#
# Returns:
#
# 	table description. See example on
# 	<EBox::TrafficShaping::Model::RuleDataMultiTable::_multiTable>. 
#
sub _multiTable
{

  throw EBox::Exceptions::NotImplemented();

}

# Method: selectedTableNotify
#
#      Override this method to be notified whenever a table is
#      selected
#
# Arguments:
#
#      table - <EBox::Model::DataTable>
#
sub selectedTableNotify
  {

  }

# Method: action
#
#      Return the CGI Controller which performs this action
#
# Parameters:
#
#      action - the action's name
#
# Return:
#
#      String - path to the selected action
#
# Exceptions:
#
#      <EBox::Exceptions::DataNotFound> - throw if there is no action
#
sub action # (action)
  {

    my ($self, $action) = @_;

    my $actions_ref = $self->multiTable()->{actions};

    if ( exists ($actions_ref->{$action}) ){
      return $actions_ref->{$action};
    }
    else {
      throw EBox::Exceptions::DataNotFound( data => __('Action'),
					    value => $action);
    }

  }

# Method: printableName
#
#      Return the multitable printable name
#
# Returns:
#
#      String - the printable name
#
sub printableName
  {

    my ($self) = @_;

    return $self->multiTable()->{printableName};

  }

# Method: helpMessage
#
#      Return the help message
#
# Returns:
#
#      String - the help message
#
sub helpMessage
  {

    my ($self) = @_;

    return $self->multiTable()->{help};

  }

# Method: optionMessage
#
#      Return the option message to show close to the selector
#
# Returns:
#
#      String - the option message
#
sub optionMessage
  {

    my ($self) = @_;

    return $self->multiTable()->{optionMessage};

  }

###
# Private helper methods
###

# Check all models
sub _checkModels
  {

    my ($self) = @_;

    foreach my $model (@{$self->{tables}}) {
      if ( not $model->isa('EBox::Model::DataTable') ) {
	throw EBox::Exception::InvalidType( 'model', 'EBox::Model::DataTable' );
      }
    }

  }

1;
