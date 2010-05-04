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
use EBox::Exceptions::DataExists;
use EBox::Gettext;
use EBox::Global;
use EBox::Samba::Types::Select;
use EBox::View::Customizer;

# Dependencies
use Error qw(:try);

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
                    printableValue => $_->{user}
                }, @{$userMod->usersList()}
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

sub validateTypedRow
{
    my ($self, $action, $params) = @_;
    # we check that user_group is unique here bz union does nto seem to work
    my $user_group = $params->{user_group};
    if (not defined $user_group) {
        return;
    }

    my $selected = $user_group->selectedType();
    my $value    = $user_group->value();
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $rowUserGroup  =$row->elementByName('user_group');
        if ($value ne $rowUserGroup->value()) {
            next;
        }
        if ($selected eq $rowUserGroup->selectedType()) {
            throw EBox::Exceptions::DataExists(
                'data'  =>  __('User/Group'),
                'value' => "$selected/$value",
               );
        }
    }
}

sub syncRows
{
    my ($self, $currentIds) = @_;

    my $anyChange = undef;
    for my $id (@{$currentIds}) {
        my $userGroup = $self->row($id)->printableValueByName('user_group');
        unless(defined($userGroup) and length ($userGroup) > 0) {
            $self->removeRow($id, 1);
            $anyChange = 1;
        }
    }
    return $anyChange;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to provide a
#   custom HTML title with breadcrumbs and to warn the user about the
#   usage of this is only useful if the share does not allow guest
#   access
#
# Overrides:
#
#     <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
        my ($self) = @_;

        my $custom =  $self->SUPER::viewCustomizer();
        $custom->setHTMLTitle([
                {
                title => __('Shares'),
                link  => '/ebox/Samba/Composite/General#SambaShares',
                },
                {
                title => $self->parentRow()->valueByName('share'),
                link  => ''
                }
        ]);
        if ($self->parentRow()->valueByName('guest')) {
            $custom->setPermanentMessage(
                __('Any access control is disabled if the guest access is allowed')
               );
        } else {
            $custom->setPermanentMessage('');
        }

        return $custom;
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
                                ],
                                unique => 1,
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
                     printableTableName => __('Access Control'),
                     modelDomain        => 'Samba',
                     menuNamespace      => 'Samba/View/SambaShares',
                     defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     class              => 'dataTable',
                     help               => '',
                     printableRowName   => __('ACL'),
                     insertPosition     => 'back',

                    };

      return $dataTable;
}



# Private methods
sub _permissionsHelp
{
    return __('Be careful if you grant <i>administrator</i> privileges.' .
              'User will be able to read and write any file in the share');
}

1;
