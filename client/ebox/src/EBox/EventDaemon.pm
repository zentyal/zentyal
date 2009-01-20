# Copyright (C) 2007 Warp Networks S.L.
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
# "/var/lib/ebox/tmp/events-fifo'.


use strict;
use warnings;

###################
# Dependencies
###################
use Data::Dumper;

# eBox uses
use EBox::Config;

# Core modules
use File::stat;
use File::Slurp;
use IO::Handle;
use IO::Select;
use Error qw(:try);
use POSIX;
use UNIVERSAL;

# Constants:
#
#      WATCHERS_DIR - String directory where the Watchers lie
#      DISPATCHERS_DIR - String directory where the Dispatchers lie
#      EVENTS_FIFO - String the path to the named pipe to send events to
#      dispatch
#      SCANNING_INTERVAL - Integer interval between scannings
#
use constant WATCHERS_DIR      => EBox::Config::conf() . 'events/WatcherEnabled/';
use constant DISPATCHERS_DIR   => EBox::Config::conf() . 'events/DispatcherEnabled/';
use constant EVENTS_FIFO       => EBox::Config::tmp() . 'events-fifo';
use constant SCANNING_INTERVAL => 60;

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
                  registeredEvents => {},
                  registeredDispatchers => {},
                  lastWatcherScan => time(),
                  lastDispatcherScan => time(),
                 };
      bless ( $self, $class);

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

      # Create the named pipe
      unless ( -p EVENTS_FIFO ) {
          unlink(EVENTS_FIFO);
          POSIX::mkfifo(EVENTS_FIFO, 0700)
              or die "Can't make a named pipe: $!";
      }

#      foreach my $fd (0 .. 64) { POSIX::close($fd); }
#
#      open(STDIN,  "+</tmp/stdin");
#      open(STDOUT, "+>/tmp/stdout");
#      open(STDERR, "+>/tmp/stderr");

#      $SIG{'HUP'} = \&_reReadDirs($self);
#      $SIG{'TERM'} = $SIG{'HUP'};

  }

# Method: _reReadDirs
#
#     Re-read the directories where the watchers/dispatchers in order
#     to suppor dynamic add/removal
#
sub _reReadDirs
  {

      my ($self) = @_;

      $self->_loadModules('Watcher');
      $self->_loadModules('Dispatcher');
      EBox::debug('Re-read: ' . Dumper($self));

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
      $self->_loadModules('Watcher');
      while ('true') {
          if ( time() - $self->{lastWatcherScan} > SCANNING_INTERVAL) {
              $self->_loadModules('Watcher');
          }
          foreach my $registeredEvent (keys %{$self->{registeredEvents}}) {
              my $queueElementRef = $self->{registeredEvents}->{$registeredEvent};
              $queueElementRef->{deadOut} -= $self->{granularity};
              if ( $queueElementRef->{deadOut} <= 0 ) {
                  my $eventsRef = undef;
                  try {
                      # Run the event
                      $eventsRef = $queueElementRef->{instance}->run();
                  } otherwise {
                      my $exception = shift;
                      EBox::warn("Error executing run from $registeredEvent: $exception");
                      # Deleting from registered events
                      delete ($self->{registeredEvents}->{$registeredEvent});
                  };
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

    # Load dispatcher classes
    $self->_loadModules('Dispatcher');
    # Start main loop with a select
    open(my $fifo, '+<', EVENTS_FIFO);
    my $select = new IO::Select();
    $select->add(\*STDIN);
    $select->add($fifo);
    while (1) {
        my @ready = $select->can_read(SCANNING_INTERVAL);
        foreach my $fh (@ready) {
            my $data = readline($fh);
            my $event;
            {
                no strict 'vars'; $event = eval $data;
            }
            $self->_dispatchEventByDispatcher($event);
        }
        if ( time() - $self->{lastDispatcherScan} > SCANNING_INTERVAL ) {
            $self->_loadModules('Dispatcher');
        }
    }
}

# Group: Private helper functions

# Method: _loadModules
#
#       Load dinamically the modules which lays on a directory given a
#       prefix. This could be: 'Watcher' or 'Dispatcher'.
#
# Parameters:
#
#       prefix - String the prefix could 'Watcher' or 'Dispatcher'
#
sub _loadModules
  {

      my ($self, $prefix) = @_;

      my ($prefixPath, $registeredField);
      if ( $prefix eq 'Watcher' ) {
          $prefixPath = WATCHERS_DIR;
          $registeredField = 'registeredEvents';
      } elsif ( $prefix eq 'Dispatcher' ) {
          $prefixPath = DISPATCHERS_DIR;
          $registeredField = 'registeredDispatchers';
      } else {
          return undef;
      }

      opendir ( my $dir, $prefixPath );

      while ( defined ( my $file = readdir ( $dir ))) {
#          next unless (-e "$prefixPath/$file");
          unless ( -e "$prefixPath/$file" ) {
              if ( -l "$prefixPath/$file" ) {
                  EBox::info("Unlinking broken link $prefixPath/$file");
                  unlink ( "$prefixPath/$file" )
                    or throw EBox::Exceptions::Internal("Cannot unlink $prefixPath/$file");
              }
              next;
          }
          next unless ( $file =~ m/.*\.pm/g );
          my ($className) = ($file =~ m/(.*)\.pm/);
          $className = 'EBox::Event::' . $prefix . '::' . $className;
          my $instance;
          # The class may not be included
          if (not defined ( $self->{$registeredField}->{$className})) {
#              eval "use $className";
              eval qq{require "$prefixPath/$file"};
              if ( $@ ) {
                  EBox::warn("Error loading class: $className $@");
                  next;
              }
              EBox::info("$className loaded from $registeredField");
              if ( $prefix eq 'Watcher') {
                  if ( $className->isa('EBox::Event::Watcher::Base') and
                      (not ($className eq 'EBox::Event::Watcher::Base')) ) {
                      $instance = $className->new();
                      $self->{$registeredField}->{$className} = {
                                                                 instance => $instance,
                                                                 deadOut  => 0,
                                                                };
                  } else {
                      EBox::info("Class $className not derived from EBox::Event::Watcher::Base");
                  }
              } else {
                  if ( $className->isa('EBox::Event::Dispatcher::Abstract') and
                       (not ($className eq 'EBox::Event::Dispatcher::Abstract')) ) {
                      $instance = $className->new();
                      $self->{$registeredField}->{$className} = $instance;
                  } else {
                      EBox::info("Class $className not derived from EBox::Event::Dispatcher::Abstract");
                  }
              }
          } else {
              # Check its last modification time in order to reload
              # the module
              my $statFile = stat ("$prefixPath/$file");
              my $lastScan;
              if (  $prefix eq 'Watcher' ) {
                  $lastScan = $self->{lastWatcherScan};
              } else {
                  $lastScan = $self->{lastDispatcherScan};
              }
              if ( $statFile->mtime() > $lastScan ) {
                  EBox::info("$className reloaded from $registeredField");
                  $self->_deleteFromINC($className);
#                  eval "use $className";
                  eval qq{require "$prefixPath/$file";};
                  if ( $@ ) {
                      EBox::warn("Error loading class: $className");
                      next;
                  }
                  $instance = $className->new();
                  if ( $prefix eq 'Watcher' ) {
                      my $registeredEvent = $self->{$registeredField}->{$className};
                      $registeredEvent->{instance} = $instance;
                      # If the period has plummered to be lower than
                      # current dead out, set the new period
                      if ( $registeredEvent->{deadOut} > $registeredEvent->{instance}->period() ) {
                          $registeredEvent->{deadOut} = $registeredEvent->{instance}->period();
                      }
                  } elsif ( $prefix eq 'Dispatcher') {
                      $self->{$registeredField}->{$className} = $instance;
                  }
              }
          }
      }
      closedir ($dir);

      # Check for deletion
      foreach my $className ( keys (%{$self->{$registeredField}}) ){
          my ($fileName) = $className =~ m/.*::(.*)$/g;
          $fileName .= '.pm';
          unless ( -e "$prefixPath/$fileName" ) {
              EBox::info("$className deleted from $registeredField");
              $self->_deleteFromINC($className);
              if ( -l "$prefixPath/$fileName" ) {
                  # Delete broken links
                  EBox::info("Unlinking broken link $prefixPath/$fileName");
                  unlink( "$prefixPath/$fileName" )
                    or throw EBox::Exceptions::Internal("Cannot unlink $prefixPath/$fileName");
              }
          }

#          unless ( -f ( readlink ( "$prefixPath/$fileName" ))) {
#              EBox::info("$className deleted from $registeredField since the link is broken");
#              $self->_deleteFromINC($className);
#              # Remove broken links
#          }
      }

      # Updating timestamp
      if ( $prefix eq 'Watcher') {
          $self->{lastWatcherScan} = time();
      } else {
          $self->{lastDispatcherScan} = time();
      }


  }

# Method: _deleteFromINC
#
#     Delete a class from the loaded modules
#
# Parameters:
#
#     className - String the class name in :: format
#
sub _deleteFromINC
  {

      my ($self, $className) = @_;

      my $pathName = $className;
      $pathName =~ s/::/\//g;
      delete $INC{$pathName};

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
          @requestedDispatchers = values ( %{$self->{registeredDispatchers}} );
      } else {
          my @reqByEvent = map { "EBox::Dispatcher::$_" } @{$reqByEventRef};
          foreach my $dispatcherName (keys (%{$self->{registeredDispatchers}})) {
              if ( grep { $dispatcherName } @reqByEvent ) {
                  push ( @requestedDispatchers,
                         $self->{registeredDispatchers}->{$dispatcherName});
              }
          }
      }

      # Dispatch the event
      foreach my $dispatcher (@requestedDispatchers) {
          try {
              $dispatcher->enable();
              $dispatcher->send($event);
          } catch EBox::Exceptions::External with {
              my ($exc) = @_;
              EBox::warn($dispatcher->name() . ' is not enabled to send messages');
              EBox::error($exc->stringify());
              # TODO: Disable dispatcher since it's not enabled to
              # send events
              eval { require 'EBox::Global'};
              my $events = EBox::Global->modInstance('events');
              # Disable the model
              $events->enableDispatcher( ref ( $dispatcher ), 0);
              $events->configureDispatcherModel()->setMessage(
                         __x('Dispatcher {name} disabled since it is not able to '
                             . 'send events', name => $dispatcher->name()));
          };
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

      my $eventStr = Dumper($event);

      # Deleting the newline characters
      $eventStr =~ s/\n//g;

      # Sending the dumpered event with a newline char
      print $eventPipe ( $eventStr . $/ );

  }


###############
# Main program
###############

# Granularity: 10 second
my $eventd = new EBox::EventDaemon(10);

$eventd->run();


