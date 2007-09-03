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
#   EBox::Network::Model::VlanInterfaceTable
#
#
#   This class is used as a model to describe the physical interfaces
#   availables in the machine
#
#   It subclasses <EBox::Model::DataTable>

package EBox::Network::Model::VlanInterfaceTable;

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
                     'editable' => 0 
                ),
		new EBox::Types::Text(
                     'fieldName' => 'trunk',
                     'printableName' => __('Physical interface'),
                     'class' => 'tcenter',
                     'type' => 'text',
                     'size' => '12',
                     'unique' => 1,
                     'editable' => 0 
                ),

	    );

    my $defaultController = '/ebox/Network/Controller/VlanInterfaceTable';

    my $dataTable = 
    { 
        'tableName' => 'VlanInterfaceTable',
        'printableTableName' => __('Vlan interface list'),
        'automaticRemove' => 1,
        'defaultController' => $defaultController,
        'defaultActions' => [ 'changeView' ],
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'order' => 0,
        'help' => __('These are the vlan interfaces which are available in'                      . ' your system.'),
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
#   empty we populate the table with the available vlan interfaces.
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
    my %storedVlans = map {
                                    $_->{'plainValueHash'}->{'name'} => 1
                               } @{$currentRows};

    my %currentVlans;
    for my $vlan (@{$network->vlans()}) {
        my $vlanInfo = $network->vlan($vlan);
        $currentVlans{"vlan$vlan"} = $vlanInfo->{'interface'};
    }

    # Add new interface to gconf
    foreach my $name (keys %currentVlans) {
        next if (exists $storedVlans{$name});
        $self->addRow('id' => $name , 'name' => $name, 
                      'trunk' => $currentVlans{$name});
    }

    # Remove non-existing interfaces from gconf
    foreach my $row (@{$currentRows}) {
        my $name = $row->{'plainValueHash'}->{'name'};
        next if (exists $currentVlans{$name});
        $self->removeRow($row->{'id'});
    }

    return $self->SUPER::rows();
}

1;

