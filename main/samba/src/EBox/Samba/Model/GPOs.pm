# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::Samba::Model::GPOs
#
#
package EBox::Samba::Model::GPOs;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Types::Select;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Samba::GPO;

# Constructor: new
#
#   Create the GPOs table
#
# Overrides:
#
#   <EBox::Model::DataTable::new>
#
# Returns:
#
#   <EBox::Samba::Model::GPOs> - the newly created object instance
#
sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);

    return $self;
}

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
        pageTitle           => __('Group Policy Objects'),
        tableName           => 'GPOs',
        defaultActions      => ['add', 'del', 'editField', 'changeView'],
        tableDescription    => $tableDesc,
        printableRowName    => __('Group Policy Object'),
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

    my $global = $self->global();
    my $samba = $global->modInstance('samba');
    unless ($samba->configured() and $samba->isProvisioned()) {
        return [];
    }

    my @list = map { $_->dn() } @{$samba->gpos()};

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

    my $gpo = new EBox::Samba::GPO(dn => $id);
    if ($gpo->exists()) {
        my $displayName = $gpo->get('displayName');
        my $status = $gpo->status();
        my $row = $self->_setValueRow(
            name => $displayName,
            status => $status,
        );
        $row->setId($id);
        if ($gpo->get('isCriticalSystemObject')) {
            # Cache the attribute in the row to disallow row
            # deletion
            $row->{isCriticalSystemObject} = 1;
        }
        return $row;
    } else {
        throw EBox::Exceptions::Internal("GPO $id does not exist");
    }
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

    # validate row to add
    $self->validateTypedRow('add', $params_r, $params_r);

    my $name = $params_r->{name}->value();
    my $status = $params_r->{status}->value();

    my $gpo = EBox::Samba::GPO->create($name, $status);
    $self->setMessage(__('GPO successfully created'));

    # Return the ID of the added row
    return $gpo->dn();
}

# Method: removeRow
#
#   Override not to allow to remove critical system objects
#
# Overrides:
#
#   <EBox::Exceptions::DataTable::removeRow>
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    unless (defined $id) {
        throw EBox::Exceptions::MissingArgument('Missing row identifier to remove');
    }

    my $row = $self->row($id);
    my $gpoName = $row->getPrintableValue('name');
    if (not defined $row) {
        throw EBox::Exceptions::Internal("Row with id '$id' does not exist, so it cannot be removed");
    }

    if ($row->{isCriticalSystemObject}) {
        throw EBox::Exceptions::UnwillingToPerform(
            reason => __x('The object {x} is a system critical object.',
                          x => $row->id()));
    }

    my $gpo = new EBox::Samba::GPO(dn => $id);
    $gpo->deleteObject();
    $self->setMessage(__x('GPO {name} removed', name => $gpoName));
}


sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $gpo = new EBox::Samba::GPO(dn => $id);
    unless ($gpo->exists()) {
        throw EBox::Exceptions::External(__x('GPO {dn} not found', dn => $id));
    }

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
}

# Method: _checkRowExist
#
#   Override <EBox::Model::DataTable::_checkRowExist> as DataTable try to
#   check if a row exists checking the existance of the conf directory
#
sub _checkRowExist
{
    my ($self, $id) = @_;
    return 1;
}

1;
