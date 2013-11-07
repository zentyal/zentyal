# Copyright (C) 2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Ntop::Model::LocalNetworks;

# Class: EBox::Ntop::Model::LocalNetworks
#
#     Define the networks should treat as local to ntop and Zentyal Remote
#

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::IPNetwork;
use EBox::Types::Select;
use EBox::Types::Union;

# Constants
use constant PRIVATE_NETWORKS => qw(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16);

# Group: Public methods

# Method: syncRows
#
#    Override to set default local networks to private IP address
#    according to RFC 1918 for IPv4
#
# Overrides:
#
#    <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    unless (@{$currentRows}) {
        foreach my $privateNetwork (PRIVATE_NETWORKS) {
            $self->add(local_network => { local_network_ip => $privateNetwork });
        }
        return 1;
    }
    return 0;
}


# Method: networkIPAddresses
#
#    Get the network IP address to set as local
#
# Returns:
#
#    Array ref - the network IP addresses
#
sub networkIPAddresses
{
    my ($self) = @_;

    my $objMod = EBox::Global->getInstance(1)->modInstance('objects');

    my @addrs;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $localNetwork = $row->elementByName('local_network');
        if ($localNetwork->selectedType() eq 'local_network_object') {
            # Get the addresses with netmask
            push(@addrs, @{$objMod->objectAddresses($localNetwork->value())});
        } else {
            push(@addrs, $localNetwork->printableValue());
        }
    }
    return \@addrs;
}


# Group: Protected methods

# Method: _table
#
#    Set model description
#
# Overrides:
#
#    <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHead =
     (
         new EBox::Types::Union(
             fieldName     => 'local_network',
             printableName => __('Local network'),
             subtypes      => [
                 new EBox::Types::IPNetwork(
                     fieldName     => 'local_network_ip',
                     printableName => __('Network IP address'),
                     editable      => 1,
                    ),
                 new EBox::Types::Select(
                     fieldName     => 'local_network_object',
                     printableName => __('Network object'),
                     foreignModel  => $self->modelGetter('objects', 'ObjectTable'),
                     foreignField  => 'name',
                     foreignNextPageField => 'members',
                     editable      => 1),
                ],
             unique   => 1,
             editable => 1,
            ),
         );

    my $dataTable =
      {
            'tableName' => __PACKAGE__->nameFromClass(),
            'printableTableName' => __('Local Networks'),
            'automaticRemove' => 1,
            'defaultController' => '/Ntop/Controller/LocalNetworks',
            'defaultActions' => [ 'add', 'del',  'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'menuNamespace' => 'Ntop/View/LocalNetworks',
            'class' => 'dataTable',
            'help' => __x('Any traffic on these networks is considered local.'),
            'printableRowName' => __('local network'),
        };

    return $dataTable;
}

1;
