# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::Events;

# Class: EBox::Events
#
#      Events module to manage the event architecture. You can
#      activate or deactivate event watchers and select which
#      dispatchers to select in order to send the event around.  This
#      module is currently integrated within the eBox main package
#      since it may be considered as a base module as logs. It manages
#      the EventDaemon.

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::LogObserver
            );

use strict;
use warnings;

use EBox::Common::Model::EnableForm;
use EBox::Config;
use EBox::Event;
use EBox::Events::Model::ConfigurationComposite;
use EBox::Events::Model::GeneralComposite;
use EBox::Events::Model::ConfigureEventDataTable;
use EBox::Events::Model::ConfigureDispatcherDataTable;
use EBox::Events::Model::Report::EventsDetails;
use EBox::Events::Model::Report::EventsGraph;
use EBox::Events::Model::Report::EventsReportOptions;
use EBox::Events::Composite::Report::EventsReport;

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;

use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Service;

# Core modules
use Data::Dumper;
use Error qw(:try);

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
use constant EVENTS_FIFO             => EBox::Config::tmp() . 'events-fifo';

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

    my $self = $class->SUPER::_create( name => 'events',
            domain => 'ebox',
            printableName => __n('Events'),
            @_
            );

    bless ($self, $class);

    return $self;
}


sub _daemons
{
    return [ { 'name' => SERVICE } ];
}

# Method: _setConf
#
#   Regenerate the configuration for the events
#
# Overrides:
#
#       <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    # Do the movements to make EventDaemon notice to work
    unless ($self->isReadOnly()) {
        $self->_submitEventElements();
    }
}

sub _enforceServiceState
{
    my ($self) = @_;

    # Check for admin dumbness, it can throw an exception
    if ($self->_adminDumbness()) {
        $self->_stopService();
        return;
    }
    $self->SUPER::_enforceServiceState();
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

    my $item = new EBox::Menu::Item(name  => 'Events',
            text  => $self->printableName(),
            url   => 'Events/Composite/GeneralComposite',
            separator => 'Core',
            order => 90);

    $root->add($item);
}

# Method: models
#
#       Return the models used by events eBox module
#
# Overrides:
#
#       <EBox::Model::ModelProvider::models>
#
sub models
{
    my ($self) = @_;

    my @models = (
            $self->configureEventModel(),
            $self->configureDispatcherModel(),
            $self->_enableForm(),

            $self->reportDetailsModel(),
            $self->reportGraphModel(),
            $self->reportOptionsModel(),
            );

    push ( @models, @{$self->_obtainModelsByPrefix(CONF_DISPATCHER_MODEL_PREFIX)});
    push ( @models, @{$self->_obtainModelsByPrefix(CONF_WATCHER_MODEL_PREFIX)});

    return \@models;
}

# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
         'action' => __('Initialize event dispatchers table'),
         'reason' => __('Enable default log dispatcher'),
         'module' => 'events'
        }
    ];
}


# Method: restoreDependencies
#
#   Override EBox::Module::Base::restoreDependencies
#
sub restoreDependencies
{
    my @depends = ();

    if ( EBox::Global->modExists('mail') )  {
        push(@depends, 'mail');
    }

    return \@depends;
}


# Method: enableActions
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    # Workaround to call syncRows and enable the log
    # dispatcher under /var/lib/ebox/conf/events
    $self->configureDispatcherModel()->ids();
}

# Method: _exposedMethods
#
# Overrides:
#
#       <EBox::Model::ModelProvider::_exposedMethods>
#
sub _exposedMethods
{
    my %exposedMethods =
      ( enableDispatcher => { action   => 'set',
                              path     => [ 'ConfigureDispatcherDataTable' ],
                              indexes  => [ 'eventDispatcher' ],
                              selector => [ 'enabled' ],
                            },
        isEnabledDispatcher => { action   => 'get',
                                path     => [ 'ConfigureDispatcherDataTable' ],
                                indexes  => [ 'eventDispatcher' ],
                                selector => [ 'enabled' ],
                              },
        enableWatcher    => { action   => 'set',
                              path     => [ 'ConfigureEventDataTable' ],
                              indexes  => [ 'eventWatcher' ],
                              selector => [ 'enabled' ],
                            },
        isEnabledWatcher   => { action   => 'get',
                               path     => [ 'ConfigureEventDataTable' ],
                               indexes  => [ 'eventWatcher' ],
                               selector => [ 'enabled' ],
                             },
      );

    return \%exposedMethods;

}

# Method: composites
#
#       Return the composites used by events eBox module
#
# Overrides:
#
#       <EBox::Model::CompositeProvider::composites>
#
sub composites
{
    my ($self) = @_;

    return [
        $self->_eventsComposite(),
        $self->_configurationComposite(),
        $self->_reportComposite(),
       ];
}

# Method: configureEventModel
#
#       Get the model for the configure events.
#
# Returns:
#
#       <EBox::Events::Model::ConfigureEventDataTable> - the
#       configurated event model
#
sub configureEventModel
{
    my ( $self ) = @_;

    # Check if it is already cached
    unless ( exists $self->{configureEventModel} ) {
        $self->{configureEventModel} =
            new EBox::Events::Model::ConfigureEventDataTable(
                    'gconfmodule' => $self,
                    'directory'   => 'configureEventTable'
                    );
    }

    return $self->{configureEventModel};
}

# Method: configureDispatcherModel
#
#       Get the model for the event dispatcher configuration
#
# Returns:
#
#       <EBox::Events::Model::ConfigureDispatcherDataTable> - the
#       configurated dispatcher model
#
sub configureDispatcherModel
{
    my ( $self ) = @_;

    # Check if it is already cached
    unless ( exists $self->{configureDispatcherModel} ) {
        $self->{configureDispatcherModel} =
            new EBox::Events::Model::ConfigureDispatcherDataTable(
                    gconfmodule => $self,
                    directory   => 'configureDispatcherTable'
                    );
    }

    return $self->{configureDispatcherModel};
}

sub reportDetailsModel
{
    my ( $self ) = @_;

    # Check if it is already cached
    unless ( exists $self->{EventsDetailsModel} ) {
        $self->{EventsDetailsModel} =
            new EBox::Events::Model::Report::EventsDetails(
                                              gconfmodule => $self,
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
            new EBox::Events::Model::Report::EventsGraph(
                                              gconfmodule => $self,
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
            new EBox::Events::Model::Report::EventsReportOptions(
                                              gconfmodule => $self,
                                              directory   => 'EventsReportOptions'
                                             );
    }

    return $self->{EventsOptionModel};
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

# Method: enableEventElement
#
#      Mark as some event element (Watcher/Dispatcher) to be
#      enable/disable when saving changes is done. This method is
#      called from the models embebbed in this module
#
# Parameters:
#
#      eventElementType - String it could be 'watcher' or 'dispatcher'
#      eventElement - String the event element identifier to
#      enable/disable
#      enabled - Boolean indicating if the event
#      element will be enabled/disabled
#
#
sub enableEventElement # ($className, $enabled)
{
    my ($self, $type, $className, $enabled) = @_;

    if ( $enabled ) {
        my @enabled  = @{$self->get_list($type . '_to_enable')};
        unless ( grep { $_ eq $className } @enabled ) {
            my @disabled = @{$self->get_list($type . '_to_disable')};
            my $disabled = scalar(@disabled);
            @disabled = grep { $_ ne $className } @disabled;
            if ( scalar(@disabled) != $disabled ) {
                $self->set_list($type . '_to_disable', 'string', \@disabled);
                # Delete from the enabled list
                return;
            }

            unless ( grep { $_ eq $className } @enabled ) {
                push ( @enabled, $className);
                $self->set_list($type . '_to_enable', 'string', \@enabled);
            }
        }
    } else {
        my @disabled  = @{$self->get_list($type . '_to_disable')};
        unless ( grep { $_ eq $className } @disabled ) {
            # Disable
            my @enabled = @{$self->get_list($type . '_to_enable')};
            my $enabled = scalar(@enabled);
            @enabled = grep { $_ ne $className } @enabled;
            if ( scalar(@enabled) != $enabled ) {
                $self->set_list($type . '_to_enable', 'string', \@enabled);
                # Delete from enable, nothing has been done yet
                return;
            }

            unless ( grep { $_ eq $className } @disabled ) {
                push ( @disabled, $className);
                $self->set_list($type . '_to_disable', 'string', \@disabled);
            }
        }
    }
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

    my $dumper = new Data::Dumper([$event]);
    # Set no new lines to dump to communicate with FIFO, the end of
    # connection is done using newline character
    $dumper->Indent(0);

    # Send the dumpered event through the FIFO
    open(my $fifo, '+<', EVENTS_FIFO)
      or throw EBox::Exceptions::Internal('Could not open ' . EVENTS_FIFO . " for reading: $!");
    print $fifo $dumper->Dump() . "\n";
    close($fifo);

    return 1;
}

# Group: Private methods

# Check either if at least one watcher and one dispatcher are enabled or the
# logs are enabled
sub _adminDumbness
{
    my ($self) = @_;

    # XXX TODO
    if ($self->_logIsEnabled()) {
        return undef;
    }

    my $eventModel = $self->configureEventModel();
    my $dispatcherModel = $self->configureDispatcherModel();

    my $match = $eventModel->find( enabled => 1);
    unless ( defined ( $match )) {
        EBox::warn('No event watchers have been enabled');
        return 1;
    }

    $match = $dispatcherModel->find( enabled => 1);
    unless ( defined ( $match )) {
        EBox::warn('No event dispatchers have been enabled');
        return 1;
    }

    return undef;
}


# Method: _logIsEnabled
#
# check if log is enabled for the events module
sub _logIsEnabled
{
    my ($self) = @_;

    my $log = EBox::Global->modInstance('logs');
    if (not $log->isEnabled()) {
        return undef;
    }

    my $configureLogTable = $log->model('ConfigureLogTable');
    my $enabledLogs = $configureLogTable->enabledLogs();
    return $enabledLogs->{events};
}


# Enable/disable watchers and dispatchers to restore backup
sub _prepareRestoreBackup
{
    my ($self) = @_;

    my $eventModel = $self->configureEventModel();
    my @enableEvents =  map { $eventModel->row($_)->valueByName('eventWatcher') }
    @{$eventModel->findAllValue (enabled => 1)};
    my @disableEvents =  map { $eventModel->row($_)->valueByName('eventWatcher') }
    @{$eventModel->findAllValue (enabled => 0)};

    my $dispatcherModel = $self->configureDispatcherModel();
    my @enableDispatchers =  map { $dispatcherModel->row($_)->valueByName('eventDispatcher') }
    @{$dispatcherModel->findAllValue (enabled => 1)};
    my @disableDispatchers =  map { $dispatcherModel->row($_)->valueByName('eventDispatcher') }
    @{$dispatcherModel->findAllValue (enabled => 0)};

    $self->set_list('watcher_to_enable', 'string', \@enableEvents);
    $self->set_list('watcher_to_disable', 'string', \@disableEvents);
    $self->set_list('dispatcher_to_enable', 'string', \@enableDispatchers);
    $self->set_list('dispatcher_to_disable', 'string', \@disableDispatchers);
}

# Submit the files to the correct directories
sub _submitEventElements
{
    my ($self) = @_;

    my @enableWatchers = @{$self->get_list('watcher_to_enable')};
    my @disableWatchers = @{$self->get_list('watcher_to_disable')};
    my @enableDispatchers = @{$self->get_list('dispatcher_to_enable')};
    my @disableDispatchers = @{$self->get_list('dispatcher_to_disable')};

    my @dirs = ( ENABLED_WATCHERS_DIR,  ENABLED_DISPATCHERS_DIR );
    my @toMove = ( [
            \@enableWatchers,
            \@disableWatchers,
            ],
            [
            \@enableDispatchers,
            \@disableDispatchers,
            ]
            );

    for ( my $idx = 0; $idx < scalar(@dirs); $idx++) {
        my $dir = $dirs[$idx];
        my $toCopy = 1;
        foreach my $classesRef (@{$toMove[$idx]}) {
            foreach my $element (@{$classesRef}) {
                if ( $toCopy ) {
                    # Transform :: to /
                    $element =~ s/::/\//g;
                    my $filePath = EBox::Config::perlPath() . $element . '.pm';
                    # Get the class final name
                    ($element) = $element =~ m:^.*/(.*)$:g;
                    my $dest = "$dir/$element.pm";
                    next if ( -l $dest );
                    symlink ( $filePath, $dest )
                        or throw EBox::Exceptions::Internal("Cannot copy from $filePath to $dir");
                } else {
                    ($element) = $element =~ m/^.*::(.*)$/;
                    my $filePath = $dir . $element . '.pm';
                    if ( -l $filePath ) {
                        unlink ( $filePath )
                            or throw EBox::Exceptions::Internal("Cannot unlink $filePath");
                    }
                }
            }
            # Now it's time to delete
            $toCopy = 0;
        }
    }

    # Remove the notebook
    $self->unset('watcher_to_enable');
    $self->unset('watcher_to_disable');
    $self->unset('dispatcher_to_enable');
    $self->unset('dispatcher_to_disable');

    # this is to avoid mark the modules as changed by the removal of deleted information
    # XXX TODO: reimplement using ebox state
    my $global = EBox::Global->getInstance();
    $global->modRestarted('events');
}

# Given a prefix it returns the configurationmodels within this
# prefix in the eBox installed perl class directory.
# Return an array ref containing the found models
sub _obtainModelsByPrefix # (prefix)
{
    my ( $self, $prefix ) = @_;

    my @models = ();

    # The search is done by iterating through the directory where
    # the event dispatcher configuration model should be stored as
    # its hierarchy indicates

    my $prefixDir = $prefix;
    $prefixDir =~ s/::/\//g;
    my $dirPath = EBox::Config::perlPath() . $prefixDir;

    opendir ( my $dir, $dirPath );

    while ( defined ( my $file = readdir ( $dir ))) {
        next unless ( -f "$dirPath/$file");
        next unless ( $file =~ m/.*\.pm/ );
        my ($fileName) =  ( $file =~ m/(.*)\.pm/);

        # Now with the prefix
        my $className = $prefix . $fileName;

        # Test loading the class
        eval "use $className";
        if ( $@ ) {
            EBox::warn("Error loading class: $className");
            next;
        }

        # It should be a model
        next unless ( $className->isa('EBox::Model::DataTable'));

        try {
            my $model = $className->new(
                    gconfmodule => $self,
                    directory   => $fileName,
                    );
            push ( @models, $model);
            # If there are submodels, created them as well
            if ( $model->can('subModels') ) {
                push( @models, @{$model->subModels()});
            }
        } catch EBox::Exceptions::Base with {
            # XXX LogFilter is failing continously but we can recover
            #     comment this out to not  write useless info to the log
            # EBox::warn("model $className cannot be instantiated");
        };
    }

    closedir ( $dir );

    return \@models;
}

# Instantiate an enabled form in order to enable/disable the events
# module
sub _enableForm
{
    my ($self) = @_;

    unless ( exists $self->{enableForm}) {
        $self->{enableForm} = new EBox::Common::Model::EnableForm(
                gconfmodule => $self,
                directory   => 'EnableForm',
                domain      => 'ebox',
                enableTitle => __('Event service status'),
                modelDomain => 'Events',
                );
    }

    return $self->{enableForm};
}

# Instantiate the events composite in order to manage events module
sub _eventsComposite
{
    my ($self) = @_;

    unless ( exists $self->{eventsComposite}) {
        $self->{eventsComposite} = new EBox::Events::Model::GeneralComposite();
    }

    return $self->{eventsComposite};
}

# Instantiate the configure composite in order to manage ability of
# event watchers and dispatchers
sub _configurationComposite
{
    my ($self) = @_;

    unless ( exists $self->{confComposite}) {
        $self->{confComposite} = new EBox::Events::Model::ConfigurationComposite();
    }

    return $self->{confComposite};
}

sub _reportComposite
{
    my ($self) = @_;

    unless ( exists $self->{reportComposite}) {
        $self->{reportComposite} = new EBox::Events::Composite::Report::EventsReport( );
      }

    return $self->{reportComposite};
}

# Method:  restoreConfig
#
#   Restore its configuration from the backup file.
#
# Parameters:
#  dir - Directory where are located the backup files
#
sub restoreConfig
{
    my ($self, $dir) = @_;

    # Call super
    $self->SUPER::restoreConfig($dir);

    $self->_prepareRestoreBackup();
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
        lasttimestamp  => __('Date of last event'),
        nrepeated     => __('Repetitions'),
        level     => __('Level'),
        source   => __('Source'),
        message  => __('Message'),
       };

    my @order =qw(firsttimestamp lasttimestamp nrepeated level source message);

    my $levels = {
        info => __('Informative'),
        warn => __('Warning'),
        error => __('Error'),
        fatal => __('Fatal error'),
       };

    return [
             {
            'name' => __('Events'),
            'index' => 'events',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'events',
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
                                                return $row->{nrepeated};
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

    return {  $table => $spec };
}



sub consolidateReportQueries
{
    return [
            {
             'target_table' => 'events_report',
             'query' => {
                         'select' => 'source, level, sum(nRepeated) AS nEvents',
                         'from' => 'events',
                         'group' => 'source,level',
                        },

            },
           ];
}




# Method: report
#
# Overrides:
#   <EBox::Module::Base::report>
#
# Returns:
#
#   hash ref - the events report
#
sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report = {};

    my $db = EBox::DBEngineFactory::DBEngine();


    my $allAlertsRaw  =  $self->runMonthlyQuery($beg, $end, {
        'select' => 'level, SUM(nEvents)',
        'from' => 'events_report',
        'group' => 'level',
                                                                  },
    { 'key' => 'level' }
   );


    $report->{'all_alerts'} = {};

    foreach my $key (%{ $allAlertsRaw }) {
        next if ( ($key eq 'debug') or ($key eq 'info'));
        my $sum = $allAlertsRaw->{$key}->{sum};
        defined $sum or
            next;
        $report->{'all_alerts'}->{$key} = $sum;
    }


    my $alertsBySource = {};
    foreach my $level (qw(warn error fatal)) {
        my $result =  $self->runMonthlyQuery($beg, $end, {
                'select' => 'source, sum(nEvents)',
                'from' => 'events_report',
                'group' => 'source,level',
                'where' => qq{level='$level'}
                                                         },
                { 'key' => 'source' }
                                            );
        foreach my $source (keys %{$result}) {
            if (not exists $alertsBySource->{$source}) {
                $alertsBySource->{$source} = {};
            }
            my $sum = $result->{$source}->{sum};
            defined($sum) or next;
            $alertsBySource->{$source}->{$level} = $sum;
        }
    }

    $report->{alerts_by_source} = $alertsBySource;

    return $report;
}

1;
