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

# Class: EBox::DHCP::Model::RangeTable
#
# This class is used to set the DHCP ranges available in a dhcp server
# attached to an interface. The fields are the following:
#
# - name : Text
# - from : HostIP
# - to   : HostIP
#
package EBox::DHCP::Model::RangeTable;

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Model::ModelManager;
use EBox::Types::Text;
use EBox::Types::HostIP;

use base 'EBox::Model::DataTable';

################
# Dependencies
################
use Net::IP;

# Constructor: new
#
#       Constructor for Rule table
#
# Parameters:
#
#       interface   - the interface where the table is attached to
#
#       - Named parameters
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

    if ( (exists $changedFields->{from})
         or (exists $changedFields->{to})) {
        my $from = $allFields->{from}->value();
        my $to   = $allFields->{to}->value();
        # Check the range is correct
        my $range = new Net::IP($from . ' - ' . $to);
        unless ( defined ( $range )) {
            throw EBox::Exceptions::External(__x('{from} - {to} is an invalid range',
                                                 from => $from,
                                                 to   => $to,
                                                ));
        }
        # Check the range is within the available range
        my $dhcp = $self->{gconfmodule};
        my $net  = EBox::Global->modInstance('network');
        my $availableRange = new Net::IP( $dhcp->initRange($self->{interface}) . '-'
                                          . $dhcp->endRange($self->{interface}));
        unless ( $range->overlaps($availableRange) == $IP_A_IN_B_OVERLAP ) {
            throw EBox::Exceptions::External(__x('Range {from}-{to} is not in '
                                                 . 'network {net}',
                                                 from => $from,
                                                 to   => $to,
                                                 net  => EBox::NetWrappers::to_network_with_mask(
                                                         $net->ifaceNetwork($self->{interface}),
                                                         $net->ifaceNetmask($self->{interface}))
                                                 ));
        }
        # Check the range does not contain the interface address
        my $ifaceAddr = $net->ifaceAddress($self->{interface});
        my $ifaceIPObj = new Net::IP($ifaceAddr);
        unless ( $ifaceIPObj->overlaps($range) == $IP_NO_OVERLAP ) {
            throw EBox::Exceptions::External(__x('Range {from}-{to} includes interface '
                                                 . 'with IP address: {ifaceIP}',
                                                 from => $from,
                                                 to   => $to,
                                                 ifaceIP => $ifaceAddr));
        }
        # Check the other ranges
        my $currentId;
        if ( $action eq 'update' ) {
            $currentId = $allFields->{name}->row()->id();
        }
        foreach my $row ( @{$self->rows()} ) {
            my $compareId = $row->id();
            # If the action is an update, does not check the same row
            if ( $action eq 'update' and $compareId eq $currentId ) {
                next;
            }
            my $compareFrom = $row->valueByName('from');
            my $compareTo   = $row->valueByName('to');
            my $compareRange = new Net::IP( $compareFrom . '-'
                                            . $compareTo);
            unless ( $compareRange->overlaps($range) == $IP_NO_OVERLAP ) {
                throw EBox::Exceptions::External(__x('Range {newFrom}-{newTo} overlaps '
                                                     . "with range '{range}': {oldFrom}-{oldTo}",
                                                     newFrom => $from, newTo => $to,
                                                     range   => $row->valueByName('name'),
                                                     oldFrom => $compareFrom,
                                                     oldTo   => $compareTo));
            }
        }

        # Check fixed addresses
        # FIXME: When #847 is done
        #my $fixedAddressModel = $self->{gconfmodule}->model('FixedAddressTable');
        my $fixedAddressModel = EBox::Model::ModelManager->instance()->model('/dhcp/FixedAddressTable/'
                                                                             . $self->{interface});
        foreach my $map ( @{$fixedAddressModel->rows()} ) {
            my $fixedIP = new Net::IP($map->valueByName('ip'));
            unless ( $fixedIP->overlaps($range) == $IP_NO_OVERLAP ) {
                throw EBox::Exceptions::External(__x('Range {from}-{to} includes fixed '
                                                     . "address '{name}': {fixedIP}",
                                                     from => $from,
                                                     to   => $to,
                                                     name => $map->valueByName('name'),
                                                     fixedIP => $map->valueByName('ip'),
                                                     ));
            }
        }
    }

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
       new EBox::Types::Text(
                             fieldName     => 'name',
                             printableName => __('Name'),
                             unique        => 1,
                             editable      => 1,
                             ),
       new EBox::Types::HostIP(
                               fieldName     => 'from',
                               printableName => __('From'),
                               unique        => 1,
                               editable      => 1,
                              ),
       new EBox::Types::HostIP(
                               fieldName     => 'to',
                               printableName => __('To'),
                               unique        => 1,
                               editable      => 1,
                              ),
      );

    my $dataTable = {
		     'tableName'          => 'RangeTable',
		     'printableTableName' => __('Ranges'),
                     'defaultActions'     =>
                           [ 'add', 'del', 'editField', 'changeView' ],
                     'modelDomain'        => 'DHCP',
		     'tableDescription'   => \@tableDesc,
		     'class'              => 'dataTable',
		     'rowUnique'          => 1,  # Set each row is unique
		     'printableRowName'   => __('range'),
                     'sortedBy'           => 'from',
		    };

    return $dataTable;

}

1;
