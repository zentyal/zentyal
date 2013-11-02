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

package EBox::EventDaemon;

# Class: EBox::EventDaemon
#
# This class is the daemon which is in charge of managing events at
# eBox. It supports an Observer pattern to add dinamically
# Event Watchers. They should inherit from <EBox::Watcher::Base> in
# order to have support for reporting events within eBox
# framework. Every watcher must just watch one event.
#
# In order to dispatch an event, the same Observer pattern is
# used. Dinamically, you can upload a dispatcher to send the event
# wherever the event said.
#
# You may send events (Dumped <EBox::Event> object) to dispatch through a
# named pipe which is pointed by the file name
# "/var/lib/zentyal/tmp/events-fifo'.

###################
# Dependencies
###################

use EBox;
use EBox::Config;
use EBox::Global;
use EBox::DBEngineFactory;
use EBox::Util::Event qw(:constants);

# Core modules
use File::Slurp;
use IO::Handle;
use IO::Select;
use TryCatch::Lite;
use POSIX;
use Time::Local qw(timelocal);
use Data::Dumper;

# Constants:
#
#      WATCHERS_DIR - String directory where the Watchers lie
#      DISPATCHERS_DIR - String directory where the Dispatchers lie
#      SCANNING_INTERVAL - Integer interval between scannings
#
use constant LOG_TABLE => 'events';
use constant SCANNING_INTERVAL => 60;
use constant EVENT_FOLDING_INTERVAL => 30 * 60; # half hour
use constant MAX_MSG_LENGTH => 256;

# Group: Public methods

# Constructor: new
#
#      The constructor for the <EBox::EventDaemon>
#
# Parameters:
#
#      granularity - Integer number of seconds when the process will
#      call the watchers.
#
# Returns:
#
#      <EBox::EventDaemon> - the event daemon
#
sub new
{
    my ($class, $granularity) = @_;

    my $self = {
        granularity => $granularity,
        # Registered events is a hash ref indexed by watcher
        # class name with two fields: deadOut (the number of
        # seconds till next run) and instance (with an
        # instance of the method).
        watchers => {},
        dispatchers => {},
    };
    bless ($self, $class);

    return $self;
}

# Method: run
#
#       Run the event daemon. It never dies
#
sub run
{
    my ($self) = @_;

    $self->_init();

    my $eventPipe;
    my $pid = open($eventPipe, "|-");
    $eventPipe->autoflush(1);
    unless ( defined ( $pid )) {
        die "$$: Cannot create a process error: $!";
    } elsif ( $pid ) {
        # Parent code
        $self->_mainWatcherLoop($eventPipe);
    } else {
        # Child code
        # STDIN will have the read code
        $self->_mainDispatcherLoop();
        exit;
    }
}

# Group: Private methods

# Method: _init
#
#      Initialises the process. Close the first 64 file descriptors
#      apart from standard input/output/error. Become an eBox user.
#      Catch the HUP and TERM signals.
#
sub _init
{
    my ($self) = @_;

    EBox::init();

    EBox::Util::Event::createFIFO();
}

# Method: _mainWatcherLoop
#
#     Where the action is made. The algorithm can be discribed as
#     following:
#
#     It never returns.
#
# Parameters:
#
#     eventPipe - Filehandle to write the events
#
sub _mainWatcherLoop
{
    my ($self, $eventPipe) = @_;

    # Load watchers classes
    $self->_loadModules('watcher');
    while (1) {
        foreach my $registeredEvent (keys %{$self->{watchers}}) {
            my $queueElementRef = $self->{watchers}->{$registeredEvent};
            $queueElementRef->{deadOut} -= $self->{granularity};
            if ( $queueElementRef->{deadOut} <= 0 ) {
                my $eventsRef = undef;
                try {
                    # Run the event
                    $eventsRef = $queueElementRef->{instance}->run();
                } catch {
                    my $exception = shift;
                    EBox::warn("Error executing run from $registeredEvent: $exception");
                    # Deleting from registered events
                    delete ($self->{watchers}->{$registeredEvent});
                }
                # An event has happened
                if ( defined ( $eventsRef )) {
                    foreach my $event (@{$eventsRef}) {
                        # Send the events to the dispatcher
                        $self->_addToDispatch($eventPipe, $event);
                    }
                }
                $queueElementRef->{deadOut} = $queueElementRef->{instance}->period();
            }
        }
        sleep ($self->{granularity});
    }
}

# Method: _mainDispatcherLoop
#
#       Process will be in charge of dispatching the event
#       wherever the event says so and the dispatcher is available
#
#
sub _mainDispatcherLoop
{
    my ($self) = @_;

    # load dbengine if neccessary
    if ($self->_logEnabled()) {
        $self->{dbengine} = EBox::DBEngineFactory::DBEngine();
    }

    # Load dispatcher classes
    $self->_loadModules('dispatcher');
    # Start main loop with a select
    open(my $fifo, '+<', EVENTS_FIFO);
    my $select = new IO::Select();
    $select->add(\*STDIN);
    $select->add($fifo);
    while (1) {
        my @ready = $select->can_read(SCANNING_INTERVAL);
        foreach my $fh (@ready) {
            my $data;
            {
                local $/ = "\0";
                $data = readline($fh);
            }

            my $event;
            my $VAR1;
            eval $data;
            if ($@) {
                EBox::error("Skipping event: Error decoding $data");
                next;
            }
            $event = $VAR1;

            bless ($event, 'EBox::Event');

            # dispatch event to its watchers
            # skip the given data if it is not a valid EBox::Event object
            if (defined($event) and $event->isa('EBox::Event')) {
                $self->_dispatchEventByDispatcher($event);
            }

            # log the event if log is enabled
            try {
                if (exists $self->{dbengine}) {
                    $self->_logEvent($event);
                }
            } catch {
                EBox::warn("Cannot log event, Mysql is stopped");
            }
        }
    }
}

# Group: Private helper functions

# Method: _loadModules
#
#       Load installed watchers or dispatchers.
#
# Parameters:
#
#       type - can be 'watcher' or 'dispatcher'
#
sub _loadModules
{
    my ($self, $type) = @_;

    my $events = EBox::Global->getInstance(1)->modInstance('events');
    my $model = $type eq 'watcher' ? $events->model('ConfigureWatchers') : $events->model('ConfigureDispatchers');

    foreach my $id (@{$model->enabledRows()}) {
        my $row = $model->row($id);
        my $className = $row->valueByName($type);

        eval "use $className";
        if ($@) {
            EBox::error("Error loading $type class: $className $@");
            next;
        }
        my $instance = $className->new();
        if ($type eq 'watcher') {
            $self->{watchers}->{$className} = { instance => $instance, deadOut  => 0 };
        } else {
            $self->{dispatchers}->{$className} = $instance;
        }
    }
}

# Method: _dispatchEventByDispatcher
#
#       Dispatch the event wherever the event wants that could be any
#       available
#
# Parameters:
#
#       event - <EBox::Event> the event to dispatch
#
sub _dispatchEventByDispatcher
{
    my ($self, $event) = @_;

    my @requestedDispatchers = ();

    my $reqByEventRef = $event->dispatchTo();

    if ( grep { 'any' } @{$reqByEventRef} ) {
        @requestedDispatchers = values ( %{$self->{dispatchers}} );
    } else {
        my @reqByEvent = map { "EBox::Dispatcher::$_" } @{$reqByEventRef};
        foreach my $dispatcherName (keys (%{$self->{dispatchers}})) {
            if ( grep { $dispatcherName } @reqByEvent ) {
                push ( @requestedDispatchers,
                        $self->{dispatchers}->{$dispatcherName});
            }
        }
    }

    # Dispatch the event
    foreach my $dispatcher (@requestedDispatchers) {
        try {
            $dispatcher->enable();
            EBox::info("Send event to $dispatcher");
            $dispatcher->send($event);
        } catch (EBox::Exceptions::External $e) {
            my ($exc) = @_;
            EBox::warn($dispatcher->name() . ' is not enabled to send messages');
            EBox::error($exc->stringify());
        }
    }
}

sub _logEnabled
{
    my ($self) = @_;
    my $logs = EBox::Global->modInstance('logs');
    defined $logs or
        return undef;
    $logs->isEnabled() or
        return undef;

    # check if log for events module is enabled
    my $enabledLogs = $logs->_restoreEnabledLogsModules();
    return $enabledLogs->{events};
}

sub _foldingEventInLog
{
    my ($self, $event) = @_;

    my $dbh = $self->{dbengine}->{dbh};

    if (not exists $self->{selectStmt}) {
         my $selectStmt = $dbh->prepare(
         'SELECT id, lastTimestamp FROM '. LOG_TABLE . ' '
          . 'WHERE level = ? '
          . 'AND source = ? '
          . 'AND message = ? '
          . 'ORDER BY lastTimestamp DESC '
          . 'LIMIT 1'
                                       );

        $self->{selectStmt} = $selectStmt;
    }

    $self->{selectStmt}->execute(
        $event->level(),
        $event->source(),
        $event->message()
       );

    my $storedEvent = $self->{selectStmt}->fetchrow_hashref();
    if (not defined $storedEvent) {
        # not matching event found ...
        return undef;
    }

    my ($year, $mon, $mday, $hour, $min, $sec) = split /[\s\-:]/, $storedEvent->{lastTimestamp};
    $year -= 1900;
    $mon -= 1;
    my $storedTimestamp = timelocal($sec,$min,$hour,$mday,$mon,$year);

    if (($storedTimestamp + EVENT_FOLDING_INTERVAL) >  $event->timestamp()) {
        # Last event of the same type happened before last
        # half an hour
        my $id = $storedEvent->{id};
        return $id;
    }

    return undef;
}

sub _updateFoldingEventInLog
{
    my ($self, $id, $event) = @_;

    my $ts = $event->timestamp();
    my @tsParts = localtime($ts);
    $tsParts[5] += 1900;
    $tsParts[4] += 1;
    my $lastTimestamp = join('-', @tsParts[5,4,3]) . ' ' .
                        join(':', @tsParts[2,1,0]);

    my $dbh = $self->{dbengine}->{dbh};

    if (not exists $self->{updateStmt}) {
        my $updateStmt = $dbh->prepare(
            'UPDATE ' . LOG_TABLE . ' '
            . 'SET nRepeated = nRepeated + 1, lastTimestamp = ? '
            . 'WHERE id = ?'
           )  or die $dbh->errstr;;
        $self->{updateStmt} = $updateStmt;
    }

    $self->{updateStmt}->execute($lastTimestamp, $id);
}

sub _insertEventInLog
{
    my ($self, $event) = @_;

    # We don't use names on the date to avoid issues
    # with DB insertions and localization
    my $timeStmp = strftime("%F %H:%M:%S %z",
                    localtime($event->timestamp()));

    # truncate message if needed
    my $message = $event->message();
    if (length($message) > MAX_MSG_LENGTH) {
        $message = substr ($message, 0, MAX_MSG_LENGTH);
    }

    my $values = {
        timestamp => $timeStmp,
        lastTimestamp  => $timeStmp,

        level    => $event->level(),
        source   => $event->source(),
        message  => $message,
    };

    $self->{dbengine}->unbufferedInsert(LOG_TABLE, $values);
}

# Method: _logEvent
#
#  Add the event to the events log
#
# Parameters:
#
#       event - <EBox::Event> the event to dispatch
#
sub _logEvent
{
    my ($self, $event) = @_;

    my $foldingEventId = $self->_foldingEventInLog($event);
    if ($foldingEventId) {
        $self->_updateFoldingEventInLog($foldingEventId, $event);
    } else {
        $self->_insertEventInLog($event);
    }
}

# Method: _addToDispatch
#
#       Send to the Dispatcher daemon the given event through the
#       given pipe
#
# Parameters:
#
#       eventPipe - Filehandle pipe to send events from the watcher
#       daemon to the dispatcher daemon
#       event - <EBox::Event> the event to dispatch
#
sub _addToDispatch
{
    my ($self, $eventPipe, $event) = @_;

    my $dumper = new Data::Dumper([$event]);
    # Set no new lines to dump to communicate with FIFO, the end of
    # connection is done using newline character
    $dumper->Indent(0);

    # Sending the dumpered event with a null char
    print $eventPipe ( $dumper->Dump() . "\0" );
}

###############
# Main program
###############

# Granularity: 10 second
my $eventd = new EBox::EventDaemon(10);

$eventd->run();
