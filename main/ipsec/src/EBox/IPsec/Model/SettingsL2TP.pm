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

package EBox::IPsec::Model::SettingsL2TP;

use base 'EBox::IPsec::Model::SettingsBase';

use EBox::Gettext;

use EBox::Types::HostIP;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Exceptions::External;

# Group: Public methods

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
    my ($self, $action, $changedFields) = @_;
    my $global = $self->global();

    shift @_;
    $self->SUPER::validateTypedRow(@_);

    my $network = $global->modInstance('network');
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
        my $ownId = exists $changedFields->{id} ?  $changedFields->{id} : '';
        $self->parentModule()->model('Connections')->l2tpCheckDuplicateLocalIP($ownId, $localIP);

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
        my $ipsec = $self->parentModule();
        my $rangeTable = $ipsec->model('RangeTable');
        foreach my $id (@{$rangeTable->ids()}) {
            my $row = $rangeTable->row($id);
            my $existingRangeHash = {
                from => $row->valueByName('from'),
                to => $row->valueByName('to'),
            };
            if (EBox::Validate::isIPInRange($existingRangeHash->{from}, $existingRangeHash->{to}, $localIP)) {
                throw EBox::Exceptions::External(
                    __x('Range {from}-{to} ({name}) includes the selected tunnel IP address: {localIP}',
                        from => $existingRangeHash->{from},
                        to => $existingRangeHash->{to},
                        name => $row->valueByName('name'),
                        localIP => $localIP,
                    )
                );
            }
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

    shift @_;
    my $dataTable = $self->SUPER::_table(@_);

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
    if ($global->modExists('samba') and $global->modInstance('samba')->isEnabled()) {
        push (@winsSubtypes,
            new EBox::Types::Union::Text(
                fieldName => 'zentyal_wins',
                printableName => __('local Zentyal')
            )
        );
    }
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

    push (@{$dataTable->{tableDescription}},
        new EBox::Types::HostIP(
            fieldName => 'local_ip',
            printableName => __('Tunnel IP'),
            editable => 1,
            help => __('The IP to use for the VPN tunnel on the server side. It must be a free IP belonging to the ' .
                       'local network where the VPN clients will be connected.'),
        )
    );

    push (@{$dataTable->{tableDescription}},
        new EBox::Types::Union(
            fieldName  => 'primary_ns',
            printableName => __('Primary nameserver'),
            editable => 1,
            subtypes => \@primaryNSSubtypes,
            help => __('If "Zentyal DNS" is present and selected, the Zentyal server will act as cache DNS server'),
        )
    );
    push (@{$dataTable->{tableDescription}},
        new EBox::Types::HostIP(
            fieldName => 'secondary_ns',
            printableName => __('Secondary nameserver'),
            editable => 1,
            optional => 1,
        )
    );
    push (@{$dataTable->{tableDescription}},
        new EBox::Types::Union(
            fieldName => 'wins_server',
            printableName => __('WINS server'),
            editable => 1,
            subtypes => \@winsSubtypes,
            help => __('If "Zentyal Samba" is present and selected, Zentyal will be the WINS server for L2TP clients'),
        )
    );

    $dataTable->{tableName} = 'SettingsL2TP';

    return $dataTable;
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


1;
