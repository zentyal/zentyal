# Copyright (C) 2008-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::DHCP::Model::RangeTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Model::Manager;
use EBox::Types::Text;
use EBox::Types::HostIP;
use EBox::Exceptions::External;

use base 'EBox::Model::DataTable';

################
# Dependencies
################
use Net::IP;

# Constructor: new
#
#       Constructor for Rule table
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

    return $self;
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

    if ((exists $changedFields->{from})
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
        my $net  = EBox::Global->modInstance('network');
        my $interface = $self->_iface();
        my $availableRange = new Net::IP($net->netInitRange($interface) . '-'
                                         . $net->netEndRange($interface));
        unless ( $range->overlaps($availableRange) == $IP_A_IN_B_OVERLAP ) {
            throw EBox::Exceptions::External(__x('Range {from}-{to} is not in '
                                                 . 'network {net}',
                                                 from => $from,
                                                 to   => $to,
                                                 net  => EBox::NetWrappers::to_network_with_mask(
                                                         $net->ifaceNetwork($interface),
                                                         $net->ifaceNetmask($interface))
                                                 ));
        }
        # Check the range does not contain the interface address
        my $ifaceAddr = $net->ifaceAddress($interface);
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
        foreach my $id ( @{$self->ids()} ) {
            my $row = $self->row($id);
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
        my $fixedAddresses = $self->{confmodule}->fixedAddresses($interface, 0);
        foreach my $fixedAddr (@{$fixedAddresses}) {
            my $fixedIP = new Net::IP($fixedAddr->{ip});
            unless ( $fixedIP->overlaps($range) == $IP_NO_OVERLAP ) {
                throw EBox::Exceptions::External(__x('Range {from}-{to} includes '
                                                     . 'fixed address from the '
                                                     . 'object member "{name}": '
                                                     . '{fixedIP}',
                                                     from => $from,
                                                     to   => $to,
                                                     name => $fixedAddr->{name},
                                                     fixedIP => $fixedAddr->{ip}
                                                    ));
            }
        }

        # Check HA floating IP overlapping
        my $global = EBox::Global->getInstance();
        if ($global->modExists('ha') and $global->modInstance('ha')->isEnabled()) {
            my $ha = $global->modInstance('ha');
            my $floatingIPs = $ha->floatingIPs();
            foreach my $floatingIPAddr (@{$floatingIPs}) {
                my $floatingIP = new Net::IP($floatingIPAddr->{address});
                unless ( $floatingIP->overlaps($range) == $IP_NO_OVERLAP ) {
                    throw EBox::Exceptions::External(__x('Range {from}-{to} includes '
                                                          . 'the HA floating IP: '
                                                          . '"{name}" - {IP}',
                                                          from => $from,
                                                          to   => $to,
                                                          name => $floatingIPAddr->{name},
                                                          IP => $floatingIPAddr->{address}
                                                         ));
                }
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
#	hash ref - table's description
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

sub _iface
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->valueByName('iface');
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();

    $customizer->setModel($self);

    $customizer->setHTMLTitle([]);

    return $customizer;
}

1;
