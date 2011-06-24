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

package EBox::Virt;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider);

use EBox;
use EBox::Gettext;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use Error qw(:try);
use EBox::Sudo;
use EBox::Dashboard::Section;
use EBox::Virt::Dashboard::VMStatus;

use constant VNC_PORT => 5900;
use constant LIBVIRT_BIN => '/usr/bin/virsh';

my $UPSTART_PATH = '/etc/init/';

# TODO: move this to /etc/zentyal/virt.conf ?
my $VIRT_USER = 'ebox';

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

}

sub modelClasses
{
    return [
        'EBox::Virt::Model::VirtualMachines',
        'EBox::Virt::Model::SystemSettings',
        'EBox::Virt::Model::NetworkSettings',
        'EBox::Virt::Model::DeviceSettings',
    ];
}

sub compositeClasses
{
    return [ 'EBox::Virt::Composite::VMSettings' ];
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Virt/View/VirtualMachines',
                                    'text' => $self->printableName(),
                                    'separator' => 'Infrastructure',
                                    'order' => 445));
}

sub _preSetConf
{
    my ($self) = @_;

    # FIXME: Do this only if needed? (disk have changed, etc)
    $self->_stopService();
}

sub _setConf
{
    my ($self) = @_;

    my $backend = $self->{backend};

    # Clean all upstart files, the current ones will be regenerated
    EBox::Sudo::silentRoot("rm -rf $UPSTART_PATH/zentyal-virt.*.conf");

    my %currentVMs;

    my $vncport = VNC_PORT;
    my $vms = $self->model('VirtualMachines');
    foreach my $vmId (@{$vms->ids()}) {
        my $vm = $vms->row($vmId);

        my $name = $vm->valueByName('name');
        my $settings = $vm->subModel('settings');
        my $autostart = $vm->valueByName('autostart');

        $currentVMs{$name} = 1;
        $self->_createMachine($name, $settings);
        $self->_setNetworkConf($name, $settings);
        $self->_setDevicesConf($name, $settings);

        $self->st_set_string("vncport/$name/vncport", $vncport);
        $self->_writeMachineConf($name, $vncport);
        $vncport++;

        # Only used for libvirt
        $backend->writeConf($name);
    }

    # Delete non-referenced VMs
    my $existingVMs = $backend->listVMs();
    my @toDelete = grep { not exists $currentVMs{$_} } @{$existingVMs};
    foreach my $machine (@toDelete) {
        $backend->deleteVM($machine);
    }
}

sub machineDaemon
{
    my ($self, $name) = @_;

    return "zentyal-virt.$name";
}

sub vncDaemon
{
    my ($self, $name) = @_;

    return "zentyal-virt.vnc.$name";
}

sub vmRunning
{
    my ($self, $name) = @_;

    return $self->{backend}->vmRunning($name);
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
    my ($self, $name) = @_;

    return $self->{backend}->systemTypes();
}

sub _daemons
{
    my ($self) = @_;

    my @daemons;

    my $vms = $self->model('VirtualMachines');
    foreach my $vmId (@{$vms->findAllValue(autostart => 1)}) {
        my $vm = $vms->row($vmId);
        my $name = $vm->valueByName('name');
        push (@daemons, { name => $self->machineDaemon($name) });
        push (@daemons, { name => $self->vncDaemon($name) });
    }

    return \@daemons;
}

sub _createMachine
{
    my ($self, $name, $settings) = @_;

    my $backend = $self->{backend};
    my $system = $settings->componentByName('SystemSettings')->row();
    my $memory = $system->valueByName('memory');
    my $os = $system->valueByName('os');

    $backend->createVM(name => $name, os => $os);
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
        my $type = $iface->valueByName('type');
        my $ifaceName = $iface->valueByName('iface');

        unless ($enabled) {
            $type = 'none';
        }

        $backend->setIface(name => $name,
                           iface => $ifaceNumber++,
                           type => $type,
                           arg => $ifaceName);
    }
}

sub _setDevicesConf
{
    my ($self, $name, $settings) = @_;

    my $backend = $self->{backend};

    # Only used for vbox
    $backend->initDeviceNumbers();

    # TODO: Manage deleted disks...
    my $devices = $settings->componentByName('DeviceSettings');
    foreach my $deviceId (@{$devices->enabledRows()}) {
        my $device = $devices->row($deviceId);
        my $file;
        my $type = $device->valueByName('type');
        my $disk_action;
        if ($type eq 'hd') {
            $disk_action = $device->valueByName('disk_action');
        }

        if ($disk_action eq 'create') {
            my $disk_name = $device->valueByName('name');
            my $size = $device->valueByName('size');
            $file = $backend->diskFile($disk_name, $name);
            unless (-f $file) {
                $backend->createDisk(file => $file, size => $size);
            }
        } else {
            $file = $device->valueByName('path');
        }

        $backend->attachDevice(name => $name, type => $type, file => $file);
    }
}

sub _writeMachineConf
{
    my ($self, $name, $vncport) = @_;

    my $backend = $self->{backend};

    my $start = $backend->startVMCommand(name => $name, port => $vncport);
    my $stop = $backend->shutdownVMCommand($name);
    # TODO: Check if port is free
    my $listenport = $vncport + 1000;

    EBox::Module::Base::writeConfFileNoCheck(
            "$UPSTART_PATH/" . $self->machineDaemon($name) . '.conf',
            '/virt/upstart.mas',
            [ startCmd => $start, stopCmd => $stop, user => $VIRT_USER ],
            { uid => 0, gid => 0, mode => '0644' }
    );
    EBox::Module::Base::writeConfFileNoCheck(
            "$UPSTART_PATH/" . $self->vncDaemon($name) . '.conf',
            '/virt/vncproxy.mas',
            [ vncport => $vncport, listenport => $listenport ],
            { uid => 0, gid => 0, mode => '0644' }
    );
    EBox::Module::Base::writeConfFileNoCheck(
            EBox::Config::www() . "/vncviewer-$name.html",
            '/virt/vncviewer.html.mas',
            [ port => $listenport, width => 720, height => 455 ],
            { uid => 0, gid => 0, mode => '0644' }
    );
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

1;
