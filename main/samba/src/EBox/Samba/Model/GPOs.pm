# Copyright (C) 2013-2014 Zentyal S.L.
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

package EBox::Samba::Model::GPOs;

# Class: EBox::Samba::Model::GPOs
#
#     Manage the GPOs from Samba LDB. The changes are applied
#     inmmediately.
#

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Types::Select;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Samba::GPO;
use EBox::Samba::GPOIdMapper;

# Method: _table
#
# Overrides:
#
#   <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableDesc = [
        new EBox::Types::Text(fieldName     => 'name',
                              printableName => __('Name'),
                              unique        => 1,
                              editable      => 1),
        new EBox::Types::Select(fieldName     => 'status',
                                printableName => __('Status'),
                                editable      => 1,
                                populate      => \&_populateStatus),
        new EBox::Types::HasMany(fieldName  => 'edit',
                                 printableName => __('GPO Editor'),
                                 foreignModel => 'samba/GPO',
                                 foreignModelIsComposite => 1,
                                 view => '/Samba/Composite/GPO',
                                 backView => '/Samba/View/GPOs')
    ];

    my $dataTable = {
        printableTableName  => __('Group Policy Objects'),
        tableName           => 'GPOs',
        defaultActions      => ['add', 'del', 'editField', 'changeView'],
        tableDescription    => $tableDesc,
        printableRowName    => __('group policy object'),
        sortedBy            => 'name',
        modelDomain         => 'Samba',
    };

    return $dataTable;
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return rows identifiers
#   based on the GPOs stored in LDAP
#
sub ids
{
    my ($self) = @_;

    my $samba = $self->parentModule();
    unless ($samba->configured() and $samba->isProvisioned()) {
        return [];
    }

    my @list = map { EBox::Samba::GPOIdMapper::dnToId($_->dn()) } @{$samba->gpos()};

    return \@list;
}

# Method: row
#
#   Override <EBox::Model::DataTable::row> to build and return a
#   row dependening on the gpo dn which is the id passwd.
#
sub row
{
    my ($self, $id) = @_;

    my $dn = EBox::Samba::GPOIdMapper::idToDn($id);

    my $gpo = new EBox::Samba::GPO(dn => $dn);
    if ($gpo->exists()) {
        my $displayName = $gpo->get('displayName');
        my $status = $gpo->status();
        my $row = $self->_setValueRow(
            name => $displayName,
            status => $status,
        );
        $row->setId($id);
        if ($gpo->isCritical()) {
            # Cache the attribute in the row to disallow row
            # deletion
            $row->{isCriticalSystemObject} = 1;
        }
        return $row;
    }

    return undef;
}

sub _populateStatus
{
    my $status = [];
    push (@{$status}, {value => EBox::Samba::GPO::STATUS_ENABLED, printableValue => __('Enabled')});
    push (@{$status}, {value => EBox::Samba::GPO::STATUS_USER_CONF_DISABLED, printableValue => __('User configuration disabled')});
    push (@{$status}, {value => EBox::Samba::GPO::STATUS_COMPUTER_CONF_DISABLED, printableValue => __('Computer configuration disabled')});
    push (@{$status}, {value => EBox::Samba::GPO::STATUS_ALL_DISABLED, printableValue => __('All settings disabled')});
    return $status;
}

# Method: addTypedRow
#
# Overrides:
#
#   <EBox::Model::DataTable::addTypedRow>
#
sub addTypedRow
{
    my ($self, $params_r, %optParams) = @_;

    # Check compulsory fields
    $self->_checkCompulsoryFields($params_r);

    my $name = $params_r->{name}->value();
    my $status = $params_r->{status}->value();

    my $gpo = EBox::Samba::GPO->create($name, $status);
    $self->setMessage(__('GPO successfully created'));

    # Return the ID of the added row
    return EBox::Samba::GPOIdMapper::dnToId($gpo->dn());
}

sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined $id) {
        throw EBox::Exceptions::MissingArgument(
            "Missing row identifier to remove");
    }

    my $row = $self->row($id);
    unless (defined $row) {
        throw EBox::Exceptions::Internal(
            "Row with id $id does not exist, so it cannot be removed");
    }
    if ($row->{isCriticalSystemObject}) {
        throw EBox::Exceptions::UnwillingToPerform(
            reason => __x('This is a system critical object and cannot be removed.',
                x => $row->id()));
    }

    my $dn = EBox::Samba::GPOIdMapper::idToDn($id);
    my $gpo = new EBox::Samba::GPO(dn => $dn);
    my $gpoName = $gpo->get('displayName');
    $gpo->deleteObject();

    $self->setMessage(__x('GPO {gpo} removed', gpo => $gpoName));
}

sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $dn = EBox::Samba::GPOIdMapper::idToDn($id);
    my $gpo = new EBox::Samba::GPO(dn => $dn);
    unless ($gpo->exists()) {
        throw EBox::Exceptions::External(__x('GPO {dn} not found', dn => $dn));
    }

    my $gpoName = $gpo->get('displayName');
    my $oldRow = $self->row($id);
    my $allHashElements = $oldRow->hashElements();
    $self->validateTypedRow('update', $paramsRef, $allHashElements);

    my $newDisplayName = $paramsRef->{name}->printableValue();
    my $newStatus = $paramsRef->{status}->value();
    $gpo->set('displayName', $newDisplayName, 1);
    $gpo->setStatus($newStatus, 1);

    # replace old values with setted ones
    $allHashElements->{name} = $newDisplayName;
    $allHashElements->{status} = $newStatus;

    $gpo->save();

    $self->setMessage(__x('GPO {gpo} updated', gpo => $gpoName));
}

# Method: _checkRowExist
#
#   Override <EBox::Model::DataTable::_checkRowExist> as DataTable try to
#   check if a row exists checking the existance of the conf directory
#
sub _checkRowExist
{
    my ($self, $id) = @_;

    my $dn = EBox::Samba::GPOIdMapper::idToDn($id);
    my $gpo = new EBox::Samba::GPO(dn => $dn);
    return $gpo->exists();
}

# Method: precondition
#
#   Check samba is configured and provisioned
#
# Overrides:
#
#   <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $samba = $self->parentModule();
    unless ($samba->configured()) {
        $self->{preconditionFail} = 'notConfigured';
        return undef;
    }
    unless ($samba->isEnabled()) {
        $self->{preconditionFail} = 'notEnabled';
        return undef;
    }
    unless ($samba->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
        return undef;
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

    if ($self->{preconditionFail} eq 'notConfigured' or
	$self->{preconditionFail} eq 'notEnabled') {
        return __('You must enable the File Sharing module in the module ' .
	          'status section in order to use it.');
    }
    if ($self->{preconditionFail} eq 'notProvisioned') {
        return __('The domain has not been created yet.');
    }
}

1;
