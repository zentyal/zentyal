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
use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Types::Action;
use EBox::Types::HTML;

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

    # FIXME: Replace this with a EBox::Types::Action
    # when added support for custom javascript
    my $viewConsoleCaption = __('View Console');
    my $vncport = 6900;
    my $viewConsoleURL = "zentyal/Virt/VNC?port=$vncport";
    my $viewConsoleHTML =
"<link href=\"/data/css/modalbox.css\" rel=\"stylesheet\" type=\"text/css\" />
<script type=\"text/javascript\" src=\"/data/js/modalbox.js\">//</script>
<form><input type=\"submit\" value=\"$viewConsoleCaption\" onclick=\"Modalbox.show($viewConsoleURL, {title: '$viewConsoleCaption', width: 640, height: 435}); return false;\" /></form>";

    # TODO: Pause/Resume actions
    # TODO: Fusion start/stop in the same action
    my $customActions = [
        new EBox::Types::Action(
            name => 'start',
            printableValue => __('Start'),
            model => $self,
            handler => \&_doStart,
            message => __('Virtual Machine started'),
        ),
        new EBox::Types::Action(
            name => 'stop',
            printableValue => __('Stop'),
            model => $self,
            handler => \&_doStop,
            message => __('Virtual Machine stopped'),
        ),
    ];

    my @tableHeader = (
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
       new EBox::Types::HTML(
                             fieldName => 'viewconsole',
                             printableName => $viewConsoleHTML,
                            ),
       new EBox::Types::Boolean(
                                fieldName     => 'autostart',
                                printableName => __('Start on boot'),
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

sub _doStart
{
    my ($self, $action, %params) = @_;

    my $virt = $self->parentModule();

    my $name = $params{name};
    EBox::Service::manage($virt->machineDaemon($name), 'start');
    EBox::Service::manage($virt->vncDaemon($name), 'start');

    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

sub _doStop
{
    my ($self, $action, %params) = @_;

    my $virt = $self->parentModule();

    my $name = $params{name};
    EBox::Service::manage($virt->vncDaemon($name), 'stop');
    EBox::Service::manage($virt->machineDaemon($name), 'stop');

    $self->setMessage($action->message(), 'note');
    $self->{customActions} = {};
}

1;
