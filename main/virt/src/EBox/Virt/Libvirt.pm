# Copyright (C) 2011-2012 Zentyal S.L.
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
use EBox::NetWrappers;
use EBox::Virt;
use File::Basename;
use String::ShellQuote;

my $VM_PATH = '/var/lib/zentyal/machines';
my $NET_PATH = '/var/lib/zentyal/vnets';
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

    $self->{vmConf}->{$name}->{arch} = $os;
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
            # FIXME: Check if the address is not used
            $self->{netConf}->{$source}->{bridge} = $self->{netBridgeId}++;
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
    if ($cd or (EBox::Config::configkey('use_ide_disks') eq 'yes')) {
        $device->{bus} = 'ide';
        $device->{letter} = $self->{ideDriveLetter};
        $self->{ideDriveLetter} = chr (ord ($self->{ideDriveLetter}) + 1);
    } else {
        $device->{bus} = 'scsi';
        $device->{letter} = $self->{scsiDriveLetter};
        $self->{scsiDriveLetter} = chr (ord ($self->{scsiDriveLetter}) + 1);
    }

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
         $self->_createBridge($file, $bridge, $netprefix);
    }
}

sub _createBridge
{
    my ($self, $file, $bridge, $net) = @_;

    _run("$VIRTCMD net-create $file");
    if ($? != 0) {
        _run("pkill -f \"dnsmasq.* --listen-address ${net}.1\"");
        _run("ifconfig virbr${bridge} down");
        _run("brctl delbr virbr${bridge}");
        _run("$VIRTCMD net-create $file");
    }
}

sub _netExists
{
    my ($self, $name) = @_;

    EBox::Sudo::silentRoot("$VIRTCMD net-list|awk '{ print $1 }'|tail -n+3|grep \"^$name\$\"");
    return ($? == 0);
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

    # Set boot device according to the first device in the list
    my $bootDev = 'hd';
    my @devices = @{$vmConf->{devices}};
    if (@devices and ($devices[0]->{type} eq 'cdrom')) {
        $bootDev = 'cdrom';
    }

    EBox::Module::Base::writeConfFileNoCheck(
        "$VM_PATH/$name/$VM_FILE",
        '/virt/domain.xml.mas',
        [
         name => $name,
         emulator => $self->{emulator},
         arch => $vmConf->{arch},
         memory => $vmConf->{memory},
         ifaces => $vmConf->{ifaces},
         devices => $vmConf->{devices},
         vncport => $vmConf->{port},
         vncpass => $vmConf->{password},
         keymap => _vncKeymap(),
         boot => $bootDev,
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

    $self->{ideDriveLetter} = 'a';
    $self->{scsiDriveLetter} = 'a';
}

sub initInternalNetworks
{
    my ($self) = @_;

    $self->{netConf} = {};
    $self->{netNum} = 190;
    $self->{netBridgeId} = 1;

    _run("rm -rf $NET_PATH/*");
}

sub _run
{
    my ($cmd) = @_;

    EBox::debug("Running: $cmd");
    EBox::Sudo::rootWithoutException($cmd);
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
            my ($lang1, $lang2) = split(/_/, $ENV{LANG});
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
    return [ { name => 'libvirt-bin' } ];
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
