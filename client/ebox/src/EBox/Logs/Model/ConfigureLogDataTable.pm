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

# Class:
#
#   EBox::Logs::Model::ConfigureLogDataTable
#
#   This class is used as a model to describe a table which will be
#   used to select the logs domains the user wants to enable/disable.
#
#   It subclasses <EBox::Model::DataTable>
#
#  
# 

package EBox::Logs::Model::ConfigureLogDataTable;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Sudo;
# eBox exceptions used 
use EBox::Exceptions::External;

use strict;
use warnings;


use base 'EBox::Model::DataTable';


sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Function: filterDomain
#
#   This is a callback used to filter the output of the field domain.
#   It basically translates the log domain
#
# Parameters:
#
#   instancedType-  an object derivated of <EBox::Types::Abastract>
#
# Return:
#
#   string - translation
sub filterDomain
{
    my ($instancedType) = @_;

    my $logs = EBox::Global->modInstance('logs');

    my $table = $logs->getTableInfo($instancedType->value());

    my $translation = $table->{'name'};

    if ($translation) {
        return $translation;
    } else {
        return $instancedType->value();
    }
}

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# This table is composed of two fields:
#
#   domain (<EBox::Types::Text>)    
#   enabled (EBox::Types::Boolean>)
# 
# The only avaiable action is edit and only makes sense for 'enabled'.
# 
sub _table
{
    my @tableHead = 
        ( 
            new EBox::Types::Text(
                    'fieldName' => 'domain',
                    'printableName' => __('Domain'),
                    'class' => 'tcenter',
                    'type' => 'text',
                    'size' => '12',
                    'unique' => 1,
                    'editable' => 0,
		    'filter' => \&filterDomain
                 ),
            new EBox::Types::Boolean(
                    'fieldName' => 'enabled',
                    'printableName' => __('Enabled'),
                    'class' => 'tcenter',
                    'type' => 'boolean',
                    'size' => '1',
                    'unique' => 0,
                    'trailingText' => '',
                    'editable' => 1,
                ),
	    new EBox::Types::Select(
		  'fieldName' => 'lifeTime',
		  'printableName' => __('Purge logs older than'),
		   populate       => \&_populateSelectLifeTime,
		   editable       => 1,
		  defaultValue    => 168, # one week
		 ),


        );

    my $dataTable = 
        { 
            'tableName' => 'ConfigureLogTable',
            'printableTableName' => __('Configure logs'),
	    'defaultController' => '/ebox/Logs/Controller/ConfigureLogTable',
            'defaultActions' => [ 'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'order' => 0,
            'help' => __x('Enable/disable logging per-module basis'),
            'rowUnique' => 0,
            'printableRowName' => __('logs'),
        };

    return $dataTable;
}



sub _populateSelectLifeTime

{
  # life time values must be in hours
  return  [
	   {
	    printableValue => __('never purge'),
	    value          =>  0,
	   },
	   {
	    printableValue => __('one hour'),
	    value          => 1,
	   },
	   {
	    printableValue => __('twelve hours'),
	    value          => 12,
	   },
	   {
	    printableValue => __('one day'),
	    value          => 24,
	   },
	   {
	    printableValue => __('three days'),
	    value          => 72,
	   },
	   {
	    printableValue => __('one week'),
	    value          =>  168,
	   },
	   {
	    printableValue => __('fifteeen days'),
	    value          =>  360,
	   },
	   {
	    printableValue => __('thirty days'),
	    value          =>  720,
	   },
	   {
	    printableValue => __('ninety days'),
	    value          =>  2160,
	   },
	  ];
}


# Method: enabledLogs
#
#   Return those log domains which must be logged.
#
# Returns:
#
#   Hashref containing the enabled logs.
#
#   Example:
#   
#       { 'squid' =>  1, 'dhcp' => 1 }
#
#   
sub enabledLogs()
{
    my $self = shift;

    my %enabledLogs;
    for my $row (@{$self->rows()}) {
        next unless ($row->{'valueHash'}->{'enabled'}->value());
        $enabledLogs{$row->{'valueHash'}->{'domain'}->value()}  = 1;
    }
    return \%enabledLogs;
}

# Method: rows 
#
#       Override <EBox::Model::DataTable>
#
#   It is overriden because this table is kind of different in 
#   comparation to the normal use of generic data tables.
#
#   - The user does not add rows. When we detect the table is
#   empty we populate the table with the available log domains.
#
#   - We check if we have to add/remove one the log domains. That happens
#   when a new module is installed or an existing one is removed.
#
#   
sub rows
{
    my ($self, $filter, $page) = @_;

    my $logs = EBox::Global->modInstance('logs');

    # Fetch the current log domains stored in gconf 
    my $currentRows = $self->SUPER::rows();
    my %storedLogDomains;
    foreach my $row (@{$currentRows}) {
        $storedLogDomains{$row->{'valueHash'}->{'domain'}->value()} = 1;
    }

    # Fetch the current available log domains
    my %currentLogDomains;
    my $currentTables = $logs->getAllTables();
    foreach my $table (keys (%{$currentTables})) {
        $currentLogDomains{$table} = 1;
    }

    # Add new domains to gconf
    foreach my $domain (keys %currentLogDomains) {
        next if (exists $storedLogDomains{$domain});
	my $enabled;
	if ($currentTables->{$domain}->{'disabledByDefault'})  {
		$enabled = 0;
	} else {
		$enabled = 1;
	}
        $self->addRow('domain' => $domain, 'enabled' => $enabled, lifeTime => 0);
    }

    # Remove non-existing domains from gconf
    foreach my $row (@{$currentRows}) {
        my $domain = $row->{'valueHash'}->{'domain'}->value();
        next if (exists $currentLogDomains{$domain});
        $self->removeRow($row->{'id'});
    }

    return $self->SUPER::rows($filter, $page);
}

# Method: validateTypedRow
#
#	Override <EBox::Model::DataTable::validateTypedRow>
#
sub updatedRowNotify 
{
  my ($self, $row) = @_;

  my $domain = $row->{'valueHash'}->{'domain'}->value();
  my $enabled = $row->{'valueHash'}->{'enabled'}->value();
 
  my $logs = EBox::Global->modInstance('logs');
  my $tables = $logs->getAllTables();

  unless (exists $tables->{$domain}) {
	EBox::warn("Domain: $domain does not exist in logs");
  }
  

  my $helper = $tables->{$domain}->{'helper'};
  $helper->enableLog($enabled);

}


1;

