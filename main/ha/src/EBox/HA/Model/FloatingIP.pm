# Copyright (C) 2014 Zentyal S. L.
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

package EBox::HA::Model::FloatingIP;

# Class: EBox::HA::Model::FloatingIP
#
#     Model to manage the floating IP addresses from the cluster
#

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::HostIP;
use EBox::Types::Text;
use Net::IP;

use constant MIN_NAME_LENGTH => 5;
use constant MAX_NAME_LENGTH => 64;

# Group: Public methods

# Method: validateTypedRow
#
#   Override <EBox::Model::DataTable::validateTypedRow> method
#
sub validateTypedRow
{
    my ($self, $action, $oldParams, $newParams) = @_;

    my $name = $newParams->{'name'}->value();
    my $ip = $newParams->{'floating_ip'}->value();

    my $nameLength = length ($name);
    if ($nameLength > MAX_NAME_LENGTH) {
        throw EBox::Exceptions::External(__x('Name is too long. Maximum length is {max}.', max => MAX_NAME_LENGTH));
    }
    if ($nameLength < MIN_NAME_LENGTH) {
        throw EBox::Exceptions::External(__x('Name is too short. Minimum length is {min}.', min => MIN_NAME_LENGTH));
    }
    if ($name !~ m/^[a-zA-Z_0-9]+$/) {
        throw EBox::Exceptions::External(__('Name must only contain letters, numbers or underscores.'));
    }
    # Check DHCP and network for every interface
    my $network = $self->parentModule()->global()->modInstance('network');
    foreach my $iface (@{$network->InternalIfaces()}, @{$network->ExternalIfaces()}) {
        if (my $error_message = $self->_ipCollides($iface, $ip)) {
            throw EBox::Exceptions::External($error_message);
        }
    }
}

# Method: _ipCollides
#
# Returns a message if the given IP collides with an existing one
#   Otherwise it returns an empty string, with won't raise an exception
#
sub _ipCollides
{
    my ($self, $iface, $ip) = @_;

    my $ipCollisionReason = "";

    if ($self->_existsNetworkIpCollision($iface, $ip)) {
        $ipCollisionReason = __('There is a Network interface with the given IP address.');
    } elsif ($self->_existsDhcpFixedIpCollision($iface, $ip)) {
        $ipCollisionReason = __('There is a fixed DHCP object with the given IP address.');
    } elsif ($self->_existsDhcpRangesCollision($iface, $ip)) {
        $ipCollisionReason = __('There is a DHCP range that include the given IP address.');
    }

    return $ipCollisionReason;
}

sub _existsNetworkIpCollision
{
    my ($self, $iface, $ip) = @_;

    my $floatingIP = new Net::IP($ip);

    my $global = $self->global();
    my $network = $global->modInstance('network');
    my @netIPs = @{ $network->ifaceAddresses($iface) };

    foreach my $ifaceIP (@netIPs) {
        $ifaceIP = new Net::IP($ifaceIP->{address});
        if ($floatingIP->overlaps($ifaceIP) != $IP_NO_OVERLAP) {
            return 1;
        }
    }

    return 0;
}

sub _existsDhcpFixedIpCollision
{
    my ($self, $iface, $ip) = @_;

    my $global = $self->global();

    if ($global->modExists('dhcp') and $global->modInstance('dhcp')->isEnabled()) {
        # If the iface is not static we don't need any further checking
        my $network = $global->modInstance('network');
        if ($network->ifaceMethod($iface) ne 'static') {
            return 0;
        }

        my $dhcp = $global->modInstance('dhcp');
        my $floatingIP = new Net::IP($ip);

        my $fixedAddresses = $dhcp->fixedAddresses($iface, 0);
        foreach my $fixedAddr (@{$fixedAddresses}) {
            my $fixedIP = new Net::IP($fixedAddr->{ip});
            if ($floatingIP->overlaps($fixedIP) != $IP_NO_OVERLAP) {
                return 1;
            }
        }
    }

    return 0;
}

sub _existsDhcpRangesCollision
{
    my ($self, $iface, $ip) = @_;

    my $global = $self->global();

    if ($global->modExists('dhcp') and $global->modInstance('dhcp')->isEnabled()) {
        my $dhcp = $global->modInstance('dhcp');
        my $ranges = $dhcp->ranges($iface);

        my $floatingIP = new Net::IP($ip);

        foreach my $range (@{$ranges}) {
            my $from     = $range->{from};
            my $to       = $range->{to};
            my $range    = new Net::IP( $from . '-' . $to);
            if ($floatingIP->overlaps($range) != $IP_NO_OVERLAP) {
                return 1;
            }
        }
    }

    return 0;
}


# Group: Protected methods

# Method: _table
#
# Overrides:
#
#       <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;


    my @fields = (
        new EBox::Types::Text(
            fieldName       => 'name',
            printableName   => __('Name'),
            editable        => 1,
            unique          => 1,
            # TODO: Validate chars
        ),
        new EBox::Types::HostIP(
            fieldName       => 'floating_ip',
            printableName   => __('Floating IP Address'),
            editable        => 1,
            unique          => 1,
           )
       );

    my $dataTable =
    {
        tableName => 'FloatingIP',
        printableTableName => __('Floating IP addresses'),
        defaultActions => [ 'add', 'del', 'editField', 'changeView' ],
        modelDomain => 'HA',
        tableDescription => \@fields,
        printableRowName => __('floating IP address'),
        # help => __('Configure how this server will start a cluster or it will join to an existing one'),
    };

    return $dataTable;
}


1;
