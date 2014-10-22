# Copyright (C) 2013 Zentyal S.L.
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

package EBox::L2TP::Model::ConnectionSettings;

use base 'EBox::Model::DataForm';

use EBox::Gettext;

use EBox::Types::Host;
use EBox::Types::Password;
use EBox::Types::HostIP;
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

    $customizer->setHTMLTitle([
            {
            title => __('Connections'),
            link  => '/L2TP/View/Connections',
            },
            {
            title => $self->parentRow()->valueByName('name'),
            link  => ''
            }
    ]);

    return $customizer;
}

# Method: nameServer
#
#     Get the primary or secondary nameserver for this options interface
#
# Parameters:
#
#     number - Int 1 or 2
#
# Returns:
#
#     String - the current nameserver IP if any, otherwise undef
#
sub nameServer
{
    my ($self, $number) = @_;

    my $row = $self->row();

    my $selectedType;
    if ( $number == 1 ) {
        $selectedType = $row->elementByName('primary_ns')->selectedType();
        if ($selectedType eq 'none') {
            return undef;
        } elsif ($selectedType eq 'zentyal_ns') {
            my $network = $self->global()->modInstance('network');
            my $localIP = $row->elementByName('local_ip')->value();
            if ($localIP) {
                my $ifaceAddr = $network->localGatewayIP($localIP);
                return $ifaceAddr;
            } else {
                # There is no way to get the correct ns value.
                return undef;
            }
        } else {
            return $row->elementByName('primary_ns')->subtype()->value();
        }
    } else {
            return $row->printableValueByName('secondary_ns');
    }
}

# Method: winsServer
#
#     Get the wins server
#
# Returns:
#
#     String - the current wins server IP if any, otherwise undef
#
sub winsServer
{
    my ($self) = @_;

    my $row = $self->row();

    my $selectedType;
    $selectedType = $row->elementByName('wins_server')->selectedType();
    if ($selectedType eq 'none') {
        return undef;
    } elsif ($selectedType eq 'zentyal_wins') {
        my $network = $self->global()->modInstance('network');
        my $localIP = $row->elementByName('local_ip')->value();
        if ($localIP) {
            my $ifaceAddr = $network->localGatewayIP($row->elementByName('local_ip')->value());
            return $ifaceAddr;
        } else {
            # There is no way to get the correct ns value.
            return undef;
        }
    } else {
        return $row->elementByName('wins_server')->subtype()->value();
    }
}

# Method: validateTypedRow
#
#      Check the row to add or update if contains a valid configuration.
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the configuration is not valid.
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    my $global = $self->global();
    my $network = $global->modInstance('network');
    my $rightIP = undef;

    unless (defined $allFields->{right}) {
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
            my $iface = $network->ifaceByAddress($rightIP);
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
    }

    my $dhcp = undef;
    if ($global->modExists('dhcp') and $global->modInstance('dhcp')->isEnabled()) {
        $dhcp = $global->modInstance('dhcp');
    }

    if (exists $changedFields->{local_ip}) {
        # Check all local networks configured on the server.
        my $localIP = $changedFields->{local_ip}->value();
        unless ($localIP) {
            throw EBox::Exceptions::External('The Tunnel IP cannot be empty');
        }

        my $localIPRangeFound = undef;
        foreach my $interface (@{$network->InternalIfaces()}) {
            if (EBox::Validate::isIPInRange(
                $network->netInitRange($interface), $network->netEndRange($interface), $localIP)) {
                $localIPRangeFound = 1;
            }
            if ($network->ifaceAddress($interface) eq $localIP) {
                throw EBox::Exceptions::External(
                    __x('The Tunnel IP {localIP} is already used as a fixed address for the interface "{interface}"',
                        localIP => $localIP,
                        interface => $interface
                    )
                );
            }

            if ($dhcp) {
                next if ($network->ifaceMethod($interface) ne 'static');

                my $fixedAddresses = $dhcp->fixedAddresses($interface, 0);

                foreach my $fixedAddr (@{$fixedAddresses}) {
                    if ($fixedAddr->{ip} eq $localIP) {
                        throw EBox::Exceptions::External(
                            __x('The Tunnel IP {localIP} is already used as a fixed address from the object member ' .
                                '"{name}": {fixedIP}',
                                localIP => $localIP,
                                name => $fixedAddr->{name},
                                fixedIP => $fixedAddr->{ip}
                            )
                        );
                    }
                }
            }
        }
        unless ($localIPRangeFound) {
            throw EBox::Exceptions::External(
                __x('The Tunnel IP {localIP} is not part of any local network',
                    localIP => $localIP,
                )
            );
        }

        # Check tunnel IP to be used for the VPN.
        my $from = $allFields->{from}->value();
        my $to   = $allFields->{to}->value();
        if (EBox::Validate::isIPInRange($from, $to, $localIP)) {
            throw EBox::Exceptions::External(
                __x('Range {from}-{to} includes the selected tunnel IP address: {localIP}',
                    from => $from,
                    to => $to,
                    localIP => $localIP,
                )
            );
        }
    }

    if (exists $changedFields->{primary_ns}) {
        if ($changedFields->{primary_ns}->selectedType() eq 'zentyal_ns') {
            my $dns = $global->modInstance('dns');
            unless ($dns->isEnabled()) {
                throw EBox::Exceptions::External(
                    __('DNS module must be enabled to be able to select Zentyal as primary DNS server'));
            }
        }
    }

    if (exists $changedFields->{wins_server}) {
        if ($changedFields->{wins_server}->selectedType() eq 'zentyal_wins') {
            my $usersMod = $global->modInstance('samba');
            unless ($usersMod->isEnabled()) {
                throw EBox::Exceptions::External(
                    __('Samba module must be enabled to be able to select Zentyal as WINS server')
                   );
            }
        }
    }
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;
    my $global = $self->global();

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
        new EBox::Types::HostIP(
            fieldName     => 'from',
            printableName => __('Range start'),
            unique        => 1,
            editable      => 1,
        ),
        new EBox::Types::HostIP(
            fieldName     => 'to',
            printableName => __('Range end'),
            unique        => 1,
            editable      => 1,
        ),
    );


    my @primaryNSSubtypes = ();
    if ($global->modExists('dns') and $global->modInstance('dns')->isEnabled()) {
        push (@primaryNSSubtypes,
            new EBox::Types::Union::Text(
                fieldName => 'zentyal_ns',
                printableName => __('local Zentyal DNS'),
            )
        );
    }
    push (@primaryNSSubtypes,
        new EBox::Types::HostIP(
            fieldName     => 'custom_ns',
            printableName => __('Custom'),
            editable      => 1,
            defaultValue  => $self->_fetchPrimaryNS(),
        ),
        new EBox::Types::Union::Text(
            fieldName => 'none',
            printableName => __('None'),
        )
    );

    my @winsSubtypes = ();
    push (@winsSubtypes,
        new EBox::Types::Union::Text(
            fieldName => 'zentyal_wins',
            printableName => __('local Zentyal')
        )
    );
    push (@winsSubtypes,
        new EBox::Types::Union::Text(
            fieldName => 'none',
            printableName => __('None')
        ),
        new EBox::Types::HostIP(
            fieldName => 'custom_wins',
            printableName => __('Custom'),
            editable      => 1
        )
    );

    push (@fields,
        new EBox::Types::HostIP(
            fieldName => 'local_ip',
            printableName => __('Tunnel IP'),
            editable => 1,
            help => __('The IP to use for the VPN tunnel on the server side. It must be a free IP belonging to the ' .
                       'local network where the VPN clients will be connected.'),
        )
    );

    push (@fields,
        new EBox::Types::Union(
            fieldName  => 'primary_ns',
            printableName => __('Primary nameserver'),
            editable => 1,
            subtypes => \@primaryNSSubtypes,
            help => __('If "Zentyal DNS" is present and selected, the Zentyal server will act as cache DNS server'),
        )
    );
    push (@fields,
        new EBox::Types::HostIP(
            fieldName => 'secondary_ns',
            printableName => __('Secondary nameserver'),
            editable => 1,
            optional => 1,
        )
    );
    push (@fields,
        new EBox::Types::Union(
            fieldName => 'wins_server',
            printableName => __('WINS server'),
            editable => 1,
            subtypes => \@winsSubtypes,
            help => __('If "Zentyal Samba" is present and selected, Zentyal will be the WINS server for L2TP clients'),
        )
    );

    my $dataTable = {
        tableName => 'ConnectionSettings',
        disableAutocomplete => 1,
        printableTableName => __('General'),
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => \@fields,
        modelDomain => 'L2TP',
    };

    return $dataTable;
}

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


# Method: _fetchPrimaryNS
#
#      Fetch primary  nameserver from Network module
#
sub _fetchPrimaryNS
{
    my ($self) = @_;

    my $network = $self->global()->modInstance('network');

    my $nsOne = $network->nameserverOne();
    ($nsOne) or return undef;
    return $nsOne;
}

# Method: _fetchSecondaryNS
#
#      Fetch secondary nameserver from Network module
#
sub _fetchSecondaryNS
{
    my ($self) = @_;

    my $network = $self->global()->modInstance('network');

    my $nsTwo = $network->nameserverTwo();
    ($nsTwo) or return undef;
    return $nsTwo;
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
