# Copyright (C) 2008 Warp Networks S.L.
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

# Class: EBox::Samba::Model::SambaShareConfiguration
#
#  This model is used to configure permissions of each share
#  created in EBox::Samba::Model::SambaShares
#
package EBox::Samba::Model::SambaSharePermissions;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Samba::Types::Select;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the new Samba shares table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Samba::Model::SambaShareConfiguration> - the newly created object
#     instance
#
sub new
{

      my ($class, %opts) = @_;
      my $self = $class->SUPER::new(%opts);
      bless ( $self, $class);

      return $self;

}

sub populateUser
{
    my $userMod = EBox::Global->modInstance('users');
    my @users = map (
                {
                    value => $_->{uid}, 
                    printableValue => $_->{username}
                }, $userMod->users()
            );
    return \@users;
}

sub populateGroup
{
    my $userMod = EBox::Global->modInstance('users');
    my @groups = map ( 
                { 
                    value => $_->{gid}, 
                    printableValue => $_->{account}
                }, $userMod->groups()
            );
    return \@groups;
}


sub populatePermissions
{
    return [
            { 
                value => 'readOnly',
                printableValue => __('Read only')
            },
            { 
                value => 'readWrite',
                printableValue => __('Read and write')
            },
            { 
                value => 'administrator',
                printableValue => __('Administrator')
            }
           ];
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
       new EBox::Types::Union(
                               fieldName     => 'user_group',
                               printableName => __('User/Group'),
                               subtypes =>
                                [
                                    new EBox::Samba::Types::Select(
                                        fieldName => 'user',
                                        printableName => __('User'),
                                        populate => \&populateUser,
                                        editable => 1),
                                    new EBox::Samba::Types::Select(
                                        fieldName => 'group',
                                        printableName => __('Group'),
                                        populate => \&populateGroup,
                                        editable => 1)
                                ]
                              ),
       new EBox::Types::Select(
                               fieldName     => 'permissions',
                               printableName => __('Permissions'),
                               populate => \&populatePermissions,
                               editable => 1,
                               help => _permissionsHelp()
                              )
      );

    my $dataTable = {
                     tableName          => 'SambaSharePermissions',
                     printableTableName => __('Samba share configuration'),
                     modelDomain        => 'Samba',
                     menuNamespace      => 'Samba/View/SambaShares',
                     defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     class              => 'dataTable',
                     help               => '',
                     printableRowName   => __('share'),
                     insertPosition     => 'back',
                    };

      return $dataTable;
}

sub rows
{
    my ($self, $filter, $page) = @_;

    my $rows = $self->SUPER::rows($filter, $page);
    my $filteredRows = [];
    for my $row (@{$rows}) {
        my $userGroup = $row->printableValueByName('user_group');
        if (defined($userGroup) and length ($userGroup) > 0) {
            push (@{$filteredRows}, $row);
        } else {
            $self->removeRow($row->{id}, 1);
        }
    }
    return $filteredRows;
}

# Private methods
sub _permissionsHelp
{
    return __('Be careful if you grant <i>administrator</i> privileges.' .
              'User will be able to read and write any file in the share');
}
1;
