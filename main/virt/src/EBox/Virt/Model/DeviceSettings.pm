# Copyright (C) 2011-2013 Zentyal S.L.
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
# Class: EBox::Virt::Model::DeviceSettings
#
#      Table with the network interfaces of the Virtual Machine
#
package EBox::Virt::Model::DeviceSettings;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::Int;
use EBox::View::Customizer;
use EBox::Exceptions::External;
use File::Basename;
use Filesys::Df;

use constant HDDS_DIR => '/var/lib/zentyal';
use constant MAX_IDE_NUM => 4;
use constant MAX_SCSI_NUM => 16;

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
    my ($model) = @_;
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
                               fieldName      => 'disk_action',
                               printableName  => __('Action'),
                               populate       => \&_populateDiskAction,
                               editable       => 1,
                               hiddenOnViewer => 1,
                              ),
       new EBox::Types::Text(
                             fieldName     => 'name',
                             printableName => __('Name'),
                             editable      => 1,
                             optional      => 1,
                             optionalLabel => 0,
                            ),
       new EBox::Types::Boolean(
                             fieldName     => 'useDevice',
                             printableName => __('Use host CD drive'),
                             editable      => 1,
                             optional      => 1,
                             optionalLabel => 0,
                             hiddenOnViewer => 1,
                            ),
       new EBox::Types::Text(
                             fieldName     => 'path',
                             printableName => __('Path'),
                             editable      => 1,
                             optional      => 1,
                             optionalLabel => 0,
                             hiddenOnViewer => 1,
                            ),
       new EBox::Types::Int(
                            fieldName      => 'size',
                            printableName  => __('Size'),
                            editable       => 1,
                            defaultValue   => 8000,
                            trailingText   => 'MB',
                            hiddenOnViewer => 1,
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

# TODO: It would be great to have something like this implemented at framework level
# for all the models
sub isEqual
{
    #my ($self, $other) = @_;
    my ($self, $vmRow) = @_;

    my $virtRO = EBox::Global->getInstance(1)->modInstance('virt');

    my @thisIds = @{$self->ids()};
    #my @otherIds = @{$other->ids()};
    my @otherIds = @{$virtRO->get_list("VirtualMachines/keys/$vmRow/settings/DeviceSettings/order")};
    return 0 unless (@thisIds == @otherIds);

    foreach my $id (@{$self->ids()}) {
        my $thisDev = $self->row($id);
        #my $otherDev = $other->row($id);
        #return 0 unless defined ($otherDev);

        foreach my $field (qw(enabled type disk_action size path)) {
            my $thisField = $thisDev->valueByName($field);
            next unless defined ($thisField);
            #my $otherField = $otherDev->valueByName($field);
            my $otherField = $virtRO->get_string("VirtualMachines/keys/$vmRow/settings/DeviceSettings/keys/$id/$field");
            next unless defined ($otherField);
            return 0 unless ($thisField eq $otherField);
        }
    }

    return 1;
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

    $self->_checkNumberOfDevices();

    my $type =  $allFields->{type}->value();
    my $path = $allFields->{path}->value();
    my $ownId = $allFields->{id};

    if ($type eq 'cd') {
        my $useDevice = $allFields->{useDevice}->value();
        if ($useDevice) {
            $self->_checkOnlyOneCDDeviceFile($ownId);
            $self->_checkCDDeviceFile();
        } else {
            $self->_checkDevicePath($path, 0, __('ISO image'));
            unless (_checkFileOutput($path, qr/ISO 9660 CD-ROM filesystem/,
                                            qr/DOS\/MBR boot sector/)) {
                throw EBox::Exceptions::External(
                    __x('The CD disk image {img} should be in ISO format',
                        img => $path)
                   );
            }
        }
    } else {
        my $disk_action =  $allFields->{disk_action}->value();
        if ($disk_action eq 'use') {
            $self->_checkDevicePath($path, 1, __('Hard disk image'));
            my @qcow2Re = (
                qr/Format:\s+Qcow\s+,\s+Version:\s+2/,
                qr/QEMU\s+QCOW\s+Image\s+\(v2\)/
               );
            unless (_checkFileOutput($path, @qcow2Re)) {
                throw EBox::Exceptions::External(
                    __x('The hard disk image {img} should be in qcow2 format',
                        img => $path)
                );
            }
        } elsif ($disk_action eq 'create') {
            my $name = exists $changedFields->{name} ? $changedFields->{name}->value() :
                                                       $allFields->{name}->value();
            unless ($name) {
                throw EBox::Exceptions::External(__('You need to specify a name for the new hard disk'));
            } else {
                $self->_checkHdName($name);
            }

            my $vmRow = $self->parentRow();
            my $vmName = $vmRow->valueByName('name');
            if ((-f $self->parentModule()->diskFile($vmName, $name)) and exists $changedFields->{size}) {
                if ($action eq 'add') {
                    throw EBox::Exceptions::External(
                        __('It already exists a disk file with this name. Save changes to synchronize disk files status')
                    );
                }
                throw EBox::Exceptions::External(__('You cannot modify an already created disk. ' .
                                                    'You need to delete it and add a new one if you want to change the size.'));
            }
        } else {
            throw EBox::Exceptions::Internal("Invalid action for hard disk $disk_action");
        }
    }
}

sub _checkNumberOfDevices
{
    my ($self) = @_;
    my $numHDs = 0;
    my $numCDs = 0;

    my @devices = @{$self->ids()};
    if (EBox::Config::boolean('use_ide_disks') and (@devices == 4)) {
        throw EBox::Exceptions::External(__x('A maximum of {num} IDE drives are allowed', num => MAX_IDE_NUM));
    }

    foreach my $id (@devices) {
        my $row = $self->row($id);

        my $type = $row->elementByName('type')->value();

        if ($type eq 'cd') {
            $numCDs++;
            if ($numCDs == MAX_IDE_NUM) {
                throw EBox::Exceptions::External(__x('A maximum of {num} CD/DVD drives are allowed', num => MAX_IDE_NUM));
            }
        } elsif ($type eq 'hd') {
            $numHDs++;
            if ($numHDs == MAX_SCSI_NUM) {
                throw EBox::Exceptions::External(__x('A maximum of {num} Hard Disk drives are allowed', num => MAX_SCSI_NUM));
            }
        }
    }
}

sub CDDeviceFile
{
    return '/dev/cdrom';
}

sub _checkOnlyOneCDDeviceFile
{
    my ($self, $ownId) = @_;
    foreach my $id (@{ $self->ids() }) {
        if ($ownId and ($ownId eq $id)) {
            next;
        }
        my $row = $self->row($id);
        my $type = $row->elementByName('type')->value();
        if (($type eq 'cd') and $row->valueByName('useDevice')) {
            throw EBox::Exceptions::External(__('Only one CD connected to a host drive is supported'))
        }
    }
}

sub _checkCDDeviceFile
{
    my $file = CDDeviceFile();
    if (not -e $file) {
        throw EBox::Exceptions::External(__x('Device file for CD "{f}" does not exists', f => $file));
    }
}

sub _checkFileOutput
{
    my ($path, @wantedRes) = @_;
    my $fileOutput = EBox::Sudo::root("file $path");
    foreach my $wantedRe (@wantedRes) {
        if ($fileOutput->[0] =~ m/$wantedRe/) {
            return 1;
        }
    }

    return undef;
}

sub _checkHdName
{
    my ($self, $name) = @_;
    unless ($name =~ m/^[\d\w]+$/) { # non-ascii characters are ok
        throw EBox::Exceptions::InvalidData(
            data => __('HardDisk name'),
            value => $name,
            advice => __('The name should contain only characters, digits and underscores'),
           );
    }

}
sub _checkDevicePath
{
    my ($self, $path, $rw, $name) = @_;
    unless ($path) {
        throw EBox::Exceptions::External(__x('You need to provide the path of a {name}',
                                             name => lcfirst $name
                                            ));
    }
    unless ($path =~ m{^[\d\w/.\\_-]+$}) {
        throw EBox::Exceptions::InvalidData(
            data => $path,
            value => $name,
            advice => __(q{The path should contain only characters, digits, dots, dashes, directory separators  and underscores}),
           );
    }

    unless (-e $path) {
        throw EBox::Exceptions::External(__x("{name} '{img}' does not exist",
                                             name => $name,
                                             img => $path));
    }

    unless (-r $path) {
        throw EBox::Exceptions::External(__x("{name} '{img}' is not readable",
                                             name => $name,
                                             img => $path));
    }
}

sub deletedRowNotify
{
    my ($self, $row) = @_;

    my $type = $row->valueByName('type');
    return unless ($type eq 'hd');

    my $action = $row->valueByName('disk_action');
    return unless ($action eq 'create');

    my $name = $row->valueByName('name');
    my $vmRow = $self->parentRow();
    my $vmName = $vmRow->valueByName('name');

    my $virt = $self->parentModule();
    my $deletedDisks = $virt->model('DeletedDisks');
    my $file = $virt->diskFile($vmName, $name);
    $deletedDisks->add(file => $file);
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

    $customizer->setHTMLTitle([]);

    my @onlyCd = ( 'useDevice', 'path' );
    my @onlyHd = ( 'disk_action', 'name', 'size' );
    $customizer->setOnChangeActions(
            {
              type =>
                {
                  'cd' => { show => \@onlyCd,  hide => \@onlyHd },
                  'hd' => { show  => \@onlyHd, hide =>\@onlyCd },

                },
              disk_action =>
                {
                  'create' => { show => [ 'name', 'size' ], hide => [ 'path' ] },
                  'use' => { show  => [ 'path' ], hide => [ 'name', 'size' ] },
                },
              useDevice =>  {
                   on  => { hide => ['path']  },
                   off => { show => ['path' ]},
               },
            });

    $customizer->setInitHTMLStateOrder(['type', 'disk_action']);

    return $customizer;
}

1;
