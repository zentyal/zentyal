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

package EBox::IPsec::Model::SettingsBase;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Host;
use EBox::Types::Password;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Validate;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

# Group: Public methods

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;
    my $network = $self->global()->modInstance('network');

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    my $leftIPAddr = $self->row()->elementByName('left_ipaddr')->value();
    if ($leftIPAddr) {
        my $interface = $network->ifaceByAddress($leftIPAddr);

        if ($interface) {
            if ($network->ifaceMethod($interface) ne 'static') {
                $customizer->setPermanentMessage(__(
                    'You are using a non fixed IP address as a VPN server address. If the IP changes it may break the ' .
                    'VPN server!'), 'warning');
            }
        } else {
            $customizer->setPermanentMessage(
                __x('The server IP changed and the old value "{oldIP}" is not valid anymore.', oldIP => $leftIPAddr),
                'error');
        }
    } else {
        $customizer->setPermanentMessage(
            __x('Your system is not correctly configured. We were not able to find any valid public IP address.'),
            'error');
    }
    return $customizer;
}

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
    my ($self, $action, $changedFields, $allFields) = @_;
    my $networkMod = $self->global()->modInstance('network');
    my $rightIP = undef;

    if (!defined $allFields->{right}) {
        throw EBox::Exceptions::InvalidData(
            data => __("Remote Address"),
            value => __("undefined"),
            advice => __("Must be the external IP to connect but it's not defined"),
        );
    }

    if ($allFields->{right}->selectedType() eq 'right_ipaddr') {
        $rightIP = $allFields->{right}->value();
        if ($rightIP eq $allFields->{left_ipaddr}->value()) {
            throw EBox::Exceptions::External("Local and remote subnets could not be the same");
        }

        if (defined $rightIP) {
            my $iface = $networkMod->ifaceByAddress($rightIP);
            if ($iface) {
                throw EBox::Exceptions::InvalidData(
                    data => $allFields->{right}->printableName(),
                    value => $rightIP,
                    advice => __x(
                        'Must be the external IP to connect and it was the addresss of local interface {if}',
                        if => $iface
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
            disableCache => 1,
            populate => \&_populatePublicIPs,
            help => __('Zentyal public IP address where clients will connect to.'),
        ),
        new EBox::Types::Union(
            fieldName => 'right',
            printableName => __('Remote Address'),
            editable => 1,
            subtypes => [
                new EBox::Types::Union::Text(
                    fieldName => 'right_any',
                    printableName => __('Any address'),
                ),
                new EBox::Types::Host(
                    fieldName => 'right_ipaddr',
                    printableName => __('IP Address'),
                    editable => 1,
                    help => __('Remote endpoint public IP address.'),
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

sub checkConfigurationIsComplete
{
    my ($self) = @_;
    my @fields = @{ $self->table()->{tableDescription} };
    foreach my $field (@fields) {
        if ($field->optional()) {
            next;
        }
        if (not $self->value($field->fieldName())) {
            throw EBox::Exceptions::External(
                __x('Configuration no complete, {field} not set',
                     field => $field->printableName()
                    )
               );
        }
    }
}

1;
