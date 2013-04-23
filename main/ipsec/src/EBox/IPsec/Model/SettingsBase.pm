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
package EBox::IPsec::Model::SettingsBase;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Host;
use EBox::Types::Password;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;

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
    my $networkMod = $self->global()->modInstance('network');
    my $rightIP = undef;

    if ($all_r->{right}->selectedType() eq 'right_ipaddr') {
        $rightIP = $all_r->{right}->value();
        if ($rightIP eq $all_r->{left_ipaddr}->value()) {
            throw EBox::Exceptions::External("Local and remote subnets could not be the same");
        }
    }

    foreach my $iface ( @{ $networkMod->allIfaces() }) {
        foreach my $addr_hash (@{ $networkMod->ifaceAddresses($iface) }) {
            my $addr = $addr_hash->{address};
            my $netmask = $addr_hash->{netmask};
            if ((defined $rightIP) and ($addr eq $rightIP)) {
                my $ifname = exists $addr_hash->{name} ? $addr_hash->{name} : $iface;
                throw EBox::Exceptions::InvalidData(
                    data => $all_r->{right}->printableName(),
                    value => $rightIP,
                    advice => __x(
                        'Must be the external IP to connect and it was the addresss of local interface {if}',
                        if => $ifname
                    ),
                );
            }
         }
     }

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataForm::_table>
#
sub _table
{
    my @fields = (
        new EBox::Types::Select(
            fieldName => 'left_ipaddr',
            printableName => __('Public IP address'),
            editable => 1,
            populate => \&_populatePublicIPs,
            help => __('Zentyal public IP address where clients will connect to.'),
        ),
        new EBox::Types::Union(
            fieldName => 'right',
            printableName => __('Remote Address'),
            editable => 1,
            subtypes => [
                new EBox::Types::Host(
                    fieldName => 'right_ipaddr',
                    printableName => __('IP Address'),
                    editable => 1,
                    help => __('Remote endpoint public IP address.'),
                ),
                new EBox::Types::Union::Text(
                    fieldName => 'right_any',
                    printableName => __('Any address'),
                ),
            ]
        ),
        new EBox::Types::Password(
            fieldName => 'secret',
            printableName => __('PSK Shared Secret'),
            editable => 1,
            help => __('Pre-shared key for the IPsec connection.'),
        ),
    );

    my $dataTable = {
        tableName => 'SettingsBase',
        disableAutocomplete => 1,
        printableTableName => __('General'),
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => \@fields,
        modelDomain => 'IPsec',
    };

    return $dataTable;
}

# Group: Private methods

# Method: _populatePublicIPs
#
#      Populate the select widget with all available public IPs for this server.
#
sub _populatePublicIPs
{
    my ($self) = @_;

    my $network = $self->global()->modInstance('network');
    my $externalIPAddresses = $network->externalIpAddresses();
    my @opts = ();

    foreach my $ipaddress (@{$externalIPAddresses}) {
        push (@opts, { value => $ipaddress, printableValue => $ipaddress });
    }

    return \@opts;
}

1;
