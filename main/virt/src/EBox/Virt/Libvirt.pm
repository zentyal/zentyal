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

package EBox::Virt::Libvirt;

use base 'EBox::Virt::AbstractBackend';

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;
use File::Basename;

my $VM_PATH = '/var/lib/zentyal/machines';
my $VM_FILE = 'domain.xml';
my $VIRTCMD = EBox::Virt::LIBVIRT_BIN();

# Class: EBox::Virt::Libvirt
#
#   Backend implementation for libvirt
#

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);

    $self->{vmConf} = {};

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

    # FIXME: faster if we use qemu-img ?
    _run("dd if=/dev/zero of=$file bs=1M count=$size");
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

    # TODO: Implement this with cat (only enlarge)
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

    return (-e "$VM_PATH/$name/$VM_FILE");
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

    return system ("$VIRTCMD list | grep running | cut -f2 -d' ' | grep -q ^$name\$") == 0;
}

# FIXME: doc
sub listVMs
{
    my @dirs = glob ("$VM_PATH/*");
    @dirs = grep { -e "$_/$VM_FILE" } @dirs;
    my @vms = map { basename($_) } @dirs;
    return \@vms;
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
    my $os = $params{os}; # FIXME: is this needed?

    my $conf = {};
    $conf->{ifaces} = [];
    $conf->{disks} = [];

    $self->{vmConf}->{$name} = $conf;

    _run("mkdir -p $VM_PATH/$name");
}

# Method: startVMCommand
#
#   Command to start a VM with a VNC server on the specified port.
#
# Parameters:
#
#   name    - virtual machine name
#   port    - VNC port
#
# Returns:
#
#   string with the command
#
sub startVMCommand
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{port} or
        throw EBox::Exceptions::MissingArgument('port');

    my $name = $params{name};
    my $port = $params{port};
    $self->{vmConf}->{$name}->{port} = $port;

    return ("$VIRTCMD create $VM_PATH/$name/$VM_FILE");
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

    _run($self->shutdownVMCommand($name));
}

# Method: shutdownVMCommand
#
#   Command to shut down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#
# Returns:
#
#   string with the command
#
sub shutdownVMCommand
{
    my ($self, $name) = @_;

    return "$VIRTCMD shutdown $name";
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

    # FIXME: Is this supported by libvirt?
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

    # FIXME: Is this supported by libvirt?
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

    _run("rm -rf $VM_PATH/$name");
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

    $self->{vmConf}->{$name}->{memory} = $size;
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

    # TODO: Is this needed?
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

    $self->_modifyVM($name, "nic$iface", $type);

    if ($type eq 'nat') {
        $type = 'natnet';
        $arg = 'default';
    } elsif ($type eq 'bridged') {
        $type = 'bridgedadapter';
    } elsif ($type eq 'internal') {
        $type = 'intnet';
    }
    my $setting = $type . $iface;

    # FIXME
    #push (@{$self->{vmConf}->{$name}->{ifaces}}, $file);
}

# Method: attachDevice
#
#   Attach a device to a VM.
#
# Parameters:
#
#   name   - virtual machine name
#   type   - hd | cd | none
#   file   - path of the ISO or VDI file
#
sub attachDevice
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{type} or
        throw EBox::Exceptions::MissingArgument('type');
    exists $params{file} or
        throw EBox::Exceptions::MissingArgument('file');

    my $name = $params{name};
    my $type = $params{type};
    my $file = $params{file};

    # TODO: CD/DVD support
    push (@{$self->{vmConf}->{$name}->{disks}}, $file);
}

sub writeConf
{
    my ($self, $name) = @_;

    my $vmConf = $self->{vmConf}->{$name};

    EBox::Module::Base::writeConfFileNoCheck(
        "$VM_PATH/$name/$VM_FILE",
        '/virt/domain.xml.mas',
        [
         name => $name,
         memory => $vmConf->{memory},
         ifaces => $vmConf->{ifaces},
         disks => $vmConf->{disks},
         vncport => $vmConf->{port},
        ],
        { uid => 0, gid => 0, mode => '0644' }
    );
}

sub listHDs
{
    my $list =  `find $VM_PATH -name '*.img'`;
    my @hds = split ("\n", $list);
    return \@hds;
}

sub _run
{
    my ($cmd) = @_;

    EBox::debug("Running: $cmd");
    system ($cmd);
}

1;
