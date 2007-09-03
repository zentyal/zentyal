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

package EBox::Events;

# Class: EBox::Events
#
#      Events module to manage the event architecture. You can
#      activate or deactivate event watchers and select which
#      dispatchers to select in order to send the event around.  This
#      module is currently integrated within the eBox main package
#      since it may be considered as a base module as logs. It manages
#      the EventDaemon.

use base qw(EBox::GConfModule EBox::Model::ModelProvider);

use strict;
use warnings;

# eBox uses
use EBox::Config;
use EBox::Events::Model::ConfigureEventDataTable;
use EBox::Events::Model::ConfigureDispatcherDataTable;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Folder;
use EBox::Menu::Item;
use EBox::Service;
use EBox::Summary::Status;

################
# Core modules
################
use File::Copy qw(copy);


# Constants:
#
#         SERVICE - the service managed by this module
#
use constant SERVICE => 'event-daemon';
use constant CONF_DIR                => EBox::Config::conf() . 'events/';
use constant ENABLED_DISPATCHERS_DIR => CONF_DIR . 'DispatcherEnabled/';
use constant ENABLED_WATCHERS_DIR => CONF_DIR . 'WatcherEnabled/';
use constant CONF_DISPATCHER_MODEL_PREFIX => 'EBox::Events::Model::Dispatcher::';
use constant CONF_WATCHER_MODEL_PREFIX => 'EBox::Events::Model::Watcher::';

# Group: Public methods

# Constructor: _create
#
#        Create an event module
#
# Overrides:
#
#        <EBox::GConfModule::_create>
#
# Returns:
#
#        <EBox::Events> - the recently created module
#
sub _create
  {

      my $class = shift;

      my $self = $class->SUPER::_create( name => 'events',
                                         domain => 'ebox-events',
                                         @_
                                       );

      bless ($self, $class);

  }

# Method: _regenConfig
#
#        Regenerate the configuration for the events
#
# Overrides:
#
#       <EBox::Module::_regenConfig>
#
# Exceptions:
#
#       <EBox::Exceptions::External> - if no event watcher and event
#       dispatcher are enabled
#
sub _regenConfig
  {

      my ($self) = @_;

      # Check for admin dumbness, it can throw an exception
      $self->_adminDumbness();

      unless ( $self->isReadOnly() ) {
          # Do the movements to make notice EventDaemon work
          $self->_submitEventElements();
      }

      $self->_doDaemon();

  }

# Method: _stopService
#
#        Stop the event service
# Overrides:
#
#       <EBox::Module::_stopService>
#
sub _stopService
  {

      EBox::Service::manage(SERVICE, 'stop');

  }

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
                                      text  => __('Events'),
                                      url   => 'Events/Index',
                                      order => 7);

      $root->add($item);

  }

# Method: statusSummary
#
#       Show the event status summary
#
# Overrides:
#
#       <EBox::Module::statusSummary>
#
sub statusSummary
  {

      my ($self) = @_;

      return new EBox::Summary::Status(
                                       'events',
                                       __('Events'),
                                       $self->running(),
                                       $self->service(),
                                      );

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
                   );

      push ( @models, @{$self->_obtainModelsByPrefix(CONF_DISPATCHER_MODEL_PREFIX)});
      push ( @models, @{$self->_obtainModelsByPrefix(CONF_WATCHER_MODEL_PREFIX)});

      return \@models;

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

# Method: running
#
#      Request to know if the event daemon is running or not
#
# Returns:
#
#      boolean - the event daemon is running or not
#
sub running
  {

      return EBox::Service::running(SERVICE);

  }

# Method: service
#
#      Check whether the Events service is enabled or not
#
# Returns:
#
#      boolean - the service is enabled or not
#
sub service
  {

      my ($self) = @_;

      return $self->get_bool('enabled');

  }

# Method: setService
#
#      Set if the events service is enabled or not
#
# Parameters:
#
#      enabled - boolean service to be enabled or not
#
sub setService
  {

      my ($self, $enabled) = @_;

      return $self->set_bool('enabled', $enabled);

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
              my $disabledWatchers = scalar(@disabled);
              @disabled = grep { $_ ne $className } @disabled;
              if ( scalar(@disabled) != $disabledWatchers ) {
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
              # Disable watcher
              my @enabled = @{$self->get_list($type . '_to_enable')};
              my $enabledWatchers = scalar(@enabled);
              @enabled = grep { $_ ne $className } @enabled;
              if ( scalar(@enabled) != $enabledWatchers ) {
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

# Group: Private methods

sub _doDaemon
  {

      my ($self) = @_;

      if ( $self->running() and $self->service() ) {
          EBox::Service::manage(SERVICE, 'restart');
      } elsif ( $self->service() ) {
          EBox::Service::manage(SERVICE, 'start');
      } else {
          EBox::Service::manage(SERVICE, 'stop');
      }

  }

# Check if at least one watcher and one dispatcher are enabled
sub _adminDumbness
  {

      my ($self) = @_;

      # FIXME: TODO when the juv branch will be merged
#      my $eventModel = $self->configureEventModel();
#      my $dispatcherModel = $self->configureDispatcherModel();
#
#      my $match = $eventModel->find( enabled => 1);
#      defined ( $match ) or
#        throw EBox::Exceptions::External(__('No event watchers have been enabled'));
#
#      $match = $dispatcherModel->find( enabled => 1);
#      defined ( $match ) or
#        throw EBox::Exceptions::External(__('No event dispatchers have been enabled'));

      return undef;

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
                      $element =~ s/::/\//g;
                      my $filePath = EBox::Config::perlPath() . $element . '.pm';
                      copy ( $filePath, $dir )
                        or throw EBox::Exceptions::Internal("Cannot copy from $filePath to $dir");
                  } else {
                      ($element) = $element =~ m/^.*::(.*)$/;
                      my $filePath = $dir . $element . '.pm';
                      if ( -f $filePath ) {
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

          push ( @models,  $className->new(
                                           gconfmodule => $self,
                                           directory   => $fileName,
                                          )
               );

      }

      closedir ( $dir );

      return \@models;

  }

1;
