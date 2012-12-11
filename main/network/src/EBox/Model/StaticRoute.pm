# Copyright (C) 2008-2012 eBox Technologies S.L.
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

use EBox::Gettext;
use EBox::Types::IPAddr;
use EBox::Types::HostIP;
use EBox::Types::Text;
use EBox::NetWrappers;
use EBox::Exceptions::External;


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
    bless ($self, $class);

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
    my $netMod = $self->parentModule();
    my $gw = $allFields->{gateway};
    my $gwIp = $gw->value();

    if ($netMod->model('GatewayTable')->findValue(ip => $gwIp)) {
        throw EBox::Exceptions::External(
            __x('Gateway {gw} is already defined in the gateway table. Use a multi gateway rule instead',
                gw => $gwIp
               )
           );
    }
    $netMod->gatewayReachable($gwIp,
                              $gw->printableName());

    my $targetIP = $allFields->{network}->ip();
    my $targetMaskBits = $allFields->{network}->mask();
    my $targetNetwork = EBox::NetWrappers::ip_network($targetIP,
                                                      EBox::NetWrappers::mask_from_bits($targetMaskBits));
     foreach my $iface (@{ $netMod->allIfaces() }) {
         my @addrs = @{ $netMod->ifaceAddresses($iface) };
         foreach my $addr_r (@addrs) {
            my $addr = $addr_r->{address};
            my $mask = $addr_r->{netmask};
            if ($targetMaskBits == 32) {
                $targetNetwork = EBox::NetWrappers::ip_network($targetIP, $mask);
            }
            if ($addr eq $targetIP) {
                throw EBox::Exceptions::External(
                    __x('Network {addr} is invalid because it is the address of the interface {if}',
                        addr => $addr,
                        if   => $iface,
                   )
                );
            } elsif ($addr eq $gwIp) {
               throw EBox::Exceptions::External(
                    __x('Gateway {addr} is invalid because it is the address of the interface {if}',
                        addr => $addr,
                        if   => $iface,
                   )
                );
            }

            my $addrNetwork =  EBox::NetWrappers::ip_network($addr, $mask);
            if ($addrNetwork eq $targetNetwork) {
                throw EBox::Exceptions::External(
                    __x(
                        'Not needed to add a route to {ip} because is reacheable directly by interface {if}',
                         ip => "$targetIP/$targetMaskBits",
                        if => $iface
                  ) );
            }
         }
     }

    # As we cannot clone the oldRow, we just keep the old params here
    if ( $action eq 'update' ) {
        my $oldRow = $self->row($changedFields->{id});
        unless ( ($allFields->{gateway}->cmp($oldRow->elementByName('gateway')) == 0)
                 and ($allFields->{network}->cmp($oldRow->elementByName('network')) == 0)) {
            $self->{toDelete} = { network => $oldRow->printableValueByName('network'),
                                  gateway => $oldRow->printableValueByName('gateway') };
        }
    }
}

# Method: updatedRowNotify
#
# Overrides:
#
#   <EBox::Model::DataTable::deletedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    # Check if network or gateway values have changed to delete
    # current route from routing table
    # The check is done in validateTypedRow
    if (exists $self->{toDelete}) {
        my $netMod = $self->parentModule();
        $netMod->gatewayDeleted($self->{toDelete}->{gateway});
        delete $self->{toDelete};
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

    my $netMod = $self->parentModule();
    $netMod->gatewayDeleted($gw);
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
           printableName => 'Gateway',
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
                       printableTableName => __('Static Routes List'),
                       pageTitle          => __('Static Routes'),
                       modelDomain        => 'Network',
                       defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
                       tableDescription   => \@tableDesc,
                       class              => 'dataTable',
                       help               => __('All gateways you enter here must be reachable '
                                               . 'through one of the network interfaces '
                                               . 'currently configured.'),
                       printableRowName   => __('static route'),
                       sortedBy           => 'gateway',
                       index              => 'network',
                     };

      return $dataTable;
}

1;
