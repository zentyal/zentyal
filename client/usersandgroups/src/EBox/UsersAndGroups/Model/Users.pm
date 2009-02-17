# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::UsersAndGroups::Model::Users;

# Class: EBox::UsersAndGroups::Model::Users
#
#       This a class used as a proxy for the users stored in LDAP.
#       It is meant to improve the user experience when managing users,
#       but it's just an interim solution. An integral approach needs to 
#       be done.
#       
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Model::Row;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;


use EBox::Types::Text;
use EBox::Types::Link;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead = 
        ( 

         new EBox::Types::Text(
             'fieldName' => 'name',
             'printableName' => __('Name'),
             'size' => '12',
             ),
         new EBox::Types::Text(
             'fieldName' => 'fullname',
             'printableName' => __('Full name'),
             'size' => '12',
             ),
         new EBox::Types::Link(
             'fieldName' => 'edit',
             'printableName' => __('Edit'),
             ),

        );

    my $dataTable = 
    { 
        'tableName' => 'Users',
        'printableTableName' => __('Users'),
        'defaultController' =>
            '/ebox/Users/Controller/Users',
        'defaultActions' =>
            ['changeView'],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'UsersAndGroups/Users',
        'help' => __x('Users'),
        'printableRowName' => __('user'),
        'sortedBy' => 'name',
    };

    return $dataTable;
}

# Method: precondition
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub precondition
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    unless ($users->configured()) {
        $self->{preconFail} = 'notConfigured';
        return undef;
    }

    unless (@{$self->ids()}) {
        $self->{preconFail} = 'noUsers';
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconFail} eq 'notConfigured') {
        return __('You must enable the module Users in the module ' .
                'status section in order to use it.');
    } else {
        return __('There are no users at the moment.');

    }
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return rows identifiers
#   based on the users stored in LDAP
#
sub ids
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    unless ($users->configured()) {
        return [];
    }

    return $users->uidList();
}

# Method: row
#
#   Override <EBox::Model::DataTable::row> to build and return a
#   row dependening on the user uid which is the id passwd.
#
sub row
{
    my ($self, $id) = @_;

    my $users = EBox::Global->modInstance('users');
    if ($users->userExists($id)) {
        my $userInfo  = $users->userInfo($id);
        my $userName = $userInfo->{'username'};
        my $full = $userInfo->{'fullname'};
        my $link = "/ebox/UsersAndGroups/User?username=$userName";
        my $row = $self->_setValueRow(name => $userName, 
                fullname => $full,
                'edit' => $link);
        $row->setId($id);
        $row->setReadOnly(1);
    } else {
        throw EBox::Exceptions::Internal("user $id does not exist");
    }
}

sub Viewer
{
    return '/ajax/tableBodyWithoutActions.mas';
}

1;
