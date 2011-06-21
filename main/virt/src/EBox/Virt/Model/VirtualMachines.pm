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

package EBox::Virt::Model::VirtualMachines;

# Class: EBox::Virt::Model::VirtualMachines
#
#      Table of Virtual Machines
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Service;
use EBox::Types::Text;
use EBox::Exceptions::External;
use EBox::Virt::Types::Status;
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Types::Action;
use EBox::Types::MultiStateAction;

# Group: Public methods

# Constructor: new
#
#       Create the new VirtualMachines model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Virt::Model::VirtualMachines> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

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

    # TODO: Pause/Resume actions
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
                    image => '/data/images/play.gif',
                },
            }
        ),
    ];

    my @tableHeader = (
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
                                view => '/zentyal/Virt/Composite/VMSettings',
                                backView => '/zentyal/Virt/View/VirtualMachines',
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

    my $name = $self->row($id)->valueByName('name');
    my $width = 750;
    my $height = 520;

    my $viewConsoleURL = "/data/vncviewer-$name.html";
    my $viewConsoleCaption = __('View Console') . " ($name)";

    return "Modalbox.show('$viewConsoleURL', {title: '$viewConsoleCaption', width: $width, height: $height}); return false",
}

sub _acquirePaused
{
    my ($self, $id) = @_;

    my $name = $self->row($id)->valueByName('name');
    my $virt = $self->parentModule();

    #FIXME: implement this: my $paused = $virt->vmPaused($name);
    my $paused = $virt->vmRunning($name);
    return ($paused) ? 'paused' : 'unpaused';
}

sub _doStart
{
    my ($self, $action, $id, %params) = @_;

    my $virt = $self->parentModule();
    my $row = $self->row($id);

    my $name = $row->valueByName('name');
    EBox::Service::manage($virt->machineDaemon($name), 'start');
    EBox::Service::manage($virt->vncDaemon($name), 'start');

    my $tries = 30;
    sleep(1) while ($tries-- and not $virt->vmRunning($name));

    if ($virt->vmRunning($name)) {
        EBox::debug("Virtual machine '$name' started");
        $self->setMessage($action->message(), 'note');
    } else {
        throw EBox::Exceptions::External(
            __("Couldn't start '$name' virtual machine"));
    }
}

sub _doStop
{
    my ($self, $action, $id, %params) = @_;

    my $virt = $self->parentModule();
    my $row = $self->row($id);

    my $name = $row->valueByName('name');
    EBox::Service::manage($virt->vncDaemon($name), 'stop');
    EBox::Service::manage($virt->machineDaemon($name), 'stop');

    my $tries = 30;
    sleep(1) while ($tries-- and $virt->vmRunning($name));

    if (not $virt->vmRunning($name)) {
        EBox::debug("Virtual machine '$name' stopped");
        $self->setMessage($action->message(), 'note');
    } else {
        throw EBox::Exceptions::External(
            __("Couldn't stop '$name' virtual machine"));
    }
}

sub _doPause
{
    my ($self, $action, $id, %params) = @_;

    my $virt = $self->parentModule();
    my $row = $self->row($id);

    my $name = $row->valueByName('name');
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

1;
