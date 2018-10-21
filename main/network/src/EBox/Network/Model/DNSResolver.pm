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

use strict;
use warnings;

# Class: EBox::Network::Model::DNSResolver
#
#   This model configures the DNS resolvers used by the system.
#
#   When the Zentyal DNS module is installed, configured and enabled, this
#   model is disabled as Zentyal is used as the unique nameserver.
#
#   Since Ubuntu 12.04 the resolvconf framework is used to configure the
#   DNS resolvers. The resolver configuration file (/etc/resolv.conf) is
#   now a symlink to /var/run/resolvconf/resolv.conf, and the last one is
#   generated dynamically based on the information in
#   /var/run/resolvconf/interface/*
#
#   The order the files in /var/run/resolvoconf are added to the dynamically
#   generated resolv.conf is defined by the file
#   /etc/resolvconf/interface-order
#
#   Resolvconf is run by network configurers, like ifup, ifdown, pppd,
#   dhclient and dnsmasq and provide to it nameserver information for each
#   interface. For example, dhclient receives one or more nameserver addresses
#   during its negotiation with the DHCP server; its hook script
#   /etc/dhcp/dhclient-enter-hooks.d/resolvconf pushes this information
#   to a new resolvconf interface file
#   (/var/run/resolvconf/interface/eth0.dhclient for example) and triggers a
#   resolvconf update.
#
#   The update process all nameservers information, stored in
#   /var/run/resolvconf/interface and order the nameservers and search
#   domains according to /etc/resolvconf/interface-order. Then the file
#   /var/run/resolvconf/resolv.conf is updated.

package EBox::Network::Model::DNSResolver;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::HostIP;
use EBox::Types::Text;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;
use TryCatch;

# Dependencies

# Group: Public methods

# Constructor: new
#
#   Create the new DNS resolver table
#
# Overrides:
#
#   <EBox::Model::DataTable::new>
#
# Returns:
#
#   <EBox::Network::Model::DNSResolver> - the newly created object instance
#
sub new
{
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);

    return $self;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#   <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $helpHostIP = __('IP address of the DNS server that Zentyal ' .
                        'will use to resolve names.');
    my $tableDesc = [
        new EBox::Types::HostIP(
            fieldName       => 'nameserver',
            printableName   => __('Domain Name Server'),
            editable        => 1,
            unique          => 1,
            help            => $helpHostIP),
        new EBox::Types::Text(
            fieldName       => 'interface',
            printableName   => __('Interface'),
            editable        => 0,
            optional        => 1,
            hidden          => 1),
    ];

    my $dataTable = {
        tableName          => 'DNSResolver',
        printableTableName => __('Domain Name Server Resolver List'),
        modelDomain        => 'Network',
        defaultActions     => [ 'add', 'del', 'move', 'editField', 'changeView' ],
        tableDescription   => $tableDesc,
        class              => 'dataTable',
        help               => $self->_help(),
        printableRowName   => __('name server'),
        order              => 1,
        insertPosition     => 'back',
    };

    return $dataTable;
}

# Method: _help
#
# Overrides:
#
#   <EBox::Model::DataTable::_help>
#
sub _help
{
    my ($self) = @_;

    return (__('<p>Here you can add the name server resolvers that Zentyal will ' .
               'use.</p>' .
               '<p>Note that these settings may be overriden if you have any ' .
               'network interface configured via DHCP</p>'));
}

# Method: addedRowNotify
#
#   This method is overrided to add the interface field, in case it is not
#   provided.
#
#   When a nameserver is added from the resolvconf update script
#   (/etc/resolvconf/update.d/zentyal-resolvconf), the interface field is
#   populated with the value used by the network configurer daemon
#   (ifup, ifdown, etc). Otherwise, we fill with the value "zentyal_<row id>"
#
# Overrides:
#
#   <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $newRow) = @_;

    my $interfaceElement = $newRow->elementByName('interface');
    my $interfaceValue = $interfaceElement->value();
    unless (defined $interfaceValue and length $interfaceValue) {
        my $rowId = $newRow->id();
        $interfaceElement->setValue("zentyal.$rowId");
        $newRow->store();
    }
}

sub addTypedRow
{
    my ($self, $paramsRef, %optParams) = @_;

    my $ns;
    if (exists $paramsRef->{nameserver}) {
        $ns = $paramsRef->{nameserver}->value();
    }

    my $iface;
    if (exists $paramsRef->{interface}) {
        $iface = $paramsRef->{interface}->value();
    }

    my $global = EBox::Global->getInstance($self->{confmodule}->{ro});
    my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
    foreach my $mod (@mods) {
        if ($mod->nameserverAdded($ns, $iface)) {
            throw EBox::Exceptions::UnwillingToPerform(
                reason => __x('This action is incompatible with the ' .
                              'module {mod} configuration',
                              mod  => $mod->name()));
        }
    }

    return $self->SUPER::addTypedRow($paramsRef, %optParams);
}

sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined ($id)) {
        throw EBox::Exceptions::MissingArgument(
                "Missing row identifier to remove");
    }
    if (not $force) {
        my $row = $self->row($id);
        unless (defined ($row)) {
            throw EBox::Exceptions::Internal("Invalid row id $id");
        }
        my $ns = $row->valueByName('nameserver');
        my $iface = $row->valueByName('interface');
        my $global = EBox::Global->getInstance($self->{confmodule}->{ro});
        my @mods = @{$global->modInstancesOfType('EBox::NetworkObserver')};
        foreach my $mod (@mods) {
            if ($mod->nameserverDelete($ns, $iface)) {
                throw EBox::Exceptions::DataInUse(
                __x(q|The nameserver '{name}' is being used by {mod}|,
                    name => $ns, mod  => $mod->name()));
            }
        }
    }

    $self->SUPER::removeRow($id, $force);
}

# Method: precondition
#
#   Check if the DNS module is installed and enabled. When this occurs, only
#   the local DNS server is used so this model has no sense.
#
# Overrides:
#
#   <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    if ($self->global->modExists('dns')) {
        my $dnsModule = $self->global->modInstance('dns');
        if ($dnsModule->configured() and $dnsModule->isEnabled()) {
            $self->{preconditionFail} = 'dnsModuleEnabled';
            return undef;
        }
    }

    return 1;
}

# Method: preconditionFailMsg
#
#   Show the precondition failure message
#
# Overrides:
#
#   <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    my $msg = __('Unknown');
    if ($self->{preconditionFail} eq 'dnsModuleEnabled') {
        $msg = __x('The Zentyal DNS module is installed and enabled, so only the local DNS server will be used to resolve the queries. ' .
                  'The queries for which this server is not authoritative and does not have the answer in its cache will be sent to ' .
                  'the {ohref}configured forwarders{chref} in first place, and if they does not answer the query root DNS servers will be used.',
                  ohref => '<a href="/DNS/Composite/Global">',
                  chref => '</a>');
    }
    return $msg;
}

# Method: getInterfaceResolvconfConfig
#
#   This method get the resolvconf configuration for a given interface.
#
# Returns:
#
#   A hash reference containing:
#       interface - The interface file
#       resolvers - An array reference containing the resolvers for this
#                   interface
#
sub getInterfaceResolvconfConfig
{
    my ($self, $file) = @_;

    my $entry = {
        interface => $file,
        resolvers => [],
    };

    # Change directory to /var/run/resolvconf/interface
    my $path = '/var/run/resolvconf/interface';
    unless (chdir $path) {
        EBox::warn("Failed to chdir to $path");
        return $entry;
    }

    my $fd;
    unless (open ($fd, $file)) {
        EBox::warn("Couldn't open $file");
        return $entry;
    }

    for my $line (<$fd>) {
        $line =~ s/^\s+//g;
        my @toks = split (/\s+/, $line);
        if ($toks[0] eq 'nameserver') {
            push (@{$entry->{resolvers}}, $toks[1]);
        }
    }
    close ($fd);

    return $entry;
}

# Method: importSystemResolvers
#
#   This method populate the model with the given resolvers list for the given interface.
#
sub importSystemResolvers
{
    my ($self, $interface, $resolvers) = @_;

    try {
        foreach my $nameserver (@{$resolvers}) {
            $self->addRow(interface => $interface, nameserver => $nameserver);
        }
    } catch ($error) {
        EBox::error("Could not import system resolvers: $error");
    }
    $self->table->{insertPosition} = 'back';
}

# Method: nameservers
#
#  Returns:
#
#   Array ref - each element contains a string holding the nameserver
#
sub nameservers
{
    my ($self) = @_;
    my $ids = $self->ids();

    my @nameservers = ();
    if (@{$ids}) {
        for my $id (@{$ids}) {
            if (defined $self->row($id)) {
                push (@nameservers, $self->row($id)->valueByName('nameserver'));
            }
        }
    }

    return \@nameservers;
}


1;
