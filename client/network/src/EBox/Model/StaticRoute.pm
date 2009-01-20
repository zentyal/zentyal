# Copyright (C) 2008 Warp Networks S.L.
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

# Class: EBox::Network::Model::StaticRoute
#
# This model configures the static route table for the server
# itself. The fields are the following ones:
#
#    - network
#    - gateway
#    - description (optional)

package EBox::Network::Model::StaticRoute;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Types::IPAddr;
use EBox::Types::HostIP;
use EBox::Types::Text;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the static route table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Network::Model::StaticRoute>
#
sub new
{

      my ($class, %opts) = @_;
      my $self = $class->SUPER::new(%opts);
      bless ( $self, $class);

      return $self;

}

# Method: validateTypedRow
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    # Validate the gateway is reachable
    if ( exists $changedFields->{gateway} ) {
        my $netMod = EBox::Global->modInstance('network');
        $netMod->gatewayReachable($changedFields->{gateway}->value(),
                                  $changedFields->{gateway}->printableName());
    }

}

# Method: updatedRowNotify
#
# Overrides:
#
#     <EBox::Model::DataTable::deletedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $newRow, $oldRow, $force) = @_;

    # Check if network or gateway values have changed to delete
    # current route from routing table
    unless ( $newRow->elementByName('gateway')->cmp($oldRow->elementByName('gateway')) == 0
             and $newRow->elementByName('network')->cmp($oldRow->elementByName('network')) == 0 ){
        $self->_addToDelete($oldRow->elementByName('network')->printableValue(),
                            $oldRow->elementByName('gateway')->printableValue());
    }

}

# Method: deletedRowNotify
#
# Overrides:
#
#     <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $rowDeleted, $force) = @_;

    my $net = $rowDeleted->elementByName('network')->printableValue();
    my $gw = $rowDeleted->elementByName('gateway')->printableValue();

    my $netMod = EBox::Global->modInstance('network');
    $netMod->gatewayDeleted($gw);

    $self->_addToDelete($net, $gw);

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
       new EBox::Types::IPAddr(
           fieldName     => 'network',
           printableName => __('Network'),
           editable      => 1,
           unique        => 1,
           help          => __('IP or network address')
           ),
       new EBox::Types::HostIP(
           fieldName     => 'gateway',
           printableName => __('Gateway'),
           editable      => 1,
           help          => __('Gateway used to reach the above network' .
                               '  address')
           ),
       new EBox::Types::Text(
           fieldName     => 'description',
           printableName => __('Description'),
           editable      => 1,
           optional      => 1,
           help          => __('Optional description for this route')
           ),
      );

      my $dataTable = {
                       tableName          => 'StaticRoute',
                       printableTableName => __('Static routes'),
                       pageTitle          => __('Static route list'),
                       modelDomain        => 'Network',
                       defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
                       tableDescription   => \@tableDesc,
                       class              => 'dataTable',
                       help               => __('All gateways you enter here must be reachable '
                                               . 'through one of the network interfaces '
                                               . 'currently configured'),
                       printableRowName   => __('static route'),
                       sortedBy           => 'gateway',
                       index              => 'network',
                     };

      return $dataTable;

}

# Group: Private methods

sub _addToDelete
{
    my ($self, $net, $gw) = @_;

    # Store the deleted static route
    my $modelManager = EBox::Model::ModelManager->instance();
    my $deletedModel = $modelManager->model('DeletedStaticRoute');
    my $result = $deletedModel->findRow( network => $net );
    if ( defined($result)
           and $result->elementByName('gateway')->value() eq $gw ) {
        $deletedModel->set( $result->id(),
                            deleted => 0);
    } else {
        $deletedModel->add(network => $net,
                           gateway => $gw,
                           deleted => 0);
    }

}


1;
