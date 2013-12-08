# Copyright (C) 2012-2012 Zentyal S.L.
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

# Class: EBox::RemoteServices::Model::VPNConnectivityCheck
#
#       Run the VPN connectivity check
#

package EBox::RemoteServices::Model::VPNConnectivityCheck;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::RemoteServices::Connection;
use EBox::Types::Action;

# Method: precondition
#
#     Show only if the module has the VPN bundle
#
# Overrides:
#
#     <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    return ($self->parentModule()->hasBundle());
}

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $customActions = [
        new EBox::Types::Action(
            name => 'check',
            printableValue => __('VPN Connectivity Check'),
            model => $self,
            handler => \&_doVPNConnectivityCheck,
            message => __('The VPN server is reachable'),
        ),
    ];

    my $form = {
        tableName          => __PACKAGE__->nameFromClass(),
        modelDomain        => 'RemoteServices',
        printableTableName => __('Zentyal Remote VPN Connectivity Check'),
        defaultActions     => [],
        customActions      => $customActions,
        tableDescription   => [],
        help => __('It performs the required test to know if the VPN client is able to connect to the server'),
    };
    return $form;
}

sub _doVPNConnectivityCheck
{
    my ($self, $action, %params) = @_;

    my $conn = new EBox::RemoteServices::Connection();
    $conn->checkVPNConnectivity();
    $self->setMessage($action->message(), 'note');
}

1;
