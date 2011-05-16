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

package EBox::Virt::VBox;

use base 'EBox::Virt::AbstractBackend';

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;

my $SATA_CTL = 'satactl';

# Class: EBox::Virt::VBox
#
#   Backend implementation for VirtualBox
#

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}

# Method: createDisk
#
#   Creates a VDI file.
#
# Parameters:
#
#   file    - filename of the disk image
#   size    - size of the disk in megabytes
#
sub createDisk
{
    my ($self, %params) = @_;

    exists $params{file} or
        throw EBox::Exceptions::MissingArgument('file');
    exists $params{size} or
        throw EBox::Exceptions::MissingArgument('size');

    my $file = $params{file};
    my $size = $params{size};

    system ("vboxmanage createhd --filename $file --size $size");
}

# Method: resizeDisk
#
#   Resizes a VDI file.
#
# Parameters:
#
#   file    - filename of the disk image
#   size    - size of the disk in megabytes
#
sub resizeDisk
{
    my ($self, %params) = @_;

    exists $params{file} or
        throw EBox::Exceptions::MissingArgument('file');
    exists $params{size} or
        throw EBox::Exceptions::MissingArgument('size');

    my $file = $params{file};
    my $size = $params{size};

    system ("vboxmanage modifyhd $file --resize $size");
}

# Method: vmExists
#
#   Checks if a VM with the given name already exists
#
# Parameters:
#
#   name    - virtual machine name
#
# Returns:
#
#   boolean - true if exists, false if not
#
sub vmExists
{
    my ($self, $name) = @_;

    $self->_vmCheck($name, 'vms');
}

# Method: vmRunning
#
#   Checks if a VM with the given name is running
#
# Parameters:
#
#   name    - virtual machine name
#
# Returns:
#
#   boolean - true if running, false if not
#
sub vmRunning
{
    my ($self, $name) = @_;

    $self->_vmCheck($name, 'runningvms');
}

sub _vmCheck
{
    my ($self, $name, $list) = @_;

    system ("vboxmanage list $list | grep -q '\"$name\"'");
    return ($? == 0);
}

# Method: createVM
#
#   Creates a new virtual machine
#
# Parameters:
#
#   name    - virtual machine name
#   os      - operating system identifier
#
sub createVM
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{os} or
        throw EBox::Exceptions::MissingArgument('os');

    my $name = $params{name};
    my $os = $params{os};

    # TODO: --settingsfile <path> ?
    system ("vboxmanage createvm $name --delete --ostype $os --register");

    # Add SATA controller
    system ("vboxmanage storagectl $name --name $SATA_CTL --add sata");
}

# Method: startVM
#
#   Starts a VM with a VNC server on the specified port.
#
# Parameters:
#
#   name    - virtual machine name
#   port    - VNC port
#
sub startVM
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{port} or
        throw EBox::Exceptions::MissingArgument('port');

    my $name = $params{name};
    my $port = $params{port};

    system ("vboxheadless --vnc --vncport $port --startvm $name");
}

# Method: shutdownVM
#
#   Shuts down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub shutdownVM
{
    my ($self, $name) = @_;

    $self->_controlVM($name, 'poweroff');
}

# Method: pauseVM
#
#   Pauses a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub pauseVM
{
    my ($self, $name) = @_;

    $self->_controlVM($name, 'pause');
}

# Method: resumeVM
#
#   Shuts down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub resumeVM
{
    my ($self, $name) = @_;

    $self->_controlVM($name, 'resume');
}

sub _controlVM
{
    my ($self, $name, $command) = @_;

    system ("vboxmanage controlvm $name $command");
}

# Method: deleteVM
#
#   Deletes a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
sub deleteVM
{
    my ($self, $name) = @_;

    system ("vboxmanage unregistervm $name --delete");
}

# Method: setMemory
#
#   Set memory amount for the given VM.
#
# Parameters:
#
#   name    - virtual machine name
#   size    - memory size (in megabytes)
#
sub setMemory
{
    my ($self, $name, $size) = @_;

    $self->_modifyVM($name, 'memory', $size);
}

# Method: setOS
#
#   Set the OS type for the given VM.
#
# Parameters:
#
#   name    - virtual machine name
#   os      - operating system identifier
#
sub setOS
{
    my ($self, $name, $os) = @_;

    $self->_modifyVM($name, 'ostype', $os);
}

# Method: setIface
#
#   Set a network interface for the given VM.
#
# Parameters:
#
#   name    - virtual machine name
#   iface   - iface number
#   type    - iface type (nat, bridged, internal)
#   arg     - iface arg (bridged => devicename, internal => networkname)
#
sub setIface
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{iface} or
        throw EBox::Exceptions::MissingArgument('iface');
    exists $params{type} or
        throw EBox::Exceptions::MissingArgument('type');

    my $name = $params{name};
    my $iface = $params{iface};
    my $type = $params{type};
    my $arg = '';
    if (($type eq 'bridged') or ($type eq 'internal')) {
        exists $params{arg} or
            throw EBox::Exceptions::MissingArgument('arg');
        $arg = $params{arg};
    }

    if ($type eq 'nat') {
        $type = 'natnet';
        $arg = 'default';
    } elsif ($type eq 'bridged') {
        $type = 'bridgedadapter';
    } elsif ($type eq 'internal') {
        $type = 'intnet';
    }
    my $setting = "--$type" . $iface;

    $self->_modifyVM($name, $setting, $arg);
}

sub _modifyVM
{
    my ($self, $name, $setting, $value) = @_;

    system ("vboxmanage modifyvm $name --$setting $value");
}

# Method: attachDevice
#
#   Attach a device to a VM.
#
# Parameters:
#
#   name   - virtual machine name
#   port   - port number
#   device - device number
#   type   - hdd | dvddrive | none
#   file   - path of the ISO or VDI file
#
sub attachDevice
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{port} or
        throw EBox::Exceptions::MissingArgument('port');
    exists $params{device} or
        throw EBox::Exceptions::MissingArgument('device');
    exists $params{type} or
        throw EBox::Exceptions::MissingArgument('type');
    exists $params{file} or
        throw EBox::Exceptions::MissingArgument('file');

    my $name = $params{name};
    my $port = $params{port};
    my $device = $params{device};
    my $type = $params{type};
    my $file = $params{file};

    system ("vboxmanage storageattach $name --storagectl $SATA_CTL --port $port --device $device --type $type --medium $file");
}

1;
