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

# Class: EBox::IPsec::Model::RangeTable
#
# This class is used to set the IP ranges available in a l2tp VPN server.
# The fields are the following:
#
# - name : Text
# - from : HostIP
# - to   : HostIP
#
package EBox::IPsec::Model::RangeTable;
use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Model::Manager;
use EBox::Types::Text;
use EBox::Types::HostIP;

################
# Dependencies
################
use Net::IP;

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ((exists $changedFields->{from}) or
        (exists $changedFields->{to})) {

        my $from = $allFields->{from}->value();
        my $to = $allFields->{to}->value();
        my $range = new Net::IP($from . ' - ' . $to);

        unless (defined ( $range )) {
            throw EBox::Exceptions::External(
                __x('{from} - {to} is an invalid range',
                    from => $from,
                    to => $to,
                )
            );
        }

        my $network  = EBox::Global->modInstance('network');
        my $dhcp;
        if (EBox::Global->modExists('dhcp')) {
            $dhcp = EBox::Global->modInstance('dhcp');
        }

        # Check all local networks configured on the server.
        foreach my $interface (@{$network->allIfaces()}) {

            my $usedRange = new Net::IP($network->netInitRange($interface) . '-' . $network->netEndRange($interface));

            unless ($range->overlaps($usedRange) == $IP_NO_OVERLAP) {
                throw EBox::Exceptions::External(
                    __x('Range {from}-{to} overlaps with the network {net} on the existing interface {ifaceName}',
                        from => $from,
                        to => $to,
                        net => EBox::NetWrappers::to_network_with_mask(
                            $network->ifaceNetwork($interface), $network->ifaceNetmask($interface)),
                        ifaceName => $interface,
                    )
                );
            }

            if (EBox::Global->modExists('dhcp')) {

                next if ($network->ifaceMethod($interface) ne 'static');

                my $fixedAddresses = $dhcp->fixedAddresses($interface, 0);

                foreach my $fixedAddr (@{$fixedAddresses}) {
                    my $fixedIP = new Net::IP($fixedAddr->{ip});
                    unless ( $fixedIP->overlaps($range) == $IP_NO_OVERLAP ) {
                        throw EBox::Exceptions::External(
                            __x('Range {from}-{to} includes fixed address from the object member "{name}": {fixedIP}',
                                from => $from,
                                to => $to,
                                name => $fixedAddr->{name},
                                fixedIP => $fixedAddr->{ip}
                            )
                        );
                    }
                }
            }
        }

        # Check local IP to be used for the VPN.
        my $ipsec = $self->parentModule();
        my $l2tp_settings = $ipsec->model('SettingsL2TP');
        my $localAddr = $l2tp_settings->value('localIP');
        my $localIPObj = new Net::IP($localAddr);
        unless ( $localIPObj->overlaps($range) == $IP_NO_OVERLAP ) {
            throw EBox::Exceptions::External(
                __x('Range {from}-{to} includes the local IP address: {localIP}',
                    from => $from,
                    to => $to,
                    localIP => $localAddr,
                )
            );
        }

        # Check other ranges.
        my $currentId;
        if ($action eq 'update') {
            $currentId = $allFields->{name}->row()->id();
        }
        foreach my $id (@{$self->ids()}) {
            my $row = $self->row($id);
            my $compareId = $row->id();

            if ( $action eq 'update' and $compareId eq $currentId ) {
                next;
            }

            my $compareFrom = $row->valueByName('from');
            my $compareTo   = $row->valueByName('to');
            my $compareRange = new Net::IP($compareFrom . '-' . $compareTo);
            unless ($compareRange->overlaps($range) == $IP_NO_OVERLAP) {
                throw EBox::Exceptions::External(
                    __x("Range {newFrom}-{newTo} overlaps with range '{range}': {oldFrom}-{oldTo}",
                        newFrom => $from,
                        newTo => $to,
                        range => $row->valueByName('name'),
                        oldFrom => $compareFrom,
                        oldTo   => $compareTo,
                    )
                );
            }
        }
    }
}

# Group: Protected methods

# Method: _table
#
#   Describe the DHCP ranges table
#
# Returns:
#
#   hash ref - table's description
#
sub _table
{
    my ($self) = @_;

    my @fields = (
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
        'defaultActions'     => [ 'add', 'del', 'editField', 'changeView' ],
        'modelDomain'        => 'IPsec',
        'tableDescription'   => \@fields,
        'class'              => 'dataTable',
        'rowUnique'          => 1,
        'printableRowName'   => __('range'),
        'sortedBy'           => 'from',
    };

    return $dataTable;

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
