# Copyright (C) 2008-2011 eBox Technologies S.L.
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

# Class: EBox::DHCP::Model::FixedAddressTable
#
# This class is used to set the fixed addresses on a dhcp server
# attached to an interface. The fields are the following:
#
# - object: Network Object (Foreign model)
# - description : Text
#
package EBox::DHCP::Model::FixedAddressTable;

use strict;
use warnings;

use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::Model::ModelProvider;
use EBox::NetWrappers;
use EBox::Types::Text;
use EBox::Types::Select;

use base 'EBox::Model::DataTable';


# Constructor: new
#
#       Constructor for Rule table
#
# Parameters:
#
#       interface   - the interface where the table is attached to
#
# Returns :
#
#      A recently created <EBox::DHCP::Model::RangeTable> object
#
sub new
{
    my $class = shift;

    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    $self->{interface} = $opts{interface};

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

    return $self->{interface};

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

    return __x("interface {iface}",
              iface => $self->{interface});

}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    # # Check the given fixed address is not in any user given
    # # range, it is within the available range and it cannot be the
    # # interface address
    # if ( exists ( $changedFields->{ip} )) {
    #     my $newIP = new Net::IP($changedFields->{ip}->value());
    #     my $net = EBox::Global->modInstance('network');
    #     my $dhcp = $self->{gconfmodule};
    #     my $netIP = new Net::IP( $dhcp->initRange($self->{interface}) . '-'
    #                              . $dhcp->endRange($self->{interface}));
    #     # Check if the ip address is within the network
    #     unless ( $newIP->overlaps($netIP) == $IP_A_IN_B_OVERLAP ) {
    #         throw EBox::Exceptions::External(__x('IP address {ip} is not in '
    #                                              . 'network {net}',
    #                                              ip => $newIP->print(),
    #                                              net  => EBox::NetWrappers::to_network_with_mask(
    #                                                      $net->ifaceNetwork($self->{interface}),
    #                                                      $net->ifaceNetmask($self->{interface}))
    #                                             ));
    #     }
    #     # Check the ip address is not the interface address
    #     my $ifaceIP = new Net::IP($net->ifaceAddress($self->{interface}));
    #     unless ( $newIP->overlaps($ifaceIP) == $IP_NO_OVERLAP ) {
    #         throw EBox::Exceptions::External(__x('The selected IP is the '
    #                                              . 'interface IP address: '
    #                                              . '{ifaceIP}',
    #                                              ifaceIP => $ifaceIP->print()
    #                                             ));
    #     }
    #     # Check the new IP is not within any given range by RangeTable model
    #     # FIXME: When #847 is done
    #     # my $rangeModel = $dhcp->model('RangeTable');
    #     my $rangeModel = EBox::Model::ModelManager->instance()->model('/dhcp/RangeTable/'
    #                                                                   . $self->{interface});
    #     foreach my $id (@{$rangeModel->ids()}) {
    #         my $rangeRow = $rangeModel->row($id);
    #         my $from = $rangeRow->valueByName('from');
    #         my $to   = $rangeRow->valueByName('to');
    #         my $range = new Net::IP( $from . '-' . $to);
    #         unless ( $newIP->overlaps($range) == $IP_NO_OVERLAP ) {
    #             throw EBox::Exceptions::External(__x('IP address {ip} is in range '
    #                                                  . "'{range}': {from}-{to}",
    #                                                  ip => $newIP->print(),
    #                                                  range => $rangeRow->valueByName('range'),
    #                                                  from  => $from, to => $to));
    #         }
    #     }
    # }
    # if ( exists ( $changedFields->{name} )) {
    #     my $newName = $changedFields->{name}->value();
    #     # Check remainder FixedAddressTable models uniqueness since
    #     # the dhcpd.conf may confuse those name repetition
    #     my @fixedAddressTables = @{EBox::Model::ModelManager->instance()->model(
    #          '/dhcp/FixedAddressTable/*'
    #                                                                          )};
    #     # Delete the self model
    #     @fixedAddressTables = grep { $_->index() ne $self->index() }
    #       @fixedAddressTables;

    #     my $row = grep { $_->findValue( name => $newName ) }
    #       @fixedAddressTables;

    #     if ( $row ) {
    #         my $i18nAction = '';
    #         if ( $action eq 'update' ) {
    #             $i18nAction = __('update');
    #         } else {
    #             $i18nAction = __('add');
    #         }
    #         throw EBox::Exceptions::External(__x('You cannot {action} a fixed address with a '
    #                                              . 'name which is already used in other fixed '
    #                                              . 'address table',
    #                                              action => $i18nAction));
    #     }

    # }

}

# Method: viewCustomizer
#
#   Overrides this to warn the user only those members with an IP
#   address within the valid range and a MAC address and not in the
#   range.
#
# Overrides:
#
#   <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setPermanentMessage(_message());
    return $customizer;
}


# Group: Protected methods

# Method: _table
#
#	Describe the DHCP ranges table
#
# Returns:
#
# 	hash ref - table's description
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
       new EBox::Types::Select(
                               fieldName     => 'object',
                               foreignModel  => \&objectModel,
                               foreignField  => 'name',
                               printableName => __('Object'),
                               unique        => 1,
                               editable      => 1,
                               optional      => 0,
                              ),
       new EBox::Types::Text(
                             fieldName     => 'description',
                             printableName => __('Description'),
                             editable      => 1,
                             optional      => 1,
                            ),
      );

      my $dataTable = {
      'tableName'          => 'FixedAddressTable',
      'printableTableName' => __('Fixed addresses'),
      'defaultActions'     =>
        [ 'add', 'del', 'editField', 'changeView' ],
      'modelDomain'        => 'DHCP',
      'tableDescription'   => \@tableDesc,
      'class'              => 'dataTable',
      'rowUnique'          => 1,  # Set each row is unique
      'printableRowName'   => __('fixed address'),
      'order'              => 0,  # Ordered by tailoredOrder
      'sortedBy'           => 'object',
        };

    return $dataTable;

}

# Closures
sub objectModel
{
    return EBox::Global->modInstance('objects')->{'objectModel'};
}

sub _message
{
    return __('Only those object members whose IP address is a host (/32), a '
              . 'valid MAC, the IP address is not used by the available range '
              . 'and whose name is unique as fixed address will be used');
}

1;
