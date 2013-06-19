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

#
# Class: EBox::Samba::Model::GPOScripts
#
package EBox::Samba::Model::GPOScripts;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::File;
use EBox::Exceptions::Internal;

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
        new EBox::Types::Select(
            fieldName      => 'type',
            printableName  => __('Script type'),
            populate       => sub { $self->_populateScriptType() },
            editable       => 1),
        new EBox::Types::Text(
            fieldName      => 'name',
            printableName  => __('Script name'),
            editable       => 0,
            hiddenOnSetter => 1,
            hiddenOnViewer => 0),
        new EBox::Types::Text(
            fieldName      => 'parameters',
            printableName  => __('Parameters'),
            editable       => 1,
            optional       => 1,
            hiddenOnSetter => 0,
            hiddenOnViewer => 0),
        new EBox::Types::File(
            fieldName      => 'upload',
            printableName  => __('Upload new script'),
            editable       => 1,
            hiddenOnSetter => 0,
            hiddenOnViewer => 1),
    ];

    my $dataTable = {
        tableName           => 'GPOScripts',
        printableTableName  => __('Scripts'),
        printableRowName    => __('script'),
        defaultActions      => ['add', 'del', 'changeView'],
        whithoutActions     => 0,
        tableDescription    => $tableDesc,
        sortedBy            => 'type',
        modelDomain         => 'Samba',
    };

    return $dataTable;
}

sub _populateScriptType
{
    my ($self) = @_;

    my $types = [
        { value => 'batch', printableValue => __('Batch') },
        { value => 'ps',    printableValue => __('PowerShell') },
    ];
    return $types;
}

# Method: precondition
#
#   Check samba is configured and provisioned, required prior to modify
#   the GPOs
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
    unless ($samba->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
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

    if ($self->{preconditionFail} eq 'notConfigured') {
        return __('You must enable the module in the module ' .
                'status section in order to use it.');
    }
    if ($self->{preconditionFail} eq 'notProvisioned') {
        return __('The domain has not been created yet.');
    }
}

# Method: parentRow
#
#   Returns the parent row
#
# Overrides:
#
#   <EBox::Model::Component::parentRow>
#
sub parentRow
{
    my ($self) = @_;

    unless ($self->{parent}) {
        return undef;
    }

    my $dir = $self->directory();
    my @parts = split ('/', $dir);

    my $rowId = undef;
    for (my $i = scalar (@parts) - 1; $i > 0; $i--) {
        if ($parts[$i] =~ m/CN={.+}/) {
            $rowId = $parts[$i];
            last;
        }
    }
    if (not defined $rowId) {
        return undef;
    }

    my $row = $self->{parent}->row($rowId);
    unless ($row) {
        throw EBox::Exceptions::Internal("Cannot find row with rowId $rowId." .
            "Component directory: $dir.");
    }

    return $row;
}

1;
