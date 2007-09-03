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
#   EBox::Network::Model::ConfiugrableInterfaceTable
#
#
#   This class is used as a model to describe the configurable interfaces
#   availables in the machine. So far, they are composed of physical
#   interfaces plus vlan interfaces
#
#   It subclasses <EBox::Model::DataTable>

package EBox::Network::Model::ConfigurableInterfaceTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Text;
use EBox::Types::Boolean;

use EBox::Exceptions::External;
use EBox::Exceptions::DataInUse;

use Error qw(:try);


use strict;
use warnings;


use base qw(EBox::Model::DataTable EBox::NetworkObserver);

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
             'fieldName' => 'interface',
             'printableName' => __('Interface'),
             'class' => 'tleft',
             'type' => 'text',
             'size' => '5',
             'unique' => 1,
             'editable' => 0 
             ),
         new EBox::Types::Text(
             'fieldName' => 'name',
             'printableName' => __('Name'),
             'class' => 'tcenter',
             'type' => 'text',
             'size' => '12',
             'unique' => 1,
             'editable' => 1
             ),
         new EBox::Types::Text(
             'fieldName' => 'method',
             'printableName' => __('Method'),
             'class' => 'tcenter',
             'type' => 'text',
             'size' => '8',
             'unique' => 1,
             'editable' => 0 
             ),
         new EBox::Types::Boolean(
                 'fieldName' => 'external',
                 'printableName' => __('External'),
                 'class' => 'tcenter',
                 'type' => 'boolean',
                 'size' => '8',
                 'unique' => 1,
                 'editable' => 0 
                 ),

         );

    my $defaultController = 
        '/ebox/Network/Controller/ConfigurableInterfaceTable';

    my $dataTable = 
    { 
        'tableName' => 'ConfigurableInterfaceTable',
        'printableTableName' => __('Configurable interface list'),
        'automaticRemove' => 1,
        'defaultController' => $defaultController,
        'defaultActions' => [ 'changeView' ],
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'order' => 0,
        'help' => __('These are the interfaces which can be configured'),
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
    my %storedIfaces = map {
        $_->{'plainValueHash'}->{'name'} => 1
    } @{$currentRows};

    my %currentIfaces = %{$self->_currentInterfaces};

# Add new interface to gconf
    foreach my $name (keys %currentIfaces) {
        next if (exists $storedIfaces{$name});
        $self->addRow('id' => $name,
                'interface' => $name, 
                'name' => $network->ifaceAlias($name),
                'method' => $network->ifaceMethod($name), 
                'external' => $network->ifaceIsExternal($name));
    }

# Remove non-existing interfaces from gconf
    foreach my $row (@{$currentRows}) {
        my $name = $row->{'plainValueHash'}->{'interface'};
        next if (exists $currentIfaces{$name});
        $self->removeRow($row->{'id'});
    }

    return $self->SUPER::rows();
}

sub _currentInterfaces
{
    my $network = EBox::Global->modInstance('network');
    my $phyModel = $network->physicalInterfaceModel();
    my $vlanModel = $network->vlanInterfaceModel();

    my %ifaces = map 
    { 

        $_->{'plainValueHash'}->{'name'} => 1 

    } @{$phyModel->rows()};

    for my $row (map {$_->{'plainValueHash'} }  @{$vlanModel->rows()}) {
        delete $ifaces{$row->{'trunk'}};
        $ifaces{$row->{'name'}} = 1;

    }

    return \%ifaces;
}

# <EBox::Network::NetworkObserver methods>

sub freeIface
{
    my ($self, $name) = @_;

    EBox::debug("Free iface $name");

    my $row = $self->find('id' => $name);

    if ($row) {
        $self->removeRow($row->{'id'}, 1);
    }
}

sub ifaceMethodChanged
{
    my ($self, $iface, $oldmethod, $newmethod) = @_;

    EBox::debug("iface $iface method changed to $newmethod");

    my $row = $self->findValue('id' => $iface);

    my $changedData = new EBox::Types::Text(
            'fieldName' => 'method',
            'printableName' => __('Method'),
            'class' => 'tcenter',
            'type' => 'text',
            'size' => '8',
            'unique' => 1,
            'editable' => 0
            );

    $changedData->setMemValue({method => $newmethod});


    my $ret = undef;
    try {
        $self->_warnOnChangeOnId($iface, $changedData);
    } catch EBox::Exceptions::DataInUse with {
        $ret = 1;
    };

    return $ret;
}

sub ifaceExternalChanged
{
    my ($self, $iface, $external) = @_;

    my $row = $self->findValue('id' => $iface);

    my $changedData = 	new EBox::Types::Boolean(
            'fieldName' => 'external',
            'printableName' => __('External'),
            'class' => 'tcenter',
            'type' => 'boolean',
            'size' => '8',
            'unique' => 1,
            'editable' => 0 
            );
    $changedData->setMemValue({external => $external});


    my $ret = undef;
    try {
        $self->_warnOnChangeOnId($iface, $changedData);
    } catch EBox::Exceptions::DataInUse with {
        $ret = 1;
    };
    return $ret;
}

sub changeIfaceExternalProperty
{
    my ($self, $iface, $external) = @_;

    my $row = $self->findValue('id' => $iface);
    $self->removeRow($row->{'id'}, 1);
}

1;

