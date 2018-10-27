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

package EBox::Virt::Libvirt;

use base 'EBox::Virt::AbstractBackend';

use EBox::Gettext;
use EBox::Config;
use EBox::Sudo;
use EBox::Exceptions::MissingArgument;
use EBox::NetWrappers;
use EBox::Virt;
use File::Basename;
use String::ShellQuote;
use File::Slurp;

my $VM_PATH = '/var/lib/zentyal/machines';
my $NET_PATH = '/var/lib/zentyal/vnets';
my $LIBVIRT_NET_PATH = '/var/run/libvirt/network';
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
    system ("egrep -q '^flags.* (vmx|svm)' /proc/cpuinfo");
    $self->{emulator} = ($? == 0) ? 'kvm' : 'qemu';

    $self->{vmConf} = {};
    $self->{netConf} = {};

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

    return ($self->_state($name) eq 'running');
}

# Method: vmPaused
#
#   Checks if a VM with the given name is paused
#
# Parameters:
#
#   name    - virtual machine name
#
# Returns:
#
#   boolean - true if paused, false if running
#
sub vmPaused
{
    my ($self, $name) = @_;

    return ($self->_state($name) eq 'paused');
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
    my ($self, $name) = @_;

    return "$VIRTCMD domstate $name | grep -q ^running";
}

sub _state
{
    my ($self, $name) = @_;

    my ($state) = @{EBox::Sudo::silentRoot("LANG=C $VIRTCMD domstate $name")};
    if ($? == 0) {
        chomp ($state);
    } else {
        $state = 'error';
    }
    return $state;
}

sub vncdisplay
{
    my ($self, $name) = @_;

    my @output = @{EBox::Sudo::silentRoot("$VIRTCMD vncdisplay $name")};
    unless (@output) {
        return undef;
    }
    my ($port) = $output[0] =~ /:(\d+)/;
    return defined ($port) ? $port : undef;
}

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
#
sub createVM
{
    my ($self, %params) = @_;

    exists $params{name} or
        throw EBox::Exceptions::MissingArgument('name');

    my $name = $params{name};

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

# Method: shutdownVMCommand
#
#   Command to shut down a virtual machine.
#
# Parameters:
#
#   name    - virtual machine name
#   force   - force hard power off
#
# Returns:
#
#   string with the command
#
sub shutdownVMCommand
{
    my ($self, $name, $force) = @_;

    my $action = $force ? 'destroy' : 'shutdown';
    my $cmd = "$VIRTCMD $action $name";
    if ($force) {
        $self->{vmConf}->{$name}->{forceStopCmd} = $cmd;
    } else {
        $self->{vmConf}->{$name}->{stopCmd} = $cmd;
    }

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

    _run("$VIRTCMD suspend $name");
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

    _run("$VIRTCMD resume $name");
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

    _run("rm -rf '$VM_PATH/$name'");
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

    $self->{vmConf}->{$name}->{os} = $os;
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
    my ($self, $name, $arch) = @_;

    $self->{vmConf}->{$name}->{arch} = $arch;
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
    my $mac = $params{mac};

    my $source = '';
    if ($type eq 'none') {
        return;
    } elsif ($type eq 'nat') {
        $source = 'default';
    } else {
        exists $params{arg} or
            throw EBox::Exceptions::MissingArgument('arg');
        $source = $params{arg};
        if (not exists $self->{netConf}->{$source}) {
            $self->{netConf}->{$source} = {};
            $self->{netConf}->{$source}->{num} = $self->{netNum}++;
            my $id = $self->_freeBridgeId();
            $self->{netConf}->{$source}->{bridge} = $id;
            $self->{usedBridgeIds}->{$id} = 1;
        }
    }

    my $iface = {};
    $iface->{type} = $type eq 'bridged' ? 'bridge' : 'network';
    $iface->{source} = $source;
    $iface->{mac} = $mac;

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
    my $file = $params{file};

    return if ($type eq 'none');

    my $device = {};
    $device->{file} = $file;
    $device->{block} = ($file =~ /^\/dev\//);
    my $cd = $type eq 'cd';
    $device->{type} = $cd ? 'cdrom' : 'disk';
    my $bus;
    if ($cd) {
        $bus = 'ide';
    } else {
        $bus = $self->_busUsedByVm($name);
    }

    if (not exists $self->{driveLetterByBus}->{$bus}) {
        throw EBox::Exceptions::Internal("Invalid bus type: $bus");
    }

    $device->{bus} = $bus;
    my $letter = $self->{driveLetterByBus}->{$bus};
    $device->{letter} = $letter;
    $self->{driveLetterByBus}->{$bus} = chr (ord ($letter) + 1);

    my $vmConf = $self->{vmConf}->{$name};
    push (@{$vmConf->{devices}}, $device);
}

sub _busUsedByVm
{
    my ($self, $name) = @_;
    my $os = $self->{vmConf}->{$name}->{os};

    my %busByOS = (
        new_windows => 'sata',
        old_windows => 'ide',
        linux => 'virtio',
        other => EBox::Config::boolean('use_ide_disks') ? 'ide' : 'scsi',
    );

    return $busByOS{$os};
}

sub _mouseUsedByOs
{
    my ($self, $os) = @_;

    if (($os eq 'new_windows') or ($os eq 'old_windows')) {
        return 'tablet';
    } else {
        return 'mouse';
    }
}

sub systemTypes
{
    return [
        { value => 'new_windows', printableValue =>  __('Windows Vista | Windows 2008 or newer') },
        { value => 'old_windows', printableValue =>  __('Windows XP | Windows 2003 or older') },
        { value => 'linux',       printableValue =>  __('Linux') },
        { value => 'other',       printableValue =>  __('Other') },
    ];
}

sub architectureTypes
{
    return [
        { value => 'i686',   printableValue =>  __('i686 compatible') },
        { value => 'x86_64', printableValue =>  __('amd64 compatible') },
    ];
}

sub manageScript
{
    my ($self, $name) = @_;

    return "$VM_PATH/$name/manage.sh";
}

sub createInternalNetworks
{
    my ($self, $name) = @_;

    mkdir ($NET_PATH) unless (-d $NET_PATH);

    foreach my $name (keys %{$self->{netConf}}) {
        next if ($self->_netExists($name));

        my $net = $self->{netConf}->{$name};
        my $bridge = $net->{bridge};
        my $netprefix = '192.168.' . $net->{num};
        my $file = "$NET_PATH/$name.xml";
        EBox::Module::Base::writeConfFileNoCheck(
            $file, '/virt/network.xml.mas',
            [ name => $name, bridge => $bridge, prefix => $netprefix ],
            { uid => 0, gid => 0, mode => '0644' }
         );
         $self->_createBridge($name, $file, $bridge, $netprefix);
    }
}

sub _createBridge
{
    my ($self, $name, $file, $bridge, $net) = @_;

    _run("$VIRTCMD net-create $file", 1);
    if ($? != 0) {
        _run("pkill -f \"dnsmasq.*/${name}.conf\"");
        _run("ifconfig virbr${bridge} down");
        _run("brctl delbr virbr${bridge}");
        _run("$VIRTCMD net-create $file");
    }
}

sub _netExists
{
    my ($self, $name) = @_;

    my $path = "$LIBVIRT_NET_PATH/$name.xml";
    return EBox::Sudo::fileTest('-e', $path);
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
              forceStopCmd => $vmConf->{forceStopCmd},
              runningCmd => $self->runningVMCommand($name),
              user => $self->{vmUser} ],
            { uid => 0, gid => 0, mode => '0755' }
    );

    # Set boot device according to the first device in the list
    my $bootDev = 'hd';
    my @devices = @{$vmConf->{devices}};
    if (@devices and ($devices[0]->{type} eq 'cdrom')) {
        $bootDev = 'cdrom';
    }

    my $os = $vmConf->{os};
    EBox::Module::Base::writeConfFileNoCheck(
        "$VM_PATH/$name/$VM_FILE",
        '/virt/domain.xml.mas',
        [
         name => $name,
         os   => $os,
         emulator => $self->{emulator},
         arch => $vmConf->{arch},
         memory => $vmConf->{memory},
         ifaces => $vmConf->{ifaces},
         devices => $vmConf->{devices},
         vncport => $vmConf->{port},
         vncpass => $vmConf->{password},
         keymap => _vncKeymap(),
         boot => $bootDev,
         mouse => $self->_mouseUsedByOs($os),
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

    $self->{driveLetterByBus} = {
        ide => 'a',
        scsi => 'a',
        sata => 'a',
        virtio => 'a',
    };
}

sub initInternalNetworks
{
    my ($self) = @_;

    $self->{netConf} = {};
    $self->{netNum} = 190;
    $self->{usedBridgeIds} = $self->_usedBridgeIds();
    $self->{netBridgeId} = 1;

    my @nets = glob ("$NET_PATH/*");
    foreach my $net (@nets) {
        my $path = "$LIBVIRT_NET_PATH/" . basename($net);
        _run("rm -rf $path");
    }
    _run("rm -rf $NET_PATH/*");
}

sub _usedBridgeIds
{
    my ($self) = @_;

    my $usedBridges = {};

    my $tmpdir = EBox::Config::tmp() . 'libvirt-networks';
    EBox::Sudo::root("mkdir -p $tmpdir",
                     "cp /etc/libvirt/qemu/networks/*.xml $tmpdir/",
                     "chmod 644 $tmpdir/*.xml");
    my @files = glob ("$tmpdir/*.xml");
    foreach my $file (@files) {
        my $content = read_file($file);
        my ($id) = ($content =~ /<bridge name='virbr(\d+)'/);
        if (defined $id) {
            $usedBridges->{$id} = 1;
        }
    }
    EBox::Sudo::root("rm -rf $tmpdir");

    return $usedBridges;
}

sub _freeBridgeId
{
    my ($self) = @_;

    while (exists $self->{usedBridgeIds}->{$self->{netBridgeId}}) {
        $self->{netBridgeId}++;
    }

    return $self->{netBridgeId};
}

sub _run
{
    my ($cmd, $silent) = @_;

    EBox::debug("Running: $cmd");
    if ($silent) {
        EBox::Sudo::silentRoot($cmd);
    } else {
        EBox::Sudo::rootWithoutException($cmd);
    }
}

sub diskFile
{
    my ($self, $disk, $machine) = @_;
    return "$VM_PATH/$machine/$disk.img";
}

sub _vncKeymap
{
    my %validKeymaps = map { basename($_) => 1 } glob ("$KEYMAP_PATH/*");

    my $keymap = EBox::Config::configkey('vnc_keymap');
    if ($keymap) {
        if ($validKeymaps{$keymap}) {
            return $keymap;
        } else {
            EBox::warn("VNC keymap '$keymap' is not valid, defaulting to '$DEFAULT_KEYMAP'");
            return $DEFAULT_KEYMAP;
        }
    } else {
        # Autodetect if not defined
        if ($ENV{LANG}) {
            my ($lang, $enc) = split(/\./, $ENV{LANG});
            my ($lang1, $lang2) = split(/_/, $lang);
            if ($lang1) {
                if ($lang2) {
                    $keymap = "$lang1-" . lc($lang2);
                    return $keymap if ($validKeymaps{$keymap});
                }
                return $lang1 if ($validKeymaps{$lang1});
            }
        }
        return $DEFAULT_KEYMAP;
    }
}

sub vmsPath
{
    return $VM_PATH;
}

sub daemons
{
    return [
        { name => 'virtlogd' },
        { name => 'libvirtd' },
        { name => 'zentyal.vncproxy' }
    ];
}

sub ifaces
{
    my $network = EBox::Global->modInstance('network');
    my @ifaces = EBox::NetWrappers::list_ifaces();
    @ifaces = grep { $network->ifaceIsBridge($_) } @ifaces;
    return @ifaces;
}

sub allowsNoneIface
{
    return 0;
}

1;
