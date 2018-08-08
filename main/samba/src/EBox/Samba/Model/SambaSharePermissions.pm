# Copyright (C) 2012-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::Samba::Model::SambaSharePermissions;

use base 'EBox::Model::DataTable';

use EBox::Exceptions::DataExists;
use EBox::Gettext;
use EBox::Global;
use EBox::Samba::Types::Select;
use EBox::View::Customizer;

# Dependencies
use TryCatch;

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
    my @users = ();
    my $samba = EBox::Global->modInstance('samba');
    return [] unless $samba->isRunning();
    my $list = $samba->realUsers(EBox::Config::boolean('allow_admin_user_in_shares_acl'));
    foreach my $u (@{$list}) {
        my $gr = {};
        $gr->{value} = $gr->{printableValue} = $u->name();
        push (@users, $gr);
    }
    return \@users;
}

sub populateGroup
{
    my @groups = ();
    my $samba = EBox::Global->modInstance('samba');
    return [] unless $samba->isRunning();
    my $domainUsersGroup = $samba->ldap->domainUsersGroup();
    my $domainUsersName = $domainUsersGroup->get('samAccountName');
    push (@groups, { value => $domainUsersName, printableValue => __('All domain users') });

    my $list = $samba->realGroups();
    foreach my $g (@{$list}) {
        my $gr = {};
        $gr->{value} = $gr->{printableValue} = $g->name();
        push (@groups, $gr);
    }
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

# Method: addedRowNotify
#
# Overrides:
#
#      <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $row) = @_;

    # Tag this share as needing a reset of rights.
    my $parentRow = $self->parentRow();
    $parentRow->model()->tagShareRightsReset($parentRow);
}

# Method: updatedRowNotify
#
# Overrides:
#
#      <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    if ($row->isEqualTo($oldRow)) {
        # no need to notify changes
        return;
    }

    # Tag this share as needing a reset of rights.
    my $parentRow = $self->parentRow();
    $parentRow->model()->tagShareRightsReset($parentRow);
}

# Method: deletedRowNotify
#
# Overrides:
#
#   <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row, $force) = @_;

    my $parentRow = $self->parentRow();
    $parentRow->model->tagShareRightsReset($parentRow);
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
                link  => '/Samba/Composite/FileSharing#SambaShares',
                },
                {
                title => $self->parentRow()->valueByName('share'),
                link  => ''
                }
        ]);
        if ($self->parentRow()->valueByName('guest')) {
            $custom->setPermanentMessage(
                __('Any access control is disabled if the guest access is allowed.')
               );
        } else {
            $custom->setPermanentMessage('');
        }

        return $custom;
}


sub precondition
{
    my ($self) = @_;

    my $samba = $self->parentModule();
    unless ($samba->configured()) {
        $self->{preconditionFail} = 'notConfigured';
        return undef;
    }
    unless ($samba->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
        return undef;
    }
    if (EBox::Config::boolean('unmanaged_acls')) {
        $self->{preconditionFail} = 'unmanagedAcl';
        return undef;
    }

    return 1;
}

sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notConfigured') {
        return __('You must enable the module in the module ' .
                'status section in order to use it.');
    }

    if ($self->{preconditionFail} eq 'notProvisioned') {
        return __('The domain has not been created yet.');
    }

    if ($self->{preconditionFail} eq 'unmanagedAcl') {
        return __x('Shares access control lists (ACLs) are in unmanaged ' .
                   'mode. To change this mode, edit {file} and restart ' .
                   'this module', file => '/etc/zentyal/samba.conf');
    }
    return undef;
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
                                filter => \&filterUserGroupPrintableValue,
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
              'User will be able to read and write any file in the share.');
}

sub filterUserGroupPrintableValue
{
    my ($element) = @_;

    my $selectedType = $element->selectedType();
    my $value = $element->value();

    if ($selectedType eq 'user') {
        return __x('User: {u}', u => $value);
    } elsif ($selectedType eq 'group') {
        return __x('Group: {g}', g => $value);
    }

    return $value;
}

1;
