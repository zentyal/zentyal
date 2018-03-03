# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Network::Model::GatewayTable;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Types::Int;
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Text;
use EBox::Network::Types::Text::AutoReadOnly;
use EBox::Network::View::GatewayTableCustomizer;
use EBox::Sudo;

use Net::ARP;

use constant MAC_FETCH_TRIES => 3;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub weights
{
    my @options;
    for my $weight (1..15) {
        push @options, { 'value' => $weight,
                 'printableValue' => $weight};
    }
    return \@options;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $conf = $self->{'confmodule'};
    my $network = EBox::Global->modInstance('network');

    my %dynamicGws;

    my $state = $conf->get_state();

    foreach my $iface (@{$network->dhcpIfaces()}) {
        my $gw = $state->{dhcp}->{$iface}->{gateway};
        if ($gw) {
            $dynamicGws{$iface} = $gw;
        }
    }
    foreach my $iface (@{$network->pppIfaces()}) {
        my $addr = $state->{interfaces}->{$iface}->{ppp_addr};
        my $ppp_iface = $state->{interfaces}->{$iface}->{ppp_iface};
        if ($addr and $ppp_iface) {
            $dynamicGws{$iface} = "$ppp_iface/$addr";
        }
    }

    my %currentIfaces = map {
        my $rowId = $_;
        my $row = $self->row($rowId);
        if ($row) {
            ($row->valueByName('interface') => $rowId)
        } else {
            ()
        }
    } @{$currentRows};

    my $modified = 0;

    my @ifacesToAdd = grep { not exists $currentIfaces{$_} } keys %dynamicGws;
    my @ifacesToDel = grep { not exists $dynamicGws{$_} } keys %currentIfaces;
    my @ifacesToModify = grep { exists $dynamicGws{$_} } keys %currentIfaces;

    # If we are going to add new gateways and there is no previous default
    # set, we will set the first added one as default
    if (scalar (@ifacesToAdd) > 0) {
        my $needDefault = 1;
        foreach my $id (@{$currentRows}) {
            my $row = $self->row($id);
            if ($row->valueByName('default')) {
                $needDefault = 0;
                last;
            }
        }
        foreach my $iface (@ifacesToAdd) {
            my $method = $network->ifaceMethod($iface);
            $self->add(name => "$method-gw-$iface",
                       interface => $iface, ip => $dynamicGws{$iface},
                       default => $needDefault, auto => 1);
            $needDefault = 0;
            $modified = 1;
        }
    }

    foreach my $iface (@ifacesToModify) {
        my $row = $self->row($currentIfaces{$iface});

        next unless $row->valueByName('auto');

        my $ip = $row->elementByName('ip');
        my $newIP = $dynamicGws{$iface};

        my $oldIP = $ip->value();
        unless (defined ($oldIP) and ($newIP eq $oldIP)) {
            $ip->setValue($newIP);
            $row->storeElementByName('ip');

            $modified = 1;
        }
    }

    foreach my $iface (@ifacesToDel) {
        my $id = $currentIfaces{$iface};
        my $row = $self->row($id);

        next unless (defined ($row) and $row->valueByName('auto'));

        $self->removeRow($id, 1);

        $modified = 1;
    }

    return $modified;
}

sub _table
{
    my ($self) = @_;

    my @tableHead =
     (
        new EBox::Types::Boolean(
                    'fieldName' => 'auto',
                    'printableName' => __('Auto'),
                    'defaultValue' => 0,
                    'hidden' => 1
                      ),
        new EBox::Network::Types::Text::AutoReadOnly(
                    'fieldName' => 'name',
                    'printableName' => __('Name'),
                    'size' => '12',
                    'unique' => 1,
                    'editable' => 1
                      ),
        new EBox::Network::Types::Text::AutoReadOnly(
                    'fieldName' => 'ip',
                    'printableName' => __('IP address'),
                    'size' => '16',
                    'unique' => 0, # Uniqueness is checked in validateRow
                    'editable' => 1
                      ),
        new EBox::Types::Text(
                    'fieldName' => 'interface',
                    'printableName' => __('Interface'),
                    'editable' => 0,
                    'hiddenOnSetter' => 1,
                    'optional' => 1,
                    'help' => __('Interface connected to this gateway')
                ),
        new EBox::Types::Select(
                    'fieldName' => 'weight',
                    'printableName' => __('Weight'),
                    'defaultValue' => 1,
                    'size' => '2',
                    'populate' => \&weights,
                    'editable' => 1,
                    'help' => __('This field is only useful if you have ' .
                                 'more than one router and  the balance ' .
                                 'traffic feature is enabled.')
                ),
        new EBox::Types::Boolean(
                    'fieldName' => 'default',
                    'printableName' => __('Default'),
                    'size' => '1',
                    'editable' => 1,
                    'HTMLSetter' => '/network/booleanSetterDefaultGW.mas',
                    'HTMLViewer' => '/ajax/viewer/booleanViewer.mas',
                )
     );

    my $dataTable =
        {
            'tableName' => 'GatewayTable',
            'printableTableName' => __('Gateways List'),
            'automaticRemove' => 1,
            'enableProperty' => 1,
            'defaultEnabledValue' => 1,
            'defaultController' =>
                '/Network/Controller/GatewayTable',
            'defaultActions' =>
                [
                'add', 'del',
                'move',  'editField',
                'changeView'
                ],
            'tableDescription' => \@tableHead,
            'menuNamespace' => 'Network/View/GatewayTable',
            'class' => 'dataTable',
            'order' => 0,
            'help' => __x('You can add as many gateways as you want. This is very useful if you want to split your Internet traffic through several links. Note that if you configure interfaces as DHCP or PPPoE their gateways are added here automatically.'),
            'rowUnique' => 0,
            'printableRowName' => __('gateway'),
        };

    return $dataTable;
}

# Method: validateRow
#
#  Implementation note:
#  this is validateRow and not typedValidateRow because we dont want to execute
#  this when failover watcher do a $row->store() call, this could be also done
#  using the 'force' parameter but I want not to risk to break something in the ecent
#
#      Override <EBox::Model::DataTable::validateRow> method
#
sub validateRow
{
    my ($self, $action, %params) = @_;
    my $ip = $params{'ip'};
    my $currentRow = $self->row($params{'id'});
    my $auto = 0;
    my $oldIP = '';
    if ($currentRow) {
        $auto = $currentRow->valueByName('auto');
        $oldIP = $currentRow->valueByName('ip');
    }

    if (exists $params{name}) {
        $self->checkGWName($params{name});
    }

    # Do not check for valid IP in case of auto-added ifaces
    unless ($auto) {
        my $network = EBox::Global->modInstance('network');

        my $ifaceForAddress = $network->ifaceByAddress($ip);
        if ($ifaceForAddress) {
            throw EBox::Exceptions::External(__x(
                "Gateway address {ip} is already the address of the local interface {iface}",
                ip => $ip,
                iface => $ifaceForAddress
               ));
        }

        my $printableName = __('IP address');
        unless ($ip) {
            throw EBox::Exceptions::MissingArgument($printableName);
        }
        checkIP($ip, $printableName);

        # Check uniqueness
        if ($oldIP ne $ip) {
            if ($self->find('ip' => $ip)) {
                throw EBox::Exceptions::DataExists('data' => $printableName,
                                                   'value' => $ip);
            }
        }

        my $iface = $network->gatewayReachable($params{ip});
        if ($iface) {
            # Only check if gateway is reachable on static interfaces
            unless ($network->ifaceMethod($iface) eq 'static') {
                if ($action eq 'add') {
                    throw EBox::Exceptions::External(__('You can not manually add a gateway for DHCP or PPPoE interfaces'));
                } else {
                    throw EBox::Exceptions::External(__x("Gateway {gw} must be in the same network that a static interface. "
                                                          . "Currently it belongs to the network of {iface} which is not static",
                                                         gw => $ip, iface => $iface));
                }
            }
        } else {
            throw EBox::Exceptions::External(__x("Gateway {gw} not reachable", gw => $ip));
        }

        if (($action eq 'add') and ($self->size() == 0)) {
            if (not $params{default}) {
                throw EBox::Exceptions::External(__('Since you have not gateways you should add the first one as default'))
            }
        }
    }

    my $currentIsDefault = 0;
    if ($currentRow) {
        $currentIsDefault = $currentRow->valueByName('default');
    }

    if ($params{default}) {
        # remove existent default mark in other row if needed
        if (not $currentIsDefault) {
            my $defaultRow = $self->find('default' => 1);
            if ($defaultRow) {
                my $default = $defaultRow->elementByName('default');
                $default->setValue(undef);
                $defaultRow->storeElementByName('default');
            }
        }
    } elsif ($currentIsDefault) {
        throw EBox::Exceptions::External(__('You cannot remove the default attribute, if you want to change it assign it to another gaterway'));
    }
}

sub validateRowRemoval
{
    my ($self, $row, $force) = @_;
    if ( $row->valueByName('auto') and not $force) {
        throw EBox::Exceptions::External(__('Automatically added gateways can not be manually deleted'));
    }
}

# Method: addedRowNotify
#
# Overrides:
#
#      <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $row) = @_;

    if ($row->valueByName('default')) {
        my $network = $self->parentModule();
        $network->storeSelectedDefaultGateway($row->id());
    }
}

# Method: updatedRowNotify
#
# Overrides:
#
#   <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    return if ($force); # failover event can force changes

    my $network = $self->parentModule();
    my $id = $row->id();
    if ($row->valueByName('default')) {
        $network->storeSelectedDefaultGateway($id);
    } else {
        if ($id eq $network->selectedDefaultGateway()) {
            $network->storeSelectedDefaultGateway('');
        }
    }
}

# Method: deletedRowNotify
#
# Overrides:
#
#      <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row, $force) = @_;

    if ($row->valueByName('default')) {
        my $network = $self->parentModule();
        my $size = $self->size();
        if ($size == 0) {
            # no preferred gateway sicne there are not gws!
            $network->storeSelectedDefaultGateway('');
        } else {
            # choose another gw
            my $newDefaultRow = $self->find(enabled => 1);
            if (not $newDefaultRow) {
                # no enabled, gw choosing another
                my ($id) = @{ $self->ids() };
                $newDefaultRow = $self->row($id);
            }

            $newDefaultRow->elementByName('default')->setValue(1);
            $newDefaultRow->store(); # this does not upgrade preferred default gw
            $network->storeSelectedDefaultGateway($newDefaultRow->id());
        }
    }

}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::Network::View::GatewayTableCustomizer();
    $customizer->setModel($self);

    return $customizer;
}

# Returns default gateway
sub defaultGateway()
{
    my ($self) = @_;

    my $row = $self->find('default' => 1);
    if ($row) {
        return $row->valueByName('ip');
    } else {
        return undef;
    }
}

sub marksForRouters
{
    my ($self) = @_;

    my $ids = $self->ids();

    my $marks;
    my $i = 1;
    for my $id (@{$ids}) {
        $marks->{$id} = $i;
        $i++;
    }

    return $marks;
}

# Returns only enabled gateways
sub gateways
{
    my ($self) = @_;

    $self->_gateways(0);
}

# Returns all gateways
sub allGateways
{
    my ($self) = @_;

    $self->_gateways(1);
}

sub _gateways
{
    my ($self, $all) = @_;

    my @gateways;

    my $balanceModel = $self->parentModule()->model('BalanceGateways');
    my %balanceEnabled =
        map { $balanceModel->row($_)->valueByName('name') => 1 } @{$balanceModel->enabledRows()};

    foreach my $id (@{$all ? $self->ids() : $self->enabledRows()}) {
        my $gw = $self->row($id);
        my $name = $gw->valueByName('name');
        push (@gateways, {
                            id => $id,
                            auto => $gw->valueByName('auto'),
                            name => $name,
                            ip => $gw->valueByName('ip'),
                            weight => $gw->valueByName('weight'),
                            default => $gw->valueByName('default'),
                            interface => $gw->valueByName('interface'),
                            enabled => $gw->valueByName('enabled'),
                            balance => $balanceEnabled{$name},
                         });
    }

    return \@gateways;
}

sub gatewaysWithMac
{
    my ($self) = @_;

    my @gateways = @{$self->allGateways()};
    foreach my $gw (@gateways) {
        # Skip mac detection for auto-added gateways (dhcp and pppoe)
        if ($gw->{'auto'}) {
            $gw->{'mac'} = undef;
        } else {
            $gw->{'mac'} = _getRouterMac($gw->{'interface'}, $gw->{'ip'});
        }
    }

    return \@gateways;
}

# Get the router MAC by sending a ping to it and look for the MAC in
# the ARP table
sub _getRouterMac
{
    my ($macif, $ip) = @_;

    my $mac;
    for (0 .. MAC_FETCH_TRIES) {
        system("ping -c 1 -W 3 $ip  > /dev/null 2> /dev/null");
        $mac = Net::ARP::arp_lookup($macif, $ip);
        return $mac if ($mac ne '00:00:00:00:00:00');
    }
    return $mac;
}

# XXX fudge bz ModelManager does not delete gateway removal in tables AND we
# don't have a removeRowValidate method
# TODO improve this if ModelManager gets rewritten with that remove-check
# feature added
sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove");
    }
    if (not $force) {
        my $row = $self->row($id);
        $row or
            throw EBox::Exceptions::Internal("Invalid row id $id");
        my $gw = $row->valueByName('name');
        my $global = EBox::Global->getInstance($self->{confmodule}->{ro});
        my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
        foreach my $mod (@mods) {
            if ($mod->gatewayDelete($gw)) {
                throw EBox::Exceptions::DataInUse(
                __x(q|The gateway '{name}' is being used by {mod}|,
                    name => $gw,
                    mod  => $mod->name()
                   )
               );
            }
        }
    }

    $self->SUPER::removeRow($id, $force);
}

sub checkGWName
{
    my ($self, $name) = @_;

    if (($name =~ m/^-/) or ($name =~ m/-$/)) {
        throw EBox::Exceptions::InvalidData(
            data => __('Gateway name'),
            value => $name,
            advice => __(q{Gateways names cannot begin or end with '-'})

           );
    }

    unless ($name =~ m/^[a-z0-9\-]+$/) {
        throw EBox::Exceptions::InvalidData(
            data => __('Gateway name'),
            value => $name,
            advice => __(q{Gateways names can only be composed of lowercase ASCII english letters, digits and '-'}),

           );
    }
}

# Method: addTypedRow
#
#  Overriden to add interface parameter if needed
#
#  Overrids:
#    - EBox::DataTable::addTypedRow
sub addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;
    $paramsRef = $self->_autoDetectInterface($paramsRef);
    return $self->SUPER::addTypedRow($paramsRef, %optParams);
}

# Method: setTypedRow
#
#  Overriden to add interface parameter if needed
#
#  Overrids:
#    - EBox::DataTable::setTypedRow
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;
    my $currentRow =  $self->row($id);
    $paramsRef = $self->_autoDetectInterface($paramsRef, $currentRow);

    return $self->SUPER::setTypedRow($id, $paramsRef, %optParams);
}

sub _autoDetectInterface
{
    my ($self, $paramsRef, $currentRow) = @_;
    my $auto;
    if (exists $paramsRef->{auto}) {
        $auto = $paramsRef->{auto}->value();
    } elsif ($currentRow) {
        $auto = $currentRow->valueByName('auto');
    }

    if ($auto) {
        return $paramsRef;
    }

    my $ip;
    if (exists $paramsRef->{ip}) {
        $ip =  $paramsRef->{ip}->value();
    } elsif ($currentRow) {
        $ip = $currentRow->valueByName('ip');
    }
    if (not $ip) {
        throw EBox::Exceptions::DataMissing(data => $self->fieldHeader('ip')->printableName());
    }

    my $network = $self->parentModule();
    my $iface = $network->gatewayReachable($ip);
    if ($iface) {
        my $interfaceType = $self->fieldHeader('interface')->clone();
        $interfaceType->setValue($iface);
        $paramsRef->{interface} = $interfaceType;
    }
    return $paramsRef;
}

1;
