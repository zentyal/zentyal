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

package EBox::PPTP::Model::Users;

use base 'EBox::Model::DataTable';

# Class: EBox::PPTP::Model::Users
#
#   TODO: Document class
#

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::IPAddr;
use EBox::Types::Password;

# Group: Public methods

# Constructor: new
#
#       Create the new Users model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::PPTP::Model::Users> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);

    return $self;
}

# Method: getUsers
#
#      Returns the enabled PPTP users
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

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
        (
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

    my $dataTable =
    {
        tableName => 'Users',
        printableTableName => __('PPTP Users'),
        printableRowName => __('user'),
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        class => 'dataTable',
        modelDomain => 'PPTP',
        enableProperty => 1,
        defaultEnabledValue => 1,
        help => __('Users allowed to connect using the PPTP VPN. This list is independant of LDAP users defined on Users and Groups.'),
    };

    return $dataTable;
}

1;
