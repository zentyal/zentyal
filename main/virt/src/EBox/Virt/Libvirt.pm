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

use EBox::Gettext;
use EBox::Sudo;
use EBox::Exceptions::MissingArgument;
use File::Basename;
use String::ShellQuote;

my $VM_PATH = '/var/lib/zentyal/machines';
my $KEYMAP_PATH = '/usr/share/qemu/keymaps';
my $VM_FILE = 'domain.xml';
my $VIRTCMD = EBox::Virt::LIBVIRT_BIN();
my $DEFAULT_KEYMAP = 'en-us';

# Class: EBox::Virt::Libvirt
#
#   Backend implementation for libvirt
#

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);

    # Choose between kvm or qemu according to the HW capabilities
    system ("egrep '^flags.* (vmx|svm)' /proc/cpuinfo");
    $self->{emulator} = ($? == 0) ? 'kvm' : 'qemu';
    $self->{keymap} = _vncKeymap();

    $self->{vmConf} = {};

    return $self;
}

# Method: createDisk
#
#   Creates a VDI file.
#
# Parameters:
#
#   file    - path of the disk image file
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

    _run("qemu-img create -f qcow2 $file ${size}M");
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

    EBox::Sudo::silentRoot("$VIRTCMD list | grep running | cut -d' ' -f3 | grep -q ^$name\$");
    return $? == 0;
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
    $conf->{devices} = [];

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
#   pass    - VNC password
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
    exists $params{pass} or
        throw EBox::Exceptions::MissingArgument('pass');

    my $name = $params{name};
    my $port = $params{port};
    my $pass = $params{pass};
    $self->{vmConf}->{$name}->{port} = $port;
    $self->{vmConf}->{$name}->{password} = $pass;

    my $cmd = "$VIRTCMD create $VM_PATH/$name/$VM_FILE";
    $self->{vmConf}->{$name}->{startCmd} = $cmd;

    return $cmd;
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

    # FIXME: "shutdown" only works when a SO with acpi enabled is running
    # is there any way to detect this? In the meanwhile the only possibility
    # seems to be use "destroy"
    #my $cmd = "$VIRTCMD shutdown $name";
    my $cmd = "$VIRTCMD destroy $name";

    $self->{vmConf}->{$name}->{stopCmd} = $cmd;

    return $cmd;
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
#   type    - iface type (nat, bridged, internal)
#   arg     - iface arg (bridged => devicename, internal => networkname)
#
sub setIface
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');
    exists $params{type} or
        throw EBox::Exceptions::MissingArgument('type');

    my $name = $params{name};
    my $type = $params{type};

    my $source = '';
    if ($type eq 'none') {
        return;
    } elsif ($type eq 'nat') {
        $source = 'default';
    } else {
        exists $params{arg} or
            throw EBox::Exceptions::MissingArgument('arg');
        $source = $params{arg};
    }

    # FIXME: This is not enough, currently only NAT will work
    # we need to create bridges either for real ifaces or internal networks
    # Another possibility is to use brX ifaces created in zentyal-network
    my $iface = {};
    $iface->{type} = $type eq 'bridged' ? 'bridge' : 'network';
    $iface->{source} = $source;

    push (@{$self->{vmConf}->{$name}->{ifaces}}, $iface);
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

    return if ($type eq 'none');

    my $device = {};
    $device->{file} = $params{file};
    $device->{type} = $type eq 'cd' ? 'cdrom' : 'disk';
    $device->{letter} = $self->{driveLetter};
    $self->{driveLetter} = chr (ord ($self->{driveLetter}) + 1);

    push (@{$self->{vmConf}->{$name}->{devices}}, $device);
}

sub systemTypes
{
    return [ { value => 'i686', printableValue => __('i686 compatible') },
             { value => 'x86_64', printableValue => __('amd64 compatible') } ]
}

sub manageScript
{
    my ($self, $name) = @_;

    return "$VM_PATH/$name/manage.sh";
}

sub writeConf
{
    my ($self, $name) = @_;

    my $vmConf = $self->{vmConf}->{$name};

    EBox::Module::Base::writeConfFileNoCheck(
            $self->manageScript($name),
            '/virt/manage.sh.mas',
            [ startCmd => $vmConf->{startCmd},
              stopCmd => $vmConf->{stopCmd},
              user => $self->{vmUser} ],
            { uid => 0, gid => 0, mode => '0755' }
    );
    EBox::Module::Base::writeConfFileNoCheck(
        "$VM_PATH/$name/$VM_FILE",
        '/virt/domain.xml.mas',
        [
         name => $name,
         emulator => $self->{emulator},
         memory => $vmConf->{memory},
         ifaces => $vmConf->{ifaces},
         devices => $vmConf->{devices},
         vncport => $vmConf->{port},
         vncpass => $vmConf->{password},
         keymap => $self->{keymap},
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

sub initDeviceNumbers
{
    my ($self) = @_;

    $self->{driveLetter} = 'a';
}

sub _run
{
    my ($cmd) = @_;

    #EBox::debug("Running: $cmd");
    EBox::Sudo::rootWithoutException($cmd);
}

sub diskFile
{
    my ($self, $disk, $machine) = @_;

    return shell_quote("$VM_PATH/$machine/$disk.img");
}

sub _vncKeymap
{
    my %validKeymaps = map { $_ => 1 } glob ("$KEYMAP_PATH/*");

    my $keymap = EBox::Config::configkey('vnc_keymap');
    if (defined ($keymap)) {
        if ($validKeymaps{$keymap}) {
            return $keymap;
        } else {
            EBox::warn("VNC keymap '$keymap' is not valid, defaulting to '$DEFAULT_KEYMAP'");
            return $DEFAULT_KEYMAP;
        }
    } else {
        # Autodetect if not defined
        my ($lang1, $lang2) = split(/_/, $ENV{LANG});
        $keymap = "$lang1-" . lc($lang2);
        return $keymap if ($validKeymaps{$keymap});
        return $lang1 if ($validKeymaps{$lang1});
        return $DEFAULT_KEYMAP;
    }
}

sub vmsPath
{
    return $VM_PATH;
}

1;
