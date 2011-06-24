# Copyright (C) 2011 eBox Technologies S.L.
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


package EBox::Virt::Model::DeviceSettings;

# Class: EBox::Virt::Model::DeviceSettings
#
#      Table with the network interfaces of the Virtual Machine
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::View::Customizer;
use EBox::Exceptions::External;

use Filesys::Df;

use constant HDDS_DIR => '/var/lib/zentyal';
use constant MAX_CD_NUM => 4;
use constant MAX_HD_NUM => 30;

# Group: Public methods

# Constructor: new
#
#       Create the new DeviceSettings model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Virt::Model::DeviceSettings> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ($self, $class);

    return $self;
}

# Group: Private methods

sub _populateDriveTypes
{
    return [
            { value => 'hd', printableValue => __('Hard Disk') },
            { value => 'cd', printableValue => 'CD/DVD' },
    ];
}

sub _populateDiskAction
{
    return [
            { value => 'create', printableValue => __('Create a new disk') },
            { value => 'use', printableValue => __('Use a existing image file') },
    ];
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
       new EBox::Types::Select(
                               fieldName     => 'type',
                               printableName => __('Drive Type'),
                               populate      => \&_populateDriveTypes,
                               editable      => 1,
                              ),
       new EBox::Types::Select(
                               fieldName     => 'disk_action',
                               printableName => __('Action'),
                               populate      => \&_populateDiskAction,
                               editable      => 1,
                              ),
       new EBox::Types::Text(
                             fieldName     => 'name',
                             printableName => __('Name'),
                             editable      => 1,
                             optional      => 1,
                            ),
       new EBox::Types::Text(
                             fieldName     => 'path',
                             printableName => __('Path'),
                             editable      => 1,
                             optional      => 1,
                            ),
       new EBox::Types::Int(
                            fieldName     => 'size',
                            printableName => __('Size'),
                            editable      => 1,
                            defaultValue  => 8000,
                            # TODO: Move these checks to validateRow
                            #min           => 32,
                            #max           => int(df('/')->{bavail}),
                            trailingText  => 'MB',
                           ),
    );

    my $dataTable =
    {
        tableName           => 'DeviceSettings',
        printableTableName  => __('Device Settings'),
        printableRowName    => __('drive'),
        defaultActions      => [ 'add', 'del', 'editField', 'changeView', 'move' ],
        tableDescription    => \@tableHeader,
        order               => 1,
        enableProperty      => 1,
        defaultEnabledValue => 1,
        class               => 'dataTable',
        help                => __('Here you can define the storage drives of the virtual machine'),
        modelDomain         => 'Virt',
    };

    return $dataTable;
}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    my $numCDs = 0;
    my $numHDs = 0;

    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);

        my $type = $row->elementByName('type')->value();

        if ($type eq 'cd') {
            $numCDs++;
            if ($numCDs == MAX_CD_NUM) {
                throw EBox::Exceptions::External(__x('A maximum of {num} CD/DVD drives are allowed', num => MAX_CD_NUM));
            }
        } elsif ($type eq 'hd') {
            $numHDs++;
            if ($numHDs == MAX_HD_NUM) {
                throw EBox::Exceptions::External(__x('A maximum of {num} Hard Disk drives are allowed', num => MAX_HD_NUM));
            }
        }
    }
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

    $self->_cleanOptionalValues($row);
}

# Method: updatedRowNotify
#
# Overrides:
#
#      <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row) = @_;

    $self->_cleanOptionalValues($row);
}

sub _cleanOptionalValues
{
    my ($self, $row) = @_;

    if ($row->valueByName('type') eq 'hd' and
        $row->valueByName('disk_action') eq 'create') {
        $row->elementByName('path')->setValue('');
    } else {
        my $file = $row->valueByName('path');
        my $size = int ((-s $file) / (1024 * 1024));
        my $sizeElement = $row->elementByName('size');
        $sizeElement->setValue($size);
        $row->elementByName('name')->setValue('');
    }
    $row->store();
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    $customizer->setOnChangeActions(
            {
              type =>
                {
                  'cd' => { show => [ 'path' ], hide => [ 'disk_action', 'name', 'size' ] },
                  'hd' => { show  => [ 'disk_action', 'name', 'size' ], hide => [ 'path' ] },
                },
              disk_action =>
                {
                  'create' => { show => [ 'name', 'size' ], hide => [ 'path' ] },
                  'use' => { show  => [ 'path' ], hide => [ 'name', 'size' ] },
                },
            });
    return $customizer;
}

1;
