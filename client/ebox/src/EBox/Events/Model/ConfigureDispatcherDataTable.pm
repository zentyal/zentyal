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

package EBox::Events::Model::ConfigureDispatcherDataTable;

# Class:
#
#   EBox::Events::Model::ConfigureDispatcherDataTable
#
#   This class is used as a model to describe a table which will be
#   used to select the event dispatchers the user wants
#   to enable/disable and each dispatcher configuration.
#
#   It subclasses <EBox::Model::DataTable>
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Link;
use EBox::Types::HasMany;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Constants:
#
#      DISPATCHER_DIR - String directory where the Dispatchers are

use constant DISPATCHER_DIR => EBox::Config::perlPath() . 'EBox/Event/Dispatcher';
use constant CONF_DIR => EBox::Config::conf() . 'events/';
use constant ENABLED_DISPATCHER_DIR => CONF_DIR . 'DispatcherEnabled/';

# Group: Public methods

# Constructor: new
#
#       Create the new ConfigureDispatcherDataTable model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Events::Model::ConfigureDispatcherDataTable> - the recently
#       created model
#
sub new
  {

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless ( $self, $class );

      # Create the Events configuration directory
      unless ( -d ( CONF_DIR )) {
          mkdir ( CONF_DIR, 0700 );
      }
      unless ( -d ENABLED_DISPATCHER_DIR ) {
          mkdir ( ENABLED_DISPATCHER_DIR, 0700 );
      }

      return $self;

  }

# Method: rows
#
#      This method is overridden since the showed data is managed
#      differently.
#
#      - The data is already available from the eBox installation
#
#      - The adding/removal of event dispatchers is done dynamically
#      reading the directories where the event dispatcher are. The
#      adding/removal is done installing or deinstalling ebox modules
#      with dispatchers.
#
#
# Overrides:
#
#        <EBox::Model::DataTable::rows>
#
sub rows
  {

      my ($self, $filter, $page) = @_;

      # Fetch the current event watchers from gconf
      my $currentRows = $self->SUPER::rows();

      my %storedEventDispatchers;
      foreach my $currentRow (@{$currentRows}) {
          $storedEventDispatchers{$currentRow->{valueHash}->{eventDispatcher}->value()} = 'true';
      }

      my %currentEventDispatchers;
      my $dispatchersRef = $self->_fetchDispatchers();
      foreach my $dispatcherFetched (@{$dispatchersRef}) {
          $currentEventDispatchers{$dispatcherFetched} = 'true';
      }

      # Adding new ones
      foreach my $dispatcher (keys ( %currentEventDispatchers )) {
          next if ( exists ( $storedEventDispatchers{$dispatcher} ));
          # Create a new instance from this dispatcher
          eval "use $dispatcher";

          my %params = (
                        'eventDispatcher'        => $dispatcher,
                        # The value is obtained dynamically
                        'receiver'               => '',
                        # The events are disabled by default
                        'enabled'                => 0,
                        'configuration_selected' => 'configuration_' .
                                                    $dispatcher->ConfigurationMethod(),
                       );

          if ( $dispatcher->ConfigurationMethod() eq 'none') {
              $params{configuration_none} = '';
          }

          $self->addRow(%params);
      }

      # Removing old ones
      foreach my $row (@{$currentRows}) {
          my $stored = $row->{valueHash}->{eventDispatcher}->value();
          next if ( exists ( $currentEventDispatchers{$stored} ));
          $self->removeRow( $row->{id} );
      }

      return $self->SUPER::rows($filter, $page);

  }

# Method: updatedRowNotify
#
#      Callback when the row has been updated. In this table model,
#      the main change is to switch the state from enabled to disabled
#      and viceversa.
#
# Overrides:
#
#      <EBox::Model::DataTable::updatedRowNotify>
#
# Parameters:
#
#      oldRowRef - hash ref named parameters containing the old row values
#
#
sub updatedRowNotify
  {

      my ($self, $rowRef) = @_;

      # Get whether the event watcher is enabled or not
      my $newRow = $self->row($rowRef->{id});
      my $enabled = $newRow->{valueHash}->{enabled}->{value};
      my $className = $newRow->{valueHash}->{eventDispatcher}->{value};

      # Set to move
      $self->{gconfmodule}->enableEventElement('dispatcher', $className, $enabled);

  }

# Method: validateTypedRow
#
#      Check if the dispatcher has been configurated to be enabled
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::External> - thrown if the dispatcher tries
#      to be enabled when it is not configurated
#
sub validateTypedRow
  {

      my ( $self, $action, $newFields ) = @_;

      if ( $action eq 'update' ) {
          $self->_checkIfConfigured($newFields);
          $self->_checkEnabled($newFields);
      }

  }

# Group: Protected methods

# Method: _table
#
#       The table description which consists of three fields:
#
#       name          - <EBox::Types::Text>
#       description   - <EBox::Types::Text>
#       configuration - <EBox::Types::Union>. It could have one of the following:
#                     - model - <EBox::Types::HasMany>
#                     - link  - <EBox::Types::Link>
#                     - none  - <EBox::Types::Union::Text>
#       enabled       - <EBox::Types::Boolean>
#
#       You can only edit enabled and configuration fields. The event
#       name and description are read-only fields.
#
sub _table
  {

      my @tableHeader =
        (
         new EBox::Types::Text(
                               fieldName     => 'eventDispatcher',
                               printableName => __('Name'),
                               class         => 'tleft',
                               size          => 12,
                               unique        => 1,
                               editable      => 0,
                               optional      => 0,
                               filter        => \&filterName,
                              ),
         new EBox::Types::Text(
                               fieldName     => 'receiver',
                               printableName => __('Receiver'),
                               class         => 'tcenter',
                               size          => 30,
                               unique        => 0,
                               optional      => 1,
                               editable      => 0,
                               # The value is obtained dynamically
                               volatile      => 1,
                               filter        => \&filterReceiver,
                              ),
         new EBox::Types::Union(
                                fieldName     => 'configuration',
                                printableName => __('Configuration'),
                                class         => 'tcenter',
                                editable      => 0,
                                subtypes      =>
                                [
                                 new EBox::Types::Link(
                                                       fieldName => 'configuration_link',
                                                       editable  => 0,
                                                       volatile  => 1,
                                                       acquirer  => \&acquirerURL,
                                                      ),
                                 new EBox::Types::HasMany(
                                                          fieldName            => 'configuration_model',
                                                          backView             => '/ebox/Events/View/ConfigureDispatcherDataTable',
                                                          size                 => 1,
                                                          trailingText         => '',
                                                          foreignModelAcquirer => \&acquireConfModel,
                                                         ),
                                 new EBox::Types::Union::Text(
                                                              fieldName     => 'configuration_none',
                                                              printableName => __('None'),
                                                             ),
                                ]
                               ),
         new EBox::Types::Boolean(
                                  fieldName     => 'enabled', 
                                  printableName => __('Enabled'),
                                  class         => 'tcenter',
                                  type          => 'boolean',
                                  size          => 1,
                                  unique        => 0,
                                  trailingText  => '',
                                  editable      => 1,
                                  # Set in order to store the type
                                  # metadata since sometimes the field
                                  # is editable and some not
                                  storeMetadata => 1,
                                  )
        );

      my $dataTable =
        {
         tableName          => 'ConfigureDispatcherDataTable',
         printableTableName => __('Configure dispatchers'),
         actions => {
                     editField  => '/ebox/Events/Controller/ConfigureDispatcherDataTable',
                     changeView => '/ebox/Events/Controller/ConfigureDispatcherDataTable',
                    },
         tableDescription   => \@tableHeader,
         class              => 'dataTable',
         order              => 0,
         rowUnique          => 1,
         printableRowName   => __('dispatcher'),
         help               => __('Enable/Disable each event dispatcher'),
        };

  }

# Group: Callback functions

# Function: filterName
#
#     Callback used to filter the output of the name field. It
#     localises the dispatcher name to the configured locale.
#
# Parameters:
#
#     instancedType - <EBox::Types::Text> the cell which will contain
#     the name
#
# Returns:
#
#     String - localised the dispatcher name
#
sub filterName
  {

      my ($instancedType) = @_;

      my $className = $instancedType->value();

      eval "use $className";
      if ( $@ ) {
          # Error loading class -> dispatcher to remove
          return;
      }
      my $dispatcher = $className->new();

      return $dispatcher->name();

  }

# Function: filterReceiver
#
#     Callback used to gather the value of the receiver field. It
#     localises the event receiver to the configured locale.
#
# Parameters:
#
#     instancedType - <EBox::Types::Text> the cell which will contain
#     the receiver
#
# Returns:
#
#     String - localised the event receiver name
#
sub filterReceiver
  {

      my ($instancedType) = @_;

      my $className = $instancedType->row()->{valueHash}->{eventDispatcher}->value();

      eval "use $className";
      if ( $@ ) {
          # Error loading class -> dispatcher to remove
          return;
      }
      my $dispatcher = $className->new();

      return $dispatcher->receiver();

  }

# Function: acquireURL
#
#      Callback function used to gather the URL that will fill the
#      value for the link
#
# Parameters:
#
#      instancedType - <EBox::Types::Abstract> the cell which will contain
#      the URL
#
# Returns:
#
#      String - the URL
#
sub acquireURL
  {

      my ($instancedType) = @_;

      my $className = $instancedType->row()->{plainValueHash}->{eventDispatcher};

      eval "use $className";
      if ( $@ ) {
          # Error loading class -> dispatcher to remove
          return;
      }

      return $className->ConfigureURL();

  }

# Function: acquireConfModel
#
#       Callback function used to gather the foreignModel and its view
#       in order to configure the event dispatcher
#
# Parameters:
#
#       row - hash ref with the content what is stored in GConf
#       regarding to this row.
#
# Returns:
#
#      String - the foreign model to configurate the dispatcher
#
sub acquireConfModel
  {

      my ($row) = @_;

      my $className = $row->{eventDispatcher};

      eval "use $className";
      if ( $@ ) {
          # Error loading class -> dispatcher to remove
          return;
      }

      return $className->ConfigureModel();

  }

# Group: Private methods

# Fetch the current dispatchers on the system
# Return an array ref with all the class names
sub _fetchDispatchers
  {
      my ($self) = @_;

      my @dispatchers = ();

      # Fetch the current available event dispatchers
      my $dirPath = DISPATCHER_DIR;
      opendir ( my $dir, $dirPath );

      while ( defined ( my $file = readdir ( $dir ))) {
          next unless (-f "$dirPath/$file");
          next unless ( $file =~ m/.*\.pm/);
          my ($className) = ($file =~ m/(.*)\.pm/);
          $className = 'EBox::Event::Dispatcher::' . $className;
          # Test the class
          eval "use $className";
          if ( $@ ) {
              EBox::warn("Error loading class: $className");
              next;
          }
          # It should be an event dispatcher
          next unless ( $className->isa('EBox::Event::Dispatcher::Abstract'));
          # It shouldn't be the abstract event dispatcher
          next if ( $className eq 'EBox::Event::Dispatcher::Abstract' );

          push ( @dispatchers, $className );
      }
      closedir ( $dir );

      return \@dispatchers;

  }

# Check if the event dispatcher is already configurated or not
sub _checkIfConfigured # (newFields)
  {

      my ($self, $newFields) = @_;

      my $className = $newFields->{enabled}->row()->{plainValueHash}->{eventDispatcher};

      eval "use $className";
      if ( $@ ) {
          # Error loading class -> dispatcher to remove
          return;
      }

      my $dispatcher = $className->new();
      if ( (not $dispatcher->configured()) and
           $newFields->{enabled}->value() ) {
          throw EBox::Exceptions::External(__('In order to enable a configurable event ' .
                                              'dispatcher, you need to configure it first'));
      }

  }

# Check if the event dispatcher is enabled to send messages
sub _checkEnabled # (newFields)
  {

      my ($self, $newFields) = @_;

      # Check if it is capable only if it is enabled to send events
      if ( $newFields->{enabled}->value() ) {
          my $className = $newFields->{enabled}->row()->{plainValueHash}->{eventDispatcher};

          eval "use $className";
          if ( $@ ) {
              # Error loading class -> dispatcher to remove
              return;
          }

          my $dispatcher = $className->new();

          return $dispatcher->enable();
      } else {
          return 1;
      }

  }



1;
