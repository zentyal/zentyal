# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

    my $self = $class->SUPER::_create(name => 'events',
                                      printableName => __('Events'),
                                      @_);

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

    $self->_enableComponents();

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

    my $folder = new EBox::Menu::Folder('name' => 'Maintenance',
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
    # dispatcher under /var/lib/zentyal/conf/events
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


# Create the symlinks to enable/disable watchers and dispatchers
sub _enableComponents
{
    my ($self) = @_;

    my @dirs = ( ENABLED_WATCHERS_DIR, ENABLED_DISPATCHERS_DIR );

    # Firstly, remove everything
    foreach my $dir (@dirs) {
        opendir(my $dh, $dir);
        while( my $file  = readdir($dh) ) {
            next unless ( -l "${dir}/$file" );
            unlink( "$dir/$file" );
        }
    }

    my $ids = $self->configureEventModel()->enabledRows();
    my $watchers = [];
    foreach my $id ( @{$ids} ) {
        push(@{$watchers}, $self->configureEventModel()->row($id)->valueByName('eventWatcher'));
    }
    my $dispatchers = [];
    foreach my $id ( @{$self->configureDispatcherModel()->enabledRows()} ) {
        push(@{$dispatchers}, $self->configureDispatcherModel()->row($id)->valueByName('eventDispatcher'));
    }

    my %enabledComponents = ($dirs[0] => $watchers,
                             $dirs[1] => $dispatchers);

    while ( my ($dir, $comps) = each(%enabledComponents) ) {
        foreach my $comp (@{$comps}) {
            # Transform :: to /
            $comp =~ s/::/\//g;
            my $filePath = EBox::Config::perlPath() . $comp . '.pm';
            # Get the class final name
            ($comp) = $comp =~ m:^.*/(.*)$:g;
            my $dest = "$dir$comp.pm";
            next if ( -l $dest );
            symlink ( $filePath, $dest )
              or throw EBox::Exceptions::Internal("Cannot copy from $filePath to $dir");
        }
    }

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

sub _reportComposite
{
    my ($self) = @_;

    unless ( exists $self->{reportComposite}) {
        $self->{reportComposite} = new EBox::Events::Composite::Report::EventsReport( );
      }

    return $self->{reportComposite};
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
            'name' => $self->printableName(),
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
             'quote' => { source => 1 },
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

    my @time = localtime();
    my $beg  = sprintf("%d-%d", $time[5]+1900, $time[4]+1);

    my $allAlerts = $self->runMonthlyQuery($beg, $beg, {
        'select' => 'level, SUM(nEvents)',
        'from'   => 'events_report',
        'group'  => 'level',
    }, { 'key' => 'level' });

    my %result = (info => 0, warn => 0, error => 0, fatal => 0);

    my $total = 0;
    foreach my $key (qw(info warn error fatal)) {
        if (exists $allAlerts->{$key} ) {
            $result{$key} = $allAlerts->{$key}->{sum}->[0];
            $total += $result{$key};
        }
    }
    $result{total} = $total;

    return \%result;
}

1;
