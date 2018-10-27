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

# Class: EBox::Virt::Model::VirtualMachines
#
#      Table of Virtual Machines
#
package EBox::Virt::Model::VirtualMachines;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Service;
use EBox::Types::Text;
use EBox::Exceptions::External;
use EBox::Virt::Types::Status;
use EBox::Types::Boolean;
use EBox::Types::Port;
use EBox::Types::HasMany;
use EBox::Types::Action;
use EBox::Types::MultiStateAction;

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $customActions = [
        new EBox::Types::Action(
            model => $self,
            name => 'viewConsole',
            printableValue => __('View Console'),
            onclick => \&_viewConsoleClicked,
            image => '/data/images/terminal.gif',
        ),
        new EBox::Types::MultiStateAction(
            acquirer => \&_acquireRunning,
            model => $self,
            states => {
                stopped => {
                    name => 'start',
                    printableValue => __('Start'),
                    handler => \&_doStart,
                    message => __('Virtual Machine started'),
                    image => '/data/images/play.gif',
                },
                started => {
                    name => 'stop',
                    printableValue => __('Stop'),
                    handler => \&_doStop,
                    message => __('Virtual Machine stopped'),
                    image => '/data/images/stop.gif',
                },
            }
        ),
        new EBox::Types::MultiStateAction(
            acquirer => \&_acquirePaused,
            model => $self,
            states => {
                unpaused => {
                    name => 'pause',
                    printableValue => __('Pause'),
                    handler => \&_doPause,
                    message => __('Virtual Machine paused'),
                    image => '/data/images/pause.gif',
                },
                paused => {
                    name => 'resume',
                    printableValue => __('Resume'),
                    handler => \&_doResume,
                    message => __('Virtual Machine resumed'),
                    image => '/data/images/resume.gif',
                },
            }
        ),
    ];

    my @tableHeader = (
       new EBox::Types::Port(
                             fieldName => 'vncport',
                             optional => 1,
                             unique => 1,
                             editable => 1,
                             hidden => 1,
                            ),
       new EBox::Virt::Types::Status(
                                     fieldName => 'status',
                                     printableName => __('Status'),
                                    ),
       new EBox::Types::Text(
                             fieldName     => 'name',
                             printableName => __('Name'),
                             size          => 16,
                             unique        => 1,
                             editable      => 1,
                            ),
       new EBox::Types::HasMany(
                                fieldName     => 'settings',
                                printableName => __('Settings'),
                                foreignModel  => 'virt/VMSettings',
                                foreignModelIsComposite => 1,
                                view => '/Virt/Composite/VMSettings',
                                backView => '/Virt/View/VirtualMachines',
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'autostart',
                                printableName => __('Autostart'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
    );

    my $dataTable =
    {
        tableName          => 'VirtualMachines',
        printableTableName => __('List of Virtual Machines'),
        pageTitle          => __('Virtual Machines'),
        printableRowName   => __('virtual machine'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        customActions      => $customActions,
        tableDescription   => \@tableHeader,
        help               => __('List of configured Virtual Machines.'),
        modelDomain        => 'Virt',
        defaultEnabledValue => 1,
    };

    return $dataTable;
}

# FIXME: pass RO model instance instead of row id
# once the ModelManager bug is fixed, uncomment all the stuff after that
sub vmChanged
{
    my ($self, $id) = @_;

    my $vm = $self->row($id);

    my $virtRO = EBox::Global->getInstance(1)->modInstance('virt');
    my $vmsRO = $virtRO->model('VirtualMachines');
    my $vmRO = $vmsRO->row($id);

    return 1 unless defined ($vmRO);

    my $name = $vm->valueByName('name');
    my $nameRO = $vmRO->valueByName('name');

    return 1 unless ($name eq $nameRO);

    my $auto = $vm->valueByName('autostart');
    my $autoRO = $vmRO->valueByName('autostart');
    return 1 if ($auto and not $autoRO);

    my $settings = $vm->subModel('settings');
    #my $settingsRO = $vmRO->subModel('settings');
    my $system = $settings->componentByName('SystemSettings');
    #my $systemRO = $settingsRO->componentByName('SystemSettings');
    return 1 if ($auto and not $autoRO);
    #return 1 unless $system->isEqual($systemRO);
    return 1 unless $system->isEqual($id);

    my $network = $settings->componentByName('NetworkSettings');
    #my $networkRO = $settingsRO->componentByName('NetworkSettings');
    #return 1 unless $network->isEqual($networkRO);
    return 1 unless $network->isEqual($id);

    my $devices = $settings->componentByName('DeviceSettings');
    #my $devicesRO = $settingsRO->componentByName('DeviceSettings');
    #return 1 unless $devices->isEqual($devicesRO);
    return 1 unless $devices->isEqual($id);

    return 0;
}

sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    if (exists $changedFields->{name}) {
        my $value = $changedFields->{name}->value();
        unless ($value =~ /^[A-Za-z0-9_-]+$/) {
            throw EBox::Exceptions::InvalidData(
                data => __('Name'),
                value => $value,
                advice => __(q{You have either invalid characters or spaces. Valid characters are: '[A-Z][a-z][0-9]-_'})
            );
        }
    }

    if ($action eq 'add') {
        my $max = $self->parentModule()->maxVMs();
        my $nVms = $self->size();
        if ($nVms >= $max) {
            throw EBox::Exceptions::External(
                __('Cannot add more virtual machines because its maximum allowed number has been reached')
               );
        }
    }
}

sub _acquireRunning
{
    my ($self, $id) = @_;

    my $name = $self->row($id)->valueByName('name');
    my $virt = $self->parentModule();

    my $running = $virt->vmRunning($name);
    return ($running) ? 'started' : 'stopped';
}

sub _viewConsoleClicked
{
    my ($self, $id) = @_;

    my $virt = $self->parentModule();
    my $name = $self->row($id)->valueByName('name');

    unless ($virt->vmRunning($name)) {
        return "return false";
    }

    my $viewConsoleURL = "/data/vncviewer-$name.html";
    my $viewConsoleCaption = __('View Console') . " ($name)";

    if ($virt->viewNewWindow()) {
        return "window.open('$viewConsoleURL'); return false";
    } else {
        return "Zentyal.Dialog.showURL('$viewConsoleURL', {title: '$viewConsoleCaption', wideWindow : true, dialogClass: 'VMConsole' }); return false";
    }
}

sub _acquirePaused
{
    my ($self, $id) = @_;

    my $name = $self->row($id)->valueByName('name');
    my $virt = $self->parentModule();

    my $paused = $virt->vmPaused($name);
    return ($paused) ? 'paused' : 'unpaused';
}

sub _doStart
{
    my ($self, $action, $id, %params) = @_;

    my $virt = $self->parentModule();
    my $row = $self->row($id);
    my $name = $row->valueByName('name');

    if ($virt->vmPaused($name)) {
        return $self->_doResume($action, $id, %params);
    }

    # Start machine precondition: module enable and without unsaved changes
    unless ($virt->isEnabled()) {
        throw EBox::Exceptions::External(__x('The Virtual Machines module is not enabled, please go to the {openref}Module Status{closeref} section and enable it prior to try to start any machine.', openref => '<a href="/ServiceModule/StatusView">', closeref => '</a>'));
    }
    if ($virt->changed()) {
        throw EBox::Exceptions::External(__('Virtual machines cannot be started if there are pending unsaved changes on the Virtual Machines module, please save changes first and try again.'));
    }

    $virt->startVM($name);

    my $tries = 30;
    sleep(1) while ($tries-- and not $virt->vmRunning($name));

    if ($virt->vmRunning($name)) {
        EBox::debug("Virtual machine '$name' started");
        $self->setMessage($action->message(), 'note');

        # Send alert if possible
        my $roGlobal  = EBox::Global->getInstance(1);
        if ( $roGlobal->modExists('cloud-prof') ) {
            my $cloudProf = $roGlobal->modInstance('cloud-prof');
            $cloudProf->zentyalVMStartAlert($name);
        }
    } else {
        throw EBox::Exceptions::External(
            __x("Couldn't start virtual machine '{vm}'", vm => $name));
    }
}

sub _doStop
{
    my ($self, $action, $id, %params) = @_;

    my $virt = $self->parentModule();
    my $row = $self->row($id);

    my $name = $row->valueByName('name');
    $virt->stopVM($name);

    my $tries = 30;
    sleep(1) while ($tries-- and $virt->vmRunning($name));

    if (not $virt->vmRunning($name)) {
        EBox::debug("Virtual machine '$name' stopped");
        $self->setMessage($action->message(), 'note');

        # Send alert if possible
        my $roGlobal  = EBox::Global->getInstance(1);
        if ( $roGlobal->modExists('cloud-prof') ) {
            my $cloudProf = $roGlobal->modInstance('cloud-prof');
            $cloudProf->zentyalVMStopAlert($name);
        }
    } else {
        throw EBox::Exceptions::External(
            __x("Couldn't stop virtual machine '{vm}'", vm => $name));
    }
}

sub _doPause
{
    my ($self, $action, $id, %params) = @_;

    my $virt = $self->parentModule();
    my $row = $self->row($id);

    my $name = $row->valueByName('name');

    unless ($virt->vmRunning($name)) {
        throw EBox::Exceptions::External(__('Cannot pause a stopped machine. You have to start it first.'));
    }

    $virt->pauseVM($name);

    EBox::debug("Virtual machine '$name' paused");
    $self->setMessage($action->message(), 'note');
}

sub _doResume
{
    my ($self, $action, $id, %params) = @_;

    my $virt = $self->parentModule();
    my $row = $self->row($id);

    my $name = $row->valueByName('name');
    $virt->resumeVM($name);

    EBox::debug("Virtual machine '$name' resumed");
    $self->setMessage($action->message(), 'note');
}

sub freeIface
{
    my ($self, $iface) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $settings = $row->subModel('settings');
        my $networkSettings = $settings->componentByName('NetworkSettings');
        $networkSettings->freeIface($iface);
    }
}

sub ifaceMethodChanged
{
    my ($self, $iface, $oldmethod, $newmethod) = @_;
    foreach my $id (@{ $self->ids()  }) {
        my $confInconsistent;
        my $row = $self->row($id);
        my $settings = $row->subModel('settings');
        my $networkSettings = $settings->componentByName('NetworkSettings');
        $confInconsistent = $networkSettings->ifaceMethodChanged($iface, $oldmethod, $newmethod);
        if ($confInconsistent) {
            return $confInconsistent;
        }
    }

    return undef;
}

# set VNC port and service
sub addedRowNotify
{
    my ($self, $row) = @_;
    my $virt = $self->{confmodule};

    my $vncport = $row->valueByName('vncport');
    if (not $vncport) {

        $vncport = $virt->firstFreeVNCPort();
        $row->elementByName('vncport')->setValue($vncport);
        $row->store();
    }

    $virt->updateFirewallService();
}

sub deletedRowNotify
{
    my ($self, $row) = @_;
    my $virt = $self->{confmodule};
    $virt->updateFirewallService();

    # stop VM
    my $name = $row->valueByName('name');
    if ($virt->vmRunning($name) or $virt->vmPaused($name)) {
        $virt->stopVM($name);
    }
}

sub vncPorts
{
    my ($self) = @_;
    my @ports;
    foreach my $vmId (@{$self->ids()}) {
        my $vm = $self->row($vmId);
        my $vncport = $vm->valueByName('vncport');
        push @ports, $vncport if $vncport;
    }

    return \@ports;
}

sub actionClickedJS
{
    my ($self, $action, @params) = @_;
    my $actionJS = $self->SUPER::actionClickedJS($action, @params);
    if ($action ne 'del') {
        return $actionJS;
    }
    my $title = __('Remove virtual machine');
    my $message = __('Are you sure about removing this virtual machine?. All its data will be lost. ');
    my $confirmJS = <<"END_JS";
       var dialogParams = {
           title: '$title',
           message: '$message'
       };
       var accept= function() { $actionJS };
       Zentyal.TableHelper.showConfirmationDialog(dialogParams, accept);
END_JS
    return $confirmJS;
}

1;
