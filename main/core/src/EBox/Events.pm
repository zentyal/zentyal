# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::Events
#
#      Events module to manage the event architecture. You can
#      activate or deactivate event watchers and select which
#      dispatchers to select in order to send the event around.  This
#      module is currently integrated within the eBox main package
#      since it may be considered as a base module as logs. It manages
#      the EventDaemon.
package EBox::Events;

use base qw(EBox::Module::Service EBox::LogObserver
            EBox::Events::WatcherProvider EBox::Events::DispatcherProvider);

use EBox::DBEngineFactory;
use EBox::Config;
use EBox::Event;
use EBox::Events::Model::EventsDetails;
use EBox::Events::Model::EventsGraph;
use EBox::Events::Model::EventsReportOptions;
use EBox::Events::Composite::EventsReport;

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;

use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Service;
use EBox::Util::Event qw(:constants);

# Core modules
use Data::Dumper;
#use File::Temp qw(tempfile);
use TryCatch::Lite;

# Constants:
#
#         SERVICE - the service managed by this module
#
use constant SERVICE                 => 'ebox.event-daemon';
use constant CONF_DIR                => EBox::Config::conf() . 'events/';
use constant ENABLED_DISPATCHERS_DIR => CONF_DIR . 'DispatcherEnabled/';
use constant ENABLED_WATCHERS_DIR    => CONF_DIR . 'WatcherEnabled/';
use constant CONF_DISPATCHER_MODEL_PREFIX => 'EBox::Events::Model::Dispatcher::';
use constant CONF_WATCHER_MODEL_PREFIX => 'EBox::Events::Model::Watcher::';

# Group: Protected methods

# Constructor: _create
#
#        Create an event module
#
# Overrides:
#
#        <EBox::Module::Service::_create>
#
# Returns:
#
#        <EBox::Events> - the recently created module
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'events',
                                      printableName => __('Events'),
                                      @_);

    bless ($self, $class);

    return $self;
}

sub _daemons
{
    return [
        {
            'name' => SERVICE,
            'precondition' => \&_watchersEnabled,
        }
    ];
}

sub _preSetConf
{
    my ($self) = @_;

    # This is needed because EventDaemon instances global as readonly
    # so syncRows is never called there, this avoids the need of the
    # user having to visit the models on the Zentyal interface, so
    # the events module can work out of the box with the default
    # configuration (log dispatcher enabled and also events log
    # if logs module is enabled)
    unless ($self->isReadOnly()) {
        $self->model('ConfigureWatchers')->ids();
        $self->model('ConfigureDispatchers')->ids();
        $self->saveConfig();
    }
}

# Group: Public methods

# Method: menu
#
#        Show the events menu entry
#
# Overrides:
#
#        <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Maintenance',
                                        'icon' => 'maintenance',
                                        'text' => __('Maintenance'),
                                        'separator' => 'Core',
                                        'order' => 70);

    my $item = new EBox::Menu::Item(
                    name => 'Events',
                    text => $self->printableName(),
                    url  => 'Maintenance/Events',
                    order => 30,
    );
    $folder->add($item);

    $root->add($folder);
}

# Method: depends
#
#       Override EBox::Module::Base::depends
#
sub depends
{
    my $modules = EBox::Global->modInstances();
    my @names;
    foreach my $mod (@{ $modules }) {
        my $name = $mod->name();
        if ($name eq 'events') {
            next;
        } elsif ($name eq 'monitor') {
            # monitor is a exception it has to depend on events
            next;
        } elsif ($name eq 'cloud-prof') {
            next;
        } elsif ($mod->isa('EBox::Events::WatcherProvider') or $mod->isa('EBox::Events::DispatcherProvider')) {
            push @names, $name;
        }
    }
    return \@names;
}

# Method: eventWatchers
#
# Overrides:
#
#      <EBox::Events::WatcherProvider::eventWatchers>
#
sub eventWatchers
{
    return [ 'Log', 'DiskFreeSpace', 'RAID', 'Runit', 'Updates', 'State' ];
}

# Method: eventDispatchers
#
# Overrides:
#
#      <EBox::Events::DispatcherProvider::eventDispatchers>
#
sub eventDispatchers
{
    return [ 'Log' ];
}

sub reportDetailsModel
{
    my ( $self ) = @_;

    # Check if it is already cached
    unless (exists $self->{EventsDetailsModel}) {
        $self->{EventsDetailsModel} =
            new EBox::Events::Model::EventsDetails(
                                              confmodule => $self,
                                              directory   => 'EventsDetails'
                                             );
    }

    return $self->{EventsDetailsModel};
}

sub reportGraphModel
{
    my ( $self ) = @_;

    # Check if it is already cached
    unless ( exists $self->{EventsGraphModel} ) {
        $self->{EventsGraphModel} =
            new EBox::Events::Model::EventsGraph(
                                              confmodule => $self,
                                              directory   => 'EventsGraph'
                                             );
    }

    return $self->{EventsGraphModel};
}

sub reportOptionsModel
{
    my ( $self ) = @_;

    # Check if it is already cached
    unless ( exists $self->{EventsOptionModel} ) {
        $self->{EventsOptionModel} =
            new EBox::Events::Model::EventsReportOptions(
                                              confmodule => $self,
                                              directory   => 'EventsReportOptions'
                                             );
    }

    return $self->{EventsOptionModel};
}

# Method: models
#
#      Override to load in manager the dynamic models for Log Watcher
#      Filtering
#
# Overrides:
#
#      <EBox::Module::Config::models>
#
sub models
{
    my ($self) = @_;

    my $logWatcherConfModel = $self->model('LogWatcherConfiguration');
    $logWatcherConfModel->setUpModels(); # This loads the log watcher models
    return $self->SUPER::models();
}

# Method: isRunning
#
# Overrides:
#
#      <EBox::Module::Service::isRunning>
#
sub isRunning
{
    my ($self) = @_;
    return $self->isEnabled();
}

sub enableDispatcher
{
    my ($self, $dispatcher, $enabled) = @_;
    $self->model('ConfigureDispatchers')->enableDispatcher($dispatcher, $enabled);
}

sub isEnabledDispatcher
{
    my ($self, $dispatcher) = @_;
    $self->model('ConfigureDispatchers')->isEnabledDispatcher($dispatcher);
}

sub enableWatcher
{
    my ($self, $watcher, $enabled) = @_;
    $self->model('ConfigureWatchers')->enableWatcher($watcher, $enabled);
}

sub isEnabledWatcher
{
    my ($self, $watcher) = @_;
    $self->model('ConfigureWatchers')->isEnabledWatcher($watcher);
}

# Method: sendEvent
#
#       Send an event to the event daemon to be dispatched to enabled
#       dispatchers.
#
#       It could send to content of an event or <EBox::Event> object
#       itself to be sent.
#
# Parameters:
#
#      message - String the i18ned message which will be dispatched
#
#      source - String the event watcher/subwatcher name to
#               categorise afterwards the event depending on the
#               source
#
#      level  - Enumerate the level of the event *(Optional)*
#               Possible values: 'info', 'warn', 'error' or 'fatal'.
#               Default: 'info'
#
#      timestamp - Int the number of seconds since the epoch (1 Jan 1970)
#                  *(Optional)* Default value: now
#
#      dispatchTo - array ref containing the relative name for the
#      dispatchers you want to dispatch this event *(Optional)*
#      Default value: *any*, which means any available dispatcher will
#      dispatch the event. Concrete example: ControlCenter
#
#      - Named parameters
#
#      event - <EBox::Event> the event to send. If this parameter is
#              set, then the previous parameters will be ignored. *(Optional)*
#
# Returns:
#
#      Boolean - indicating if the sending was successful or not
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if there is no
#      message and source or no event.
#
#      <EBox::Exceptions::External> - thrown if we try to send events
#      giving the fact the events module is disabled
#
#      <EBox::Exceptions::Internal> - thrown if we cannot send the
#      event through the fifo
#
sub sendEvent
{
    my ($self, %args) = @_;

    unless ( $self->isEnabled() ) {
        throw EBox::Exceptions::External(
            __('The events module is not enabled to send events')
           );
    }

    my $event;
    if ( defined($args{event}) and $args{event}->isa('EBox::Event') ) {
        $event = $args{event};
    } elsif ( defined($args{message}) and defined($args{source}) ) {
        $event = new EBox::Event(%args);
    } else {
        throw EBox::Exceptions::MissingArgument('message') if not defined($args{message});
        throw EBox::Exceptions::MissingArgument('source') if not defined($args{source});
    }

    # Remove NULL characters
    $event->{message} =~ tr/\0//d;

    my $dumper = new Data::Dumper([$event]);
    # Set no new lines to dump to communicate with FIFO, the end of
    # connection is done using newline character
    $dumper->Indent(0);

    # Send the dumpered event through the FIFO
    open(my $fifo, '+<', EVENTS_FIFO)
      or throw EBox::Exceptions::Internal('Could not open ' . EVENTS_FIFO . " for reading: $!");
    print $fifo $dumper->Dump() . "\0";
    close($fifo);

    return 1;
}

# Group: Private methods

# Check either if there are enabled watchers
sub _watchersEnabled
{
    my ($self) = @_;

    if ($self->_logIsEnabled()) {
        return 1;
    }

    my $match = $self->model('ConfigureWatchers')->find(enabled => 1);
    if (defined ($match)) {
        return 1;
    } else {
        EBox::warn('No event watchers have been enabled');
    }

    return 0;
}

# Method: _logIsEnabled
#
# check if log is enabled for the events module
sub _logIsEnabled
{
    my ($self) = @_;

    my $log = EBox::Global->modInstance('logs');
    unless ($log->isEnabled()) {
        return undef;
    }

    my $configureLogTable = $log->model('ConfigureLogs');
    my $enabledLogs = $configureLogTable->enabledLogs();
    return $enabledLogs->{events};
}

sub enableLog
{
    my ($self, $status) = @_;
    $self->setAsChanged();
}

sub tableInfo
{
    my ($self) = @_;
    my $titles =  {
        timestamp => __('Date of first event'),
        lastTimestamp  => __('Date of last event'),
        nRepeated     => __('Repetitions'),
        level     => __('Level'),
        source   => __('Source'),
        message  => __('Message'),
       };

    my @order =qw(timestamp lastTimestamp nRepeated level source message);

    my $levels = {
        info => __('Informative'),
        warn => __('Warning'),
        error => __('Error'),
        fatal => __('Fatal error'),
       };

    return [
             {
            'name' => $self->printableName(),
            'tablename' => 'events',
            'titles' => $titles,
            'order' => \@order,
            'filter' => [ 'source', 'message'],
            'events' => $levels,
            'eventcol' => 'level',
            'consolidate' => $self->_consolidateTable(),
           }
       ];
}

sub _consolidateTable
{
    my $table = 'events_accummulated';
    my $spec=  {
            consolidateColumns => {
                                level => {
                                        accummulate => sub {
                                                # accummulate in correct
                                                # level column
                                                my ($type) = @_;
                                                return $type;
                                            },
                                        conversor => sub {
                                                my ($v, $row) = @_;
                                                return $row->{nRepeated};
                                            },
                                        },
                                source => { destination => 'source' },
                            },
            accummulateColumns => {
                                info  => 0,
                                warn  => 0,
                                error => 0,
                                fatal => 0,
                            },
    };

    return { $table => $spec };
}

# Method: lastEventsReport
#
#     Get the report of current month events report
#
# Returns:
#
#     Hash ref - containing the following keys
#
#         total - the sum of all alerts
#         info  - the sum of info alerts
#         warn  - the sum of warn alerts
#         error  - the sum of error alerts
#         fatal  - the sum of fatal alerts
#
sub lastEventsReport
{
    my ($self) = @_;

    my $db = EBox::DBEngineFactory::DBEngine();

    my $allAlerts = $db->query_hash(
        {
            select => 'level, SUM(nRepeated) AS nEvents',
            from   => 'events',
            where  => 'timestamp >= DATE_SUB(NOW(), INTERVAL 1 MONTH)',
            group  => 'level',
        });

    my %result = (info => 0, warn => 0, error => 0, fatal => 0);

    my $total = 0;
    foreach my $row (@{$allAlerts}) {
        if ( exists($result{$row->{level}}) ) {
            $result{$row->{level}} = $row->{nEvents};
            $total += $row->{nEvents};
        }
    }
    $result{total} = $total;

    return \%result;
}

1;
