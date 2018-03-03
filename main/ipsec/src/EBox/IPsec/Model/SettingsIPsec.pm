# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::IPsec::Model::SettingsIPsec;

use base 'EBox::IPsec::Model::SettingsBase';

use EBox::Gettext;
use EBox::Types::IPAddr;
use EBox::NetWrappers;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

# Group: Public methods
#
# Method: validateTypedRow
#
#      Check the row to add or update if contains a valid configuration.
#
# Overrides:
#
#      <EBox::Model::DataForm::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the configuration is not valid.
#
sub validateTypedRow
{
    my ($self, $action, $changed_r, $all_r) = @_;

    shift @_;
    $self->SUPER::validateTypedRow(@_);

    my $networkMod = $self->global()->modInstance('network');
    my $rightIP = undef;

    if ($all_r->{left_subnet}->printableValue() eq $all_r->{right_subnet}->printableValue()) {
        throw EBox::Exceptions::External("Local and remote subnets could not be the same");
    }

    my %localNets;
    foreach my $iface ( @{ $networkMod->allIfaces() }) {
        foreach my $addr_hash (@{ $networkMod->ifaceAddresses($iface) }) {
            my $addr = $addr_hash->{address};
            my $netmask = $addr_hash->{netmask};
            my $net = EBox::NetWrappers::ip_network($addr, $netmask);

            $localNets{$net} = 1;
         }
     }

    my %localRoutes = map {
        my ($net) = split '/', $_->{network}, 2;
        ($net => 1)
    } @{ $networkMod->routes()  };

    my $externalSubnet = $all_r->{right_subnet}->ip();
    if ($localNets{$externalSubnet}) {
        throw EBox::Exceptions::InvalidData(
            data => => $all_r->{right_subnet}->printableName(),
            value => $externalSubnet,
            advice => __('This is a local network, thus already accessible through local interfaces')
        );
    } elsif ($localRoutes{$externalSubnet}) {
        throw EBox::Exceptions::InvalidData(
            data => $all_r->{right_subnet}->printableName(),
            value => $externalSubnet,
            advice => __('This network is already reachable through a static route')
        );
    }
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my $dataTable = $self->SUPER::_table(@_);

    while (my ($index, $element) = each @{$dataTable->{tableDescription}}) {
        my $field = undef;

        if ($element->{fieldName} eq 'left_ipaddr') {
            $field = new EBox::Types::IPAddr(
                fieldName => 'left_subnet',
                printableName => __('Local Subnet'),
                editable => 1,
                help => __('Local subnet available through the tunnel.'),
            );

        } elsif ($element->{fieldName} eq 'right') {
            $field = new EBox::Types::IPAddr(
                fieldName => 'right_subnet',
                printableName => __('Remote Subnet'),
                editable => 1,
                help => __('Remote subnet available through the tunnel.'),
            );
        }

        if ($field) {
            splice @{$dataTable->{tableDescription}}, ($index + 1), 0, $field;
        }
    }

    $dataTable->{tableName} = 'SettingsIPsec';

    return $dataTable;
}

1;
