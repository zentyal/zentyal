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

use strict;
use warnings;

package EBox::Printers::Model::PrinterPermissions;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Union;
use EBox::Types::Select;
use EBox::Exceptions::DataExists;
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
    bless ($self, $class);

    return $self;
}

sub populateUser
{
    my $sambaMod = EBox::Global->modInstance('samba');
    my @users = ();
    my $list = $sambaMod->realUsers();
    foreach my $u (@{$list}) {
        my $v = {
            value => $u->sid(),
            printableValue => $u->name(),
        };
        push (@users, $v);
    }
    return \@users;
}

sub populateGroup
{
    my $userMod = EBox::Global->modInstance('samba');
    my @groups = ();
    my $list = $userMod->securityGroups();
    foreach my $g (@{$list}) {
        next if ($g->isInternal());
        my $v = {
            value => $g->sid(),
            printableValue => $g->name(),
        };
        push (@groups, $v);
    }
    return \@groups;
}

sub populatePermissions
{
    return [
            {
                value => 'print',
                printableValue => __('Print')
            },
           ];
}

# Method: validateTypedRow
#
#   Overrided because the 'unique' attribute of the Unique type does
#   not seem to work properly
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $params) = @_;

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
    $custom->setHTMLTitle(
        [
            {
                title => __('Printers'),
                link  => '/Printers/Composite/General#Printers',
            },
            {
                title => $self->parentRow()->valueByName('printer'),
                link  => ''
            }
        ]
    );
    if ($self->parentRow()->valueByName('guest')) {
        $custom->setPermanentMessage(
            __('Any access control is disabled if guest access is allowed.'));
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

    my @tableDesc = (
        new EBox::Types::Union(
            fieldName     => 'user_group',
            printableName => __('User/Group'),
            subtypes => [
                new EBox::Types::Select(
                    fieldName => 'user',
                    printableName => __('User'),
                    populate => \&populateUser,
                    disableCache => 1,
                    editable => 1),
                new EBox::Types::Select(
                    fieldName => 'group',
                    printableName => __('Group'),
                    populate => \&populateGroup,
                    disableCache => 1,
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
        ),
    );

    my $dataTable = {
        tableName          => 'PrinterPermissions',
        printableTableName => __('Access Control'),
        modelDomain        => 'Printers',
        menuNamespace      => 'Printers/View/Printers',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        class              => 'dataTable',
        help               => '',
        printableRowName   => __('ACL'),
        insertPosition     => 'back',
    };

    return $dataTable;
}

sub filterUserGroupPrintableValue
{
    my ($element) = @_;
    my $selectedType = $element->selectedType();
    my $value = $element->printableValue();
    if ($selectedType eq 'user') {
        return $value . __(' (user)')
    } elsif ($selectedType eq 'group') {
        return $value . __(' (group)')
    }

    return $value;
}

1;
