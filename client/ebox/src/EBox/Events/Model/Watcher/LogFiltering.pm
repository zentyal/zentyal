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

# Class: EBox::Events::Model::Watcher::LogFiltering
#
# This class is used to set those filters that you may want to be
# informed. This model is used as template given a set of filters (all
# String-based) and events (a selection) using tableInfo information
# (Check <EBox::LogObserver::tableInfo> for details)
#
# The model composition based on tableInfo information is the
# following: 
#
#     - filter1..n - Text
#     - event      - Selection between the given selections from tableInfo
#

# FIXME ALL code 
package EBox::Events::Model::Watcher::LogFiltering;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

# eBox uses
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;

# Group: Public methods

# Constructor: new
#
#       Constructor for <EBox::Events::Model::Watcher::LogFiltering>
#       object instance
#
# Parameters:
#
#       gconfmodule -
#       directory   -
#
#       tableInfo - hash ref the table info giving with the same
#       structure that it's described in
#       <EBox::LogObserver::tableInfo>
#
#
# Returns :
#
#      A recently created <EBox::Events::Model::Watcher::LogFiltering>
#      object
#
sub new
{

  my ($class, %params) = @_;

  if ( not defined ($params{tableInfo})) {
    throw EBox::Exceptions::MissingArgument('tableInfo');
  }

  my $self = $class->SUPER::new(%params);

  bless($self, $class);
  $self->{tableInfo} = $params{tableInfo};

  return $self;

}

# Method: index
#
# Overrides:
#
#     <EBox::Model::DataTable::index>
#
sub index
{

    my ($self) = @_;

    return $self->{tableInfo}->{index};

}

# Method: printableIndex
#
# Overrides:
#
#     <EBox::Model::DataTable::printableIndex>
#
sub printableIndex
{

    my ($self) = @_;

    return __x('Log domain {logDomain}',
	       logDomain => $self->{tableInfo}->{name});

}

# Group: Protected methods

# Method: _table
#
#	Describe the traffic shaping table
#
# Returns:
#
# 	hash ref - table's description
#
sub _table
{

    my ($self) = @_;

    my @tableDesc = ();

    # Every filter element from table info is a text-based type
    my @filters = @{$self->{tableInfo}->{filter}};

    foreach my $filter (@filters) {
      push( @tableDesc,
	    new EBox::Types::Text(
	         fieldName     => $filter,
	         printableName => $self->{tableInfo}->{titles}->{$filter},
		 editable      => 1,
				 ));
    }
    # Every event is a selection filter, we always allow the 'any'
    # selection which matches with every event that logger logs
    push ( @tableDesc,
	   new EBox::Types::Select(
				   fieldName => 'event',
				   printableName => __('Event'),
				   editable => 1,
				   populate => \&populateEvents,
				   defaultValue => 'any'
				  ));

    my $dataTable = {
		     'tableName'          => 'LogWatcherFiltering',
		     'printableTableName' => __x('Filters to apply to notify logs from '
						 . '{logDomain}',
						 logDomain => $self->{tableInfo}->{name}),
                     'defaultActions'     =>
                           [ 'add', 'del', 'editField', 'changeView' ],
                     'modelDomain'        => 'Events',
		     'tableDescription'   => \@tableDesc,
		     'class'              => 'dataTable',
		     'help'               => __('Every filter added is cumulative.'
					       . 'Then every log line which matches '
					       . 'with any filter given will be notified'),
		     'rowUnique'          => 1,  # Set each row is unique
		     'printableRowName'   => __('filter'),
		    };

    return $dataTable;

}

# Group: Callback functions

# Function: populateEvents
#
#    Populate event field with options from 'event' key in table
#    info. Moreover, the 'any' element is added if there is more than
#    one event lives in the table info
#
# Returns:
#
#    array ref - containing hash ref with value and printable value
#
sub populateEvents
{

}


1;
