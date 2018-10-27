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

package EBox::Virt;

use base qw(EBox::Module::Service
            EBox::NetworkObserver
            EBox::FirewallObserver);

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Service;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo;
use EBox::Util::Version;
use EBox::Dashboard::Section;
use EBox::Virt::Dashboard::VMStatus;
use EBox::Virt::Model::NetworkSettings;
use EBox::Virt::Model::DeviceSettings;
use TryCatch;
use String::ShellQuote;
use File::Slurp;

use constant DEFAULT_VNC_PORT => 5900;
use constant LIBVIRT_BIN => '/usr/bin/virsh';
use constant DEFAULT_VIRT_USER => 'ebox';
use constant VNC_PASSWD_FILE => '/var/lib/zentyal/conf/vnc-passwd';
use constant VNC_TOKENS_FILE => '/var/lib/zentyal/conf/vnc-tokens';

my $SYSTEMD_PATH = '/lib/systemd/system';
my $WWW_PATH = EBox::Config::www();

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'virt',
                                      printableName => __('Virtual Machines'),
                                      @_);
    bless($self, $class);

    # Autodetect which virtualization suite is installed,
    # libvirt has priority if both are installed
    if (-x LIBVIRT_BIN) {
        eval 'use EBox::Virt::Libvirt';
        $self->{backend} = new EBox::Virt::Libvirt();
    } else {
        eval 'use EBox::Virt::VBox';
        $self->{backend} = new EBox::Virt::VBox();
    }

    my $user = EBox::Config::configkey('vm_user');
    unless ($user) {
        $user = DEFAULT_VIRT_USER;
    }
    $self->{vmUser} = $user;

    return $self;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    unless ($version) {
        # Create default service only if installing the first time
        my $services = EBox::Global->modInstance('network');

        my $serviceName = 'vnc-virt';
        unless ($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => __('Virtual Machines VNC'),
                'description' => __('VNC connections for Zentyal VMs'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => [
                                { protocol => 'tcp',
                                  sourcePort => 'any',
                                  destinationPort => DEFAULT_VNC_PORT },
                                { protocol => 'tcp',
                                  sourcePort => 'any',
                                  destinationPort => DEFAULT_VNC_PORT + 1000 }
                              ],
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setExternalService($serviceName, 'deny');
        $firewall->setInternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();

        # Force load of nginx-virt.conf
        EBox::Sudo::silentRoot("systemctl restart zentyal.webadmin-nginx");
    }
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Virt/View/VirtualMachines',
                                    'icon' => 'virt',
                                    'text' => $self->printableName(),
                                    'separator' => 'Infrastructure',
                                    'order' => 447));
}

sub _preSetConf
{
    my ($self) = @_;

    my $disabled = not $self->isEnabled();

    # The try is needed because this is also executed before
    # the systemd files for the machines are created, if
    # we made this code more intelligent probably it won't
    # be needed.
    try {
        my $vms = $self->model('VirtualMachines');
        foreach my $vmId (@{$vms->ids()}) {
            if ($disabled or $self->needsRewrite($vmId)) {
                my $vm = $vms->row($vmId);
                my $name = $vm->valueByName('name');
                if ($self->vmRunning($name)) {
                    $self->stopVM($name);
                }
            }
        }

        $self->_stopService();
    } catch {
    }
}

sub _setConf
{
    my ($self) = @_;

    my $backend = $self->{backend};

    # Clean all systemd and novnc files, the current ones will be regenerated
    EBox::Sudo::silentRoot("rm -rf $SYSTEMD_PATH/zentyal-virt.*.service",
                           "rm -rf $WWW_PATH/vncviewer-*.html");

    my %currentVMs;

    my %vncPasswords;
    # Syntax of the vnc passwords file:
    # machinename:password
    my @lines;
    if (-f VNC_PASSWD_FILE) {
        @lines = read_file(VNC_PASSWD_FILE);
        chomp(@lines);
        foreach my $line (@lines) {
            my ($machine, $pass) = split(/:/, $line);
            next unless ($machine and $pass);
            $vncPasswords{$machine} = $pass;
        }
    }
    my %vncPorts;

    $backend->initInternalNetworks();

    my $vms = $self->model('VirtualMachines');
    foreach my $vmId (@{$vms->ids()}) {
        my $vm = $vms->row($vmId);
        my $name = $vm->valueByName('name');
        $currentVMs{$name} = 1;

        my $rewrite = 1;
        if ($self->usingVBox()) {
            $rewrite = $self->needsRewrite($vmId);
        }

        my $settings = $vm->subModel('settings');
        my $system = $settings->componentByName('SystemSettings')->row();

        unless (exists $vncPasswords{$name}) {
            $vncPasswords{$name} = _randPassVNC();
        }

        if ($rewrite) {
            $self->_createMachine($name, $system);
            $self->_setNetworkConf($name, $settings);
            $self->_setDevicesConf($name, $settings);
        }

        my $vncport = $vm->valueByName('vncport');
        $vncPorts{$name} = $vncport;
        $self->_writeMachineConf($name, $vncport, $vncPasswords{$name});
        $backend->writeConf($name);
    }

    # Delete non-referenced VMs
    my $existingVMs = $backend->listVMs();
    my @toDelete = grep { not exists $currentVMs{$_} } @{$existingVMs};
    foreach my $machine (@toDelete) {
        $backend->deleteVM($machine);
        delete $vncPasswords{$machine};
    }

    # Update vnc passwords file
    @lines = map { "$_:$vncPasswords{$_}\n" } keys %vncPasswords;
    write_file(VNC_PASSWD_FILE, @lines);
    chmod (0600, VNC_PASSWD_FILE);

    # Write vncproxy tokens file
    @lines = map { "$_: 127.0.0.1:$vncPorts{$_}\n" } keys %vncPorts;
    write_file(VNC_TOKENS_FILE, @lines);
    chmod (0600, VNC_TOKENS_FILE);
}

sub updateFirewallService
{
    my ($self) = @_;

    my @vncservices;
    my $vms = $self->model('VirtualMachines');
    foreach my $vncport (@{$vms->vncPorts()}) {
        foreach my $vncport ($vncport, $vncport + 1000) {
            push (@vncservices, { protocol => 'tcp',
                                  sourcePort => 'any',
                                  destinationPort => $vncport });
        }
    }

    my $servMod = EBox::Global->modInstance('network');
    $servMod->setMultipleService(name => 'vnc-virt',
                                 printableName => __('Virtual Machines VNC'),
                                 description => __('VNC connections for Zentyal VMs'),
                                 allowEmpty => 1,
                                 internal => 1,
                                 services => \@vncservices);
}

sub machineDaemon
{
    my ($self, $name) = @_;

    return "zentyal-virt.$name";
}

sub vmRunning
{
    my ($self, $name) = @_;

    return $self->{backend}->vmRunning($name);
}

sub vmPaused
{
    my ($self, $name) = @_;

    return $self->{backend}->vmPaused($name);
}

sub diskFile
{
    my ($self, $vmName, $diskName) = @_;

    return $self->{backend}->diskFile($diskName, $vmName);
}

sub startVM
{
    my ($self, $name) = @_;

    $self->_manageVM($name, 'start');
}

sub stopVM
{
    my ($self, $name) = @_;

    $self->_manageVM($name, 'stop');
}

sub _manageVM
{
    my ($self, $name, $action) = @_;

    my $manageScript = $self->manageScript($name);
    $manageScript = shell_quote($manageScript);
    EBox::Sudo::root("$manageScript $action");
}

sub pauseVM
{
    my ($self, $name) = @_;

    return $self->{backend}->pauseVM($name);
}

sub resumeVM
{
    my ($self, $name) = @_;

    return $self->{backend}->resumeVM($name);
}

sub systemTypes
{
    my ($self) = @_;

    return $self->{backend}->systemTypes();
}

sub architectureTypes
{
    my ($self) = @_;

    return $self->{backend}->architectureTypes();
}

sub ifaces
{
    my ($self) = @_;
    return $self->{backend}->ifaces();
}

sub allowsNoneIface
{
    my ($self) = @_;
    return $self->{backend}->allowsNoneIface();
}

sub manageScript
{
    my ($self, $name) = @_;

    return $self->{backend}->manageScript($name);
}

my $needRewriteVMs;

sub needsRewrite
{
    my ($self, $vmId) = @_;

    return $needRewriteVMs->{$vmId};
}

sub _saveConfig
{
    my ($self) = @_;

    $needRewriteVMs = {};
    my $vms = $self->model('VirtualMachines');
    foreach my $vmId (@{$vms->ids()}) {
        if ($self->usingVBox()) {
            my $vm = $vms->row($vmId);
            my $settings = $vm->subModel('settings');
            my $system = $settings->componentByName('SystemSettings')->row();

            if ($system->valueByName('manageonly')) {
                $needRewriteVMs->{$vmId} = 0;
                next;
            }
        }
        $needRewriteVMs->{$vmId} = $vms->vmChanged($vmId);
    }

    $self->SUPER::_saveConfig();
}

sub _daemons
{
    my ($self) = @_;

    my @daemons;

    # Add virtualizer-specific daemons to manage, if any
    # Currently this is only the case of libvirt-bin
    push (@daemons, @{$self->{backend}->daemons()});

    return \@daemons;
}

sub _enforceServiceState
{
    my ($self) = @_;

    return unless $self->isEnabled();

    $self->_startService();

    $self->{backend}->createInternalNetworks();

    # Start machines marked as autostart
    my $vms = $self->model('VirtualMachines');
    foreach my $vmId (@{$vms->findAll('autostart' => 1)}) {
        my $vm = $vms->row($vmId);
        my $name = $vm->valueByName('name');
        unless ($self->vmRunning($name)) {
            $self->startVM($name);
        }
    }
}

sub _createMachine
{
    my ($self, $name, $system) = @_;

    my $backend = $self->{backend};
    my $memory = $system->valueByName('memory');
    my $os = $system->valueByName('os');
    my $arch = $system->valueByName('arch');

    $backend->createVM(name => $name);

    $backend->setOS($name, $os);
    $backend->setArch($name, $arch);
    $backend->setMemory($name, $memory);
}

sub _setNetworkConf
{
    my ($self, $name, $settings) = @_;

    my $backend = $self->{backend};
    my $ifaceNumber = 1;

    my $ifaces = $settings->componentByName('NetworkSettings');
    foreach my $ifaceId (@{$ifaces->ids()}) {
        my $iface = $ifaces->row($ifaceId);
        my $enabled = $iface->valueByName('enabled');

        my $type = 'none';
        my $arg = undef;
        if ($enabled) {
            $type = $iface->valueByName('type');
            if ($type eq 'bridged') {
                $arg = $iface->valueByName('iface');
            } elsif ($type eq 'internal') {
                $arg = $iface->valueByName('name');
            }
        }
        my $mac;
        if ($iface->elementExists('mac')) {
            $mac = $iface->valueByName('mac');
        }

        $backend->setIface(name => $name, iface => $ifaceNumber++,
                           type => $type, arg => $arg, mac => $mac);
    }

    # Unset the rest of the interfaces to prevent they stay from an old conf
    while ($ifaceNumber <= EBox::Virt::Model::NetworkSettings::MAX_IFACES()) {
        $backend->setIface(name => $name, iface => $ifaceNumber++,
                           type => 'none');
    }
}

sub _setDevicesConf
{
    my ($self, $name, $settings) = @_;

    my $backend = $self->{backend};

    # Clean all devices first (only needed for vbox)
    $backend->initDeviceNumbers();
    for (1 .. $backend->attachedDevices($name, 'cd')) {
        $backend->attachDevice(name => $name, type => 'cd', file => 'none');
    }
    for (1 .. $backend->attachedDevices($name, 'hd')) {
        $backend->attachDevice(name => $name, type => 'hd', file => 'none');
    }
    $self->_cleanupDeletedDisks();

    $backend->initDeviceNumbers();

    my $devices = $settings->componentByName('DeviceSettings');
    foreach my $deviceId (@{$devices->enabledRows()}) {
        my $device = $devices->row($deviceId);
        my $file;
        my $type = $device->valueByName('type');

        if (($type eq 'hd') and ($device->valueByName('disk_action') eq 'create')) {
            my $disk_name = $device->valueByName('name');
            my $size = $device->valueByName('size');
            $file = $backend->diskFile($disk_name, $name);
            unless (-f $file) {
                $backend->createDisk(file => $file, size => $size);
            }
        } elsif (($type eq 'cd') and $device->valueByName('useDevice')) {
            $file = $devices->CDDeviceFile();
        } else {
            $file = $device->valueByName('path');
        }

        $backend->attachDevice(name => $name, type => $type, file => $file);
    }
}

sub _writeMachineConf
{
    my ($self, $name, $vncport, $vncpass) = @_;

    my $backend = $self->{backend};

    my $start = $backend->startVMCommand(name => $name, port => $vncport, pass => $vncpass);
    my $stop = $backend->shutdownVMCommand($name);
    my $forceStop = $backend->shutdownVMCommand($name, 1);
    my $running = $backend->runningVMCommand($name);
    my $listenport = $vncport + 1000;

    EBox::Module::Base::writeConfFileNoCheck(
            "$SYSTEMD_PATH/" . $self->machineDaemon($name) . '.service',
            '/virt/systemd.mas',
            [ startCmd => $start, stopCmd => $stop, forceStopCmd => $forceStop, runningCmd => $running, user => $self->{vmUser} ],
            { uid => 0, gid => 0, mode => '0644' }
    );

    my $gid = getgrnam('www-data'); # nginx needs to read it
    EBox::Module::Base::writeConfFileNoCheck(
            EBox::Config::www() . "/vncviewer-$name.html",
            '/virt/vncviewer.html.mas',
            [ token => $name, password => $vncpass ],
            { uid => 0, gid => $gid, mode => '0640' }
    );
}

sub _cleanupDeletedDisks
{
    my ($self) = @_;

    my $deletedDisks = $self->model('DeletedDisks');

    foreach my $id (@{$deletedDisks->ids()}) {
        my $row = $deletedDisks->row($id);
        my $file = $row->valueByName('file');
        EBox::Sudo::root("rm -f $file");
    }

    $deletedDisks->removeAll(1);

    # mark as saved to avoid red button
    EBox::Global->getInstance()->modRestarted('virt');
}

# Method: widgets
#
#   Overriden method that returns the widgets offered by this module
#
# Overrides:
#
#       <EBox::Module::widgets>
#
sub widgets
{
    return {
        'machines' => {
            'title' => __('Virtual Machines'),
            'widget' => \&_vmWidget,
            'order' => 12,
            'default' => 1
        },
    };
}

# Method: maxVMs
#
#   return the maximum number of virtual machines allowed
sub maxVMs
{
    my ($self) = @_;

    my $max = EBox::Config::configkey('vm_max');
    return $max ? $max : 10;
}

sub firstVNCPort
{
    my ($self) = @_;

    my $vncport = EBox::Config::configkey('first_vnc_port');
    return $vncport ? $vncport : DEFAULT_VNC_PORT;
}

sub firstFreeVNCPort
{
    my ($self) = @_;

    my $vms = $self->model('VirtualMachines');
    my @ports = @{ $vms->vncPorts() };

    my $firstPort = $self->firstVNCPort();
    if (@ports == 0) {
        return $firstPort;
    }

    @ports = sort @ports;
    if ($ports[0] < $firstPort) {
        return $firstPort;
    }

    my $prev = shift @ports;
    foreach my $port (@ports) {
        if (($port - $prev) > 1) {
            # hole found
            return $prev + 1;
        }
        $prev = $port;
    }

    return $prev + 1;
}

sub viewNewWindow
{
    return EBox::Config::boolean('view_console_new_window');
}

sub usingVBox
{
    my ($self) = @_;

    return $self->{backend}->isa('EBox::Virt::VBox');
}

sub _vmWidget
{
    my ($self, $widget) = @_;

    my $backend = $self->{backend};

    my $section = new EBox::Dashboard::Section('status');
    $widget->add($section);

    my $vms = $self->model('VirtualMachines');
    foreach my $vmId (@{$vms->ids()}) {
        my $vm = $vms->row($vmId);
        my $name = $vm->valueByName('name');
        my $running = $backend->vmRunning($name);

        $section->add(new EBox::Virt::Dashboard::VMStatus(
                            id => $vmId,
                            model => $vms,
                            name => $name,
                            running => $running
                      )
        );
    }
}

sub _randPassVNC
{
    return join ('', map +(0..9,'a'..'z','A'..'Z')[rand(10+26*2)], 1..8);
}

sub freeIface
{
    my ($self, $iface) = @_;
    my $vms = $self->model('VirtualMachines');
    my $globalRO     = EBox::Global->getInstance(1);
    my $networkMod = $globalRO->modInstance('network');
    if ($networkMod->ifaceMethod($iface) eq 'bridged') {
        my $bridgeId = $networkMod->ifaceBridge($iface);
        if ($bridgeId) {
            my $bridge = "br$bridgeId";
            my $nBridgeIfaces = @{ $networkMod->bridgeIfaces($bridge) };
            if ($nBridgeIfaces == 1) {
                $vms->freeIface($bridge);
            }

        }
    }

    $vms->freeIface($iface);
}

sub freeViface
{
    my ($self, $iface, $viface) = @_;
    $self->freeIface($viface);
}

sub ifaceMethodChanged
{
    my ($self, $iface, $oldmethod, $newmethod) = @_;
    my $vms = $self->model('VirtualMachines');

    if ($oldmethod eq 'bridged') {
        my $globalRO     = EBox::Global->getInstance(1);
        my $networkMod = $globalRO->modInstance('network');
        my $bridgeId = $networkMod->ifaceBridge($iface);
        if ($bridgeId) {
            my $bridge = "br$bridgeId";
            my $nBridgeIfaces = @{ $networkMod->bridgeIfaces($bridge) };
            if ($nBridgeIfaces == 1) {
                my $inconsistent =
                    $vms->ifaceMethodChanged($bridge, $networkMod->ifaceMethod($bridge) ,'notset');
                if ($inconsistent) {
                    return $inconsistent;
                }
            }
        }
    }

    $vms->ifaceMethodChanged($iface, $oldmethod, $newmethod);
}

sub usesPort
{
    my ($self, $protocol, $port, $iface) = @_;
    if ($protocol ne 'tcp') {
        return undef;
    }

    my $firstPort = $self->firstVNCPort();
    my $lastPort = $firstPort + $self->maxVMs() - 1;
    if (($port >= $firstPort) and ($port <= $lastPort)) {
        return 1;
    }

    # second required VNC port: + 1000 port
    $firstPort += 1000;
    $lastPort  += 1000;
    if (($port >= $firstPort) and ($port <= $lastPort)) {
        return 1;
    }

    return undef;
}

1;
