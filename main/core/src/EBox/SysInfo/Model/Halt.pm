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

package EBox::SysInfo::Model::Halt;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Action;
use EBox::DBEngineFactory;
use EBox::Util::Lock;
use TryCatch;

my $haltInProgress;

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

sub _table
{
    my ($self) = @_;

    my $customActions = [
        new EBox::Types::Action(
            name => 'halt',
            printableValue => __('Halt'),
            model => $self,
            handler => \&_doHalt,
            message => __('Zentyal is going down for halt'),
            enabled => \&_buttonEnabled,
        ),
        new EBox::Types::Action(
            name => 'reboot',
            printableValue => __('Reboot'),
            model => $self,
            handler => \&_doReboot,
            message => __("Zentyal is going down for reboot"),
            enabled => \&_buttonEnabled,
        ),
    ];

    my $form = {
        tableName => 'Halt',
        modelDomain => 'SysInfo',
        pageTitle => __('Halt or Reboot'),
        defaultActions => [],
        customActions => $customActions,
        tableDescription => [],
        message =>  __('You might lose your Internet connection if this machine is halted.'),
        messageClass => 'warning',
    };
    return $form;
}

# Method: popMessage
#
#     Get the message to show. Overrided to not delete the current message,
#     messages of this model are permanent (till reboot) by default.
#
# Overrides:
#
#     EBox::SysInfo::Model::DataTable::popMessage
sub popMessage
{
    my ($self) = @_;
    return $self->message();
}

sub _doHalt
{
    my ($self, $action) = @_;
    $self->_updateHaltInProgress();
    if ($haltInProgress) {
        return;
    }
    $haltInProgress = 1;

    $self->_prepareSystemForHalt($action);
    EBox::Sudo::root('/sbin/poweroff');
}

sub _doReboot
{
    my ($self, $action) = @_;
    $self->_updateHaltInProgress();
    if ($haltInProgress) {
        return;
    }
    $haltInProgress = 1;

    $self->_prepareSystemForHalt($action);
    EBox::Sudo::root("/sbin/reboot");
}

# this is to detect hatl/reboot from other processes
sub _updateHaltInProgress
{
    my ($class) = @_;
    try {
        EBox::Util::Lock::lock("sysinfo-halt");
        # it is a system halt/reboot so we will not unlock this
    } catch {
        $haltInProgress = 1;
    }
}

sub _prepareSystemForHalt
{
    my ($self, $action) = @_;
    my $actionName = $action->name();
    my $actionMsg  = $action->message();

    try {
        my $audit = $self->global()->modInstance('audit');
        $audit->logShutdown($actionName);
    } catch ($ex) {
        EBox::error("Error logging halt/reboot: $ex");
    }

    try {
        # flush db
        my $dbEngine = EBox::DBEngineFactory::DBEngine();
        $dbEngine->multiInsert();
    } catch ($ex)  {
        EBox::error("Error when flushing database before halt/reboot: $ex");
    }

    EBox::info($actionMsg);
    $self->setMessage($actionMsg, 'note');
}

sub _buttonEnabled
{
    __PACKAGE__->_updateHaltInProgress();
    return not $haltInProgress;
}

1;
