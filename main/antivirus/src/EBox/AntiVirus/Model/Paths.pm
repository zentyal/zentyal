# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::AntiVirus::Model::Paths;

use base 'EBox::Model::DataTable';

# Class: EBox::Antivirus::Model::Paths
#
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;

# Group: Public methods

sub includes
{
    my ($self) = @_;

    my @paths;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        push (@paths, $row->valueByName('type') . ' ' . $row->valueByName('path'));

    }
    return \@paths;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
        new EBox::Types::Text(
            fieldName     => 'path',
            printableName => __('Path'),
            size          => 30,
            unique        => 0,
            editable      => 1,
            allowUnsafeChars => 1,
        ),
        new EBox::Types::Select(
            fieldName     => 'type',
            printableName => __('Type'),
            editable      => 1,
            populate      => \&_types,
        ),
    );

    my $dataTable =
    {
        tableName          => 'Paths',
        printableTableName => __('On-Access Scanning'),
        printableRowName   => __('path'),
        rowUnique          => 1,
        defaultActions     => [ 'add', 'del', 'editField', 'changeView', 'move' ],
        order              => 1,
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'AntiVirus',
        defaultEnabledValue => 1,
        help => __('Inclusions and Exclusions are recursive. Please also note that any path that is not explicitly included is excluded by default.'),
    };

    return $dataTable;
}

sub _types
{
    return [
        {
            value => 'IncludePath',
            printableValue => __('Include')
        },
        {
            value => 'ExcludePath',
            printableValue => __('Exclude')
        },
    ];
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless defined ($changedFields->{path});

    my $path = $changedFields->{path}->value();
    EBox::Validate::checkAbsoluteFilePath($path, __('path'));
}

1;
