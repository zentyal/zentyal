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

package EBox::AuditLogging;

use base qw(EBox::Module::Service EBox::LogObserver);

use POSIX qw(getlogin);

use EBox::Global;
use EBox::Gettext;
use EBox::DBEngineFactory;

use constant TABLE_ACTIONS => 'audit_actions';
use constant TABLE_SESSIONS => 'audit_sessions';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name => 'audit',
        printableName => __('Audit Logging'),
        @_
    );

    bless ($self, $class);
    return $self;
}

sub _db
{
    my ($self) = @_;
    unless ($self->{db}) {
        $self->{db} = EBox::DBEngineFactory::DBEngine();
    }
    return $self->{db};
}

# Method: showModuleStatus
#
#   Indicate to ServiceManager if the module must be shown in Module
#   status configuration.
#
# Overrides:
#   EBox::Module::Service::showModuleStatus
#
sub showModuleStatus
{
    # we don't want it to appear in module status
    return undef;
}

# Method: addModuleStatus
#
# Overrides:
#   EBox::Module::Service::addModuleStatus
#
sub addModuleStatus
{
    # we don't want it to appear in the dashboard widget
    return undef;
}

# Method: enableLog
#
#   Overrides <EBox::LogObserver::enableLog>
#
#
sub enableLog
{
    my ($self, $enable) = @_;

    $self->set_bool('logging', $enable);
    $self->global()->addModuleToPostSave('audit');
}

sub isEnabled
{
    my ($self) = @_;
    if ($self->{dontLog}) {
        return 0;
    }

    # Get readonly value to avoid disable of logging before saving changes
    my $globalRO = EBox::Global->getInstance(1);
    return $globalRO->modInstance('audit')->get_bool('logging') ? 1 : 0;
}

# Method: tableInfo
#
# Overrides:
#
#   <EBox::LogObserver::tableInfo>
sub tableInfo
{
    my $action_titles = {
        'timestamp' => __('Date/Time'),
        'username' => __('User'),
        'module' => __('Module'),
        'model' => __('Section'),
        'event' => __('Event'),
        'id' => __('Identifier'),
        'value' => __('Value'),
        'oldvalue' => __('Previous value'),
    };
    my @action_order = qw{timestamp username module model event id value oldvalue};
    my $action_events = {
        'add' => __('Add'),
        'set' => __('Set'),
        'del' => __('Delete'),
        'move' => __('Move'),
        'action' => __('Action'),
    };
    my $action_table = {
        'name' => __('Configuration changes'),
        'tablename' => TABLE_ACTIONS,
        'titles' => $action_titles,
        'order' => \@action_order,
        'timecol' => 'timestamp',
        'filter' => ['username', 'module', 'model'],
        'events' => $action_events,
        'eventcol' => 'event',
        'autoFilter' => {'temporal' => 0},
    };

    my $session_titles = {
        'timestamp' => __('Date/Time'),
        'username' => __('User'),
        'ip' => __('IP'),
        'event' => __('Event'),
    };
    my @session_order = qw{timestamp username ip event};
    my $session_events = {
        'login' => __('Login'),
        'logout' => __('Logout'),
        'fail' => __('Failed login'),
        'expired' => __('Expired session'),
    };
    my $session_table = {
        'name' => __('Administrator sessions'),
        'tablename' => TABLE_SESSIONS,
        'titles' => $session_titles,
        'order' => \@session_order,
        'timecol' => 'timestamp',
        'filter' => ['username', 'ip'],
        'events' => $session_events,
        'eventcol' => 'event',
        'disabledByDefault' => 1,
        'types' => { 'ip' => 'IPAddr' }
    };

    return [
        $action_table,
        $session_table
    ];
}

sub queryPending
{
    my ($self) = @_;

    return unless $self->isEnabled();

    return
        $self->_db()->query('SELECT * FROM ' . TABLE_ACTIONS . ' WHERE temporal = TRUE ');
}

sub commit
{
    my ($self) = @_;

    return unless $self->isEnabled();

    $self->_db()->update(TABLE_ACTIONS, {'temporal' => 'FALSE'}, ['temporal = TRUE']);
}

sub discard
{
    my ($self) = @_;

    return unless $self->isEnabled();

    $self->_db()->{multiInsert}->{TABLE_ACTIONS} = [];
    $self->_db()->delete(TABLE_ACTIONS, ['temporal = TRUE']);
}

sub _timestamp
{
    my ($self) = @_;
    my ($sec, $min, $hour, $day, $month, $year) = localtime(time());
    $year += 1900;
    $month++;
    # TODO: Show this localized? Check the behavior in the rest of the logs
    return "$year-$month-$day $hour:$min:$sec";
}

sub _username
{
    my ($self) = @_;
    unless (defined $self->{username}) {
        # It is a script or cloud (or something unexpected is happening)
        $self->{username} = POSIX::getlogin();
    }
    return $self->{username};
}

sub setUsername
{
    my ($self, $username) = @_;
    $self->{username} = $username;
}

sub logModelAction
{
    my ($self, $model, $event, $id, $value, $oldvalue, $temporal) = @_;

    my $module = $model->parentModule()->name();
    my $section = $model->name();
    $self->_log($module, $section, $event, $id, $value, $oldvalue, $temporal);
}

sub logAction
{
    my ($self, $module, $section, $action, $arg, $temporal) = @_;

    return unless $self->isEnabled();

    $self->_log($module, $section, 'action', $action, $arg, undef, $temporal);
}

sub _log
{
    my ($self, $module, $section, $event, $id, $value, $oldvalue, $temporal) = @_;
    $temporal = 1 unless defined $temporal;
    if ((defined $value) and (defined $oldvalue)) {
        if ($value eq $oldvalue) {
            # do not log changes to the same
            return;
        }
    }

    my %data = (
        timestamp => $self->_timestamp(),
        username => $self->_username(),
        module => $module,
        event => $event,
        model => $section,
        id => $id,
        value => $value,
        oldvalue => $oldvalue,
        temporal => $temporal,
    );

    $self->_db()->unbufferedInsert(TABLE_ACTIONS, \%data);
}

sub logSessionEvent
{
    my ($self, $username, $ip, $event) = @_;

    return unless $self->isEnabled();

    my %data = (
        timestamp => $self->_timestamp(),
        username => $username,
        ip => $ip,
        event => $event,
    );

    if ($event == 'login') {
        $self->{username} = $username;
    }

    if ($event == 'logout' or $event == 'expired') {
        delete $self->{username};
    }

    $self->_db()->unbufferedInsert(TABLE_SESSIONS, \%data);
}

sub logShutdown
{
    my ($self, $type) = @_;
    $self->logAction('System', 'General', 'shutdown' ,$type);
    # disable audit to avoid trying to log when resources are shutted down
    $self->{dontLog} = 1;
}

1;
