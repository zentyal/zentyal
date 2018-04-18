# Copyright (C) 2011-2018 Zentyal S.L.
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

package EBox::Virt::AbstractBackend;

use EBox::Exceptions::NotImplemented;

# Class: EBox::Virt::AbstractBackend
#
#   Abstract class with the methods that each virtualization backend
#   has to implement

# Method: createDisk
#
#   Creates a disk image.
#
# Parameters:
#
#   file    - path of the disk image file
#   size    - size of the disk in megabytes
#
sub createDisk
{
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
}

# Method: createVM
#
#   Creates a new virtual machine
#
# Parameters:
#
#   name    - virtual machine name
#
sub createVM
{
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
}

# Method: shutdownVMCommand
#
#   Command to shut down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#   force   - force hard power off
#
sub shutdownVMCommand
{
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
}

# Method: setArch
#
#   Set the architecture type for the given VM.
#
# Parameters:
#
#   name    - virtual machine name
#   arch      - architecture identifier
#
sub setArch
{
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
}

# Method: initDeviceNumbers
#
#   Do the required initialization for drive order assignment
#
sub initDeviceNumbers
{
    throw EBox::Exceptions::NotImplemented();
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
    throw EBox::Exceptions::NotImplemented();
}

# Method: systemTypes
#
#   Returns system types supported by the virtualizer
#
# Returns:
#
#   [ { value => 'foo', printableValue => 'Foo' }, ... ]
#
sub systemTypes
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: vmsPath
#
#   Returns the path where VMs are stored.
#
sub vmsPath
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: ifaces
#
#   Returns array with the names of the interfaces that can be
#   used to create bridged interfaces with the current virtualizer
#
sub ifaces
{
    throw EBox::Exceptions::NotImplemented();
}

# Method : allowsNoneIface
#
#   return whether the backend allow interfaces set to 'None' (inactive)
sub allowsNoneIface
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: listVMs
#
#   Returns the list of names of found VMs referenced
#   by Zentyal config or not.
#
sub listVMs
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: diskFile
#
#   Returns the path for a disk file.
#
# Parameters:
#
#   disk    - disk name
#   machine - *optional* VM name
#
sub diskFile
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: manageScript
#
#   Returns the path for the manage script used to start/stop VMs
#
# Parameters:
#
#   name    - virtual machine name
#
sub manageScript
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: writeConf
#
#   Writes configuration file for a VM if needed.
#
# Parameters:
#
#   name    - virtual machine name
#
sub writeConf
{
}

# Method: initInternalNetworks
#
#   Init stuff for internal networks creation if needed.
#
sub initInternalNetworks
{
}

# Method: createInternalNetworks
#
#   Creates all the internal networks if needed.
#
sub createInternalNetworks
{
}

# Method: daemons
#
#   Returns daemons to manage needed by the virtualization backend
#
# Return:
#
#   arrayref - same format as EBox::Module::Service::_daemons
#
sub daemons
{
    return [];
}

# Method: attachedDevices
#
#   Returns the number of attached devices for a VM.
#
# Parameters:
#
#   name    - virtual machine name
#   type    - type of devices (values: hd | cd)
#
sub attachedDevices
{
    return 0;
}

# Method: runningVMCommand
#
#   Only used for libvirt for the systemd and manage.sh scripts.
#
# Parameters:
#
#   name    - virtual machine name
#
sub runningVMCommand
{
    return undef;
}

1;
