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
use strict;
use warnings;

package EBox::IPsec::Model::RangeTable;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Model::Manager;
use EBox::Types::Text;
use EBox::Types::HostIP;
use EBox::Validate;
use EBox::Exceptions::External;
use Net::IP;

use TryCatch;

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;
    my $global = $self->global();

    if ((exists $changedFields->{from}) or
        (exists $changedFields->{to})) {
        my $from = $allFields->{from}->value();
        my $to   = $allFields->{to}->value();
        my $newRangeHash = {
            from => $from,
            to   => $to,
        };
        unless (EBox::Validate::isValidRange($newRangeHash->{from}, $newRangeHash->{to})) {
            throw EBox::Exceptions::External(
                __x('{from} - {to} is an invalid range',
                    from => $newRangeHash->{from},
                    to => $$newRangeHash->{to},
                )
            );
        }

        my $parentId = $self->parentRow()->id();
        my $rangeId = exists $changedFields->{id} ? $changedFields->{id} : '';
        my $dir = $self->directory();
        try {
            $self->parentModule()->model('Connections')->l2tpCheckDuplicateIPRange($parentId, $rangeId, $from, $to);
        } catch {
        }
        $self->setDirectory($dir);


        my $network  = $global->modInstance('network');
        my $dhcp = undef;
        if ($global->modExists('dhcp') and $global->modInstance('dhcp')->isEnabled()) {
            $dhcp = $global->modInstance('dhcp');
        }

        # Check tunnel IP to be used for the VPN.
        my $ipsec = $self->parentModule();
        my $l2tp_settings = $ipsec->model('SettingsL2TP');
        my $localIP = $l2tp_settings->row()->elementByName('local_ip')->value();
        if ($localIP and EBox::Validate::isIPInRange($newRangeHash->{from}, $newRangeHash->{to}, $localIP)) {
            throw EBox::Exceptions::External(
                __x('Range {from}-{to} includes the tunnel IP address: {localIP}',
                    from => $newRangeHash->{from},
                    to => $newRangeHash->{to},
                    localIP => $localIP,
                )
            );
        }

        # Check all local networks configured on the server.
        my $localNetOverlaps = undef;
        foreach my $interface (@{$network->InternalIfaces()}) {
            my $internalRangeHash = {
                from => $network->netInitRange($interface),
                to => $network->netEndRange($interface),
            };
            if (EBox::Validate::isRangeOverlappingWithRange($newRangeHash, $internalRangeHash)) {
                $localNetOverlaps = 1;
            }

            if ($dhcp) {

                next if ($network->ifaceMethod($interface) ne 'static');

                my $fixedAddresses = $dhcp->fixedAddresses($interface, 0);

                foreach my $fixedAddr (@{$fixedAddresses}) {
                    if (EBox::Validate::isIPInRange($newRangeHash->{from}, $newRangeHash->{to}, $fixedAddr->{ip})) {
                        throw EBox::Exceptions::External(
                            __x('Range {from}-{to} includes fixed address from the object member "{name}": {fixedIP}',
                                from => $newRangeHash->{from},
                                to => $newRangeHash->{to},
                                name => $fixedAddr->{name},
                                fixedIP => $fixedAddr->{ip}
                            )
                        );
                    }
                }
            }
        }
        unless ($localNetOverlaps) {
            throw EBox::Exceptions::External(__('The defined range is not part of any local network'));
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

            my $existingRangeHash = {
                from => $row->valueByName('from'),
                to => $row->valueByName('to'),
            };
            if (EBox::Validate::isRangeOverlappingWithRange($newRangeHash, $existingRangeHash)) {
                throw EBox::Exceptions::External(
                    __x("Range {newFrom}-{newTo} overlaps with range '{range}': {oldFrom}-{oldTo}",
                        newFrom => $newRangeHash->{from},
                        newTo => $newRangeHash->{to},
                        range => $row->valueByName('name'),
                        oldFrom => $existingRangeHash->{from},
                        oldTo   => $existingRangeHash->{to},
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

sub rangeOverlaps
{
    my ($self, $range, $skipId) = @_;
    $skipId or $skipId = '';

    foreach my $id (@{ $self->ids() }) {
        if ($id eq $skipId) {
            next;
        }

        my $row = $self->row($id);
        my $rowRange = new Net::IP($row->valueByName('from') . '-' . $row->valueByName('to'));
        if (not $rowRange) {
            next;
        }
        if ($range->overlaps($rowRange)) {
            return 1;
        }
    }

    return 0;
}

1;
