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
#   EBox::Network::Model::PhysicalInterfaceTable
#
#   This class is used as a model to describe the physical interfaces
#   availables in the machine
#
#   It subclasses <EBox::Model::DataTable>

package EBox::Network::Model::PhysicalInterfaceTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::Text;

use Net::ARP;

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

sub _table
{
    my @tableHead = 
        ( 

        	 new EBox::Types::Text(
                     'fieldName' => 'name',
                     'printableName' => __('Name'),
                     'class' => 'tcenter',
                     'type' => 'text',
                     'size' => '12',
                     'unique' => 1,
                     'editable' => 1
                )
	    );

    my $defaultController = '/ebox/Network/Controller/PhysicalInterfaceTable';

    my $dataTable = 
    { 
        'tableName' => 'PhysicalInterfaceTable',
        'printableTableName' => __('Physical interface list'),
        'automaticRemove' => 1,
        'defaultController' => $defaultController,
        'defaultActions' => [ 'changeView' ],
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'order' => 0,
        'help' => __('These are the physical interfaces which are available in'                      . ' your system.'),
        'rowUnique' => 0,
        'printableRowName' => __('interface'),
    };

    return $dataTable;
}

# Method: rows 
#
#       Override <EBox::Model::DataTable>
#
#   It is overriden because this table is kind of different in 
#   comparation to the normal use of generic data tables.
#
#   - The user does not add rows. When we detect the table is
#   empty we populate the table with the available interfaces.
#
#   - We check if we have to add/remove interfaces. That happens
#     when an interface is physically removed
#
#   
sub rows()
{
    my $self = shift;

    my $network = EBox::Global->modInstance('network');

    # Fetch the current interfaces stored in gconf 
    my $currentRows = $self->SUPER::rows();
    my %storedInterfaces = map {
                                    $_->{'plainValueHash'}->{'name'} => 1
                               } @{$currentRows};

    # Fetch the current interfaces 
    my %currentInterfaces = map { $_ => 1  } @{$network->_ifaces};

    # Add new interface to gconf
    foreach my $name (keys %currentInterfaces) {
        next if (exists $storedInterfaces{$name});
        $self->addRow('id' => $name,'name' => $name);
    }

    # Remove non-existing interfaces from gconf
    foreach my $row (@{$currentRows}) {
        my $name = $row->{'plainValueHash'}->{'name'};
        next if (exists $currentInterfaces{$name});
        $self->removeRow($row->{'id'});
    }

    return $self->SUPER::rows();
}

1;

