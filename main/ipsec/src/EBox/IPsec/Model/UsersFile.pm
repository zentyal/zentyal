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

package EBox::IPsec::Model::UsersFile;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::IPAddr;
use EBox::Types::Password;

# Method: getUsers
#
#      Returns the enabled L2TP/IPSec users
#
# Returns:
#
#      array - to ref hash clients
#
sub getUsers
{
    my ($self) = @_;

    my @users = ();

    foreach my $id (@{$self->enabledRows()}) {

        my $row = $self->row($id);

        my %user = ();

        $user{'user'} = $row->valueByName('user');
        $user{'passwd'} = $row->valueByName('passwd');
        $user{'ipaddr'} = $row->printableValueByName('ipaddr');
        push (@users, \%user);
    }

    return \@users;
}

# TODO: Validate the static IP assignation. It should be part of one of the internal networks and it should not be
# already assigned to any pool of ips to be used by DHCP or xl2tpd itself.

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @fields = (
        new EBox::Types::Text(
            fieldName => 'user',
            printableName => __('User'),
            size => 12,
            unique => 1,
            editable => 1,
        ),
        new EBox::Types::Password(
            fieldName => 'passwd',
            printableName => __('Password'),
            editable => 1,
        ),
        new EBox::Types::IPAddr(
            fieldName => 'ipaddr',
            printableName => __('IP Address'),
            editable => 1,
            optional => 1,
            help => __('IP address assigned to this user within the VPN network.'),
        ),
    );

    my $dataTable = {
        tableName => 'UsersFile',
        printableTableName => __('L2TP/IPSec Users'),
        printableRowName => __('user'),
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@fields,
        class => 'dataTable',
        modelDomain => 'IPsec',
        enableProperty => 1,
        defaultEnabledValue => 1,
        help => __('Users allowed to connect using the L2TP/IPSec VPN. This list is independant of users defined on Users and Groups.'),
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

1;
