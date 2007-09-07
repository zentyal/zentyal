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

package EBox::Events::Model::ConfigureEventDataTable;

# Class:
#
#   EBox::Events::Model::ConfigureEventDataTable
#
#   This class is used as a model to describe a table which will be
#   used to select the event watchers the user wants to enable/disable
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
use EBox::Types::Text;
use EBox::Types::Boolean;

# Constants:
#
#      WATCHERS_DIR - String directory where the Watchers lie

use constant WATCHERS_DIR => EBox::Config::perlPath() . 'EBox/Event/Watcher';
use constant CONF_DIR => EBox::Config::conf() . 'events/';
use constant ENABLED_WATCHERS_DIR => CONF_DIR . 'WatcherEnabled/';

# Group: Public methods

# Constructor: new
#
#       Create the new ConfigureEventDataTable model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Events::Model::ConfigureEventDataTable> - the recently
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
      unless ( -d (ENABLED_WATCHERS_DIR)) {
          mkdir ( ENABLED_WATCHERS_DIR, 0700 );
      }

      return $self;

  }

# Function: filterName
#
#     Callback used to filter the output of the name field. It
#     localises the event name to the configured locale.
#
# Parameters:
#
#     className - String the event watcher class name
#
# Return:
#
#     String - localised the event name
#
sub filterName
  {

      my ($className) = @_;

      eval "use $className";
      my $watcher = $className->new();

      return $watcher->name();

  }

# Function: wangleDescription
#
#     Callback used to gather the value of the description field. It
#     localises the event description to the configured locale.
#
# Parameters:
#
#     hash - hash ref containing the containment of a data table
#     row
#
# Return:
#
#     String - localised the description name
#
sub wangleDescription
  {

      my ($hashRef) = @_;

      my $className = $hashRef->{eventWatcher};

      eval "use $className";
      my $watcher = $className->new();

      return $watcher->description();

  }

# Method: rows
#
#      This method is overridden since the showed data is managed
#      differently.
#
#      - The data is already available from the eBox installation
#
#      - The adding/removal of event watchers is done dynamically
#      reading the directories where the event watchers lies
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

      my %storedEventWatchers;
      foreach my $currentRow (@{$currentRows}) {
          $storedEventWatchers{$currentRow->{valueHash}->{eventWatcher}->value()} = 'true';
      }

      my %currentEventWatchers;
      my $watchersRef = $self->_fetchWatchers();
      foreach my $watcherFetched (@{$watchersRef}) {
          $currentEventWatchers{$watcherFetched} = 'true';
      }

      # Adding new ones
      foreach my $watcher (keys ( %currentEventWatchers )) {
          next if ( exists ( $storedEventWatchers{$watcher} ));
          $self->addRow( 'eventWatcher' => $watcher,
                         # The value is obtained dynamically
                         'description'  => undef,
                         # The events are disabled by default
                         'enabled'      => 0,
                       );
      }

      # Removing old ones
      foreach my $row (@{$currentRows}) {
          my $stored = $row->{valueHash}->{eventWatcher}->value();
          next if ( exists ( $currentEventWatchers{$stored} ));
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
      my $className = $newRow->{valueHash}->{eventWatcher}->{value};

      # Set to move
      $self->{gconfmodule}->enableEventElement('watcher', $className, $enabled);


  }

# Group: Protected methods

# Method: _table
#
#       The table description which consists of three fields:
#
#       name        - <EBox::Types::Text>
#       description - <EBox::Types::Text>
#       enabled     - <EBox::Types::Boolean>
#
#       You can only edit enabled field to activate or deactivate the
#       event. The event name and description are read-only fields.
#
sub _table
  {

      my @tableHeader =
        (
         new EBox::Types::Text(
                               fieldName     => 'eventWatcher',
                               printableName => __('Name'),
                               class         => 'tleft',
                               type          => 'text',
                               size          => 12,
                               unique        => 1,
                               editable      => 0,
                               optional      => 0,
                               filter        => \&filterName,
                              ),
         new EBox::Types::Text(
                               fieldName     => 'description',
                               printableName => __('Description'),
                               class         => 'tcenter',
                               type          => 'text',
                               size          => 30,
                               unique        => 0,
                               optional      => 1,
                               editable      => 0,
                               # The value is obtained dynamically
                               volatile      => 1,
                               wangler       => \&wangleDescription,
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
                                  )
        );

      my $dataTable =
        {
         tableName          => 'ConfigureEventDataTable',
         printableTableName => __('Configure events'),
         actions => {
                     editField  => '/ebox/Events/Controller/ConfigureEventDataTable',
                     changeView => '/ebox/Events/Controller/ConfigureEventDataTable',
                    },
         tableDescription   => \@tableHeader,
         class              => 'dataTable',
         order              => 0,
         rowUnique          => 1,
         printableRowName   => __('event'),
         help               => __('Enable/Disable each event watcher monitoring'),
        };

  }

# Group: Private methods

# Fetch the current watchers on the system
# Return an array ref with all the class names
sub _fetchWatchers
  {
      my ($self) = @_;

      my @watchers = ();

      # Fetch the current available event watchers
      my $dirPath = WATCHERS_DIR;
      opendir ( my $dir, $dirPath );

      while ( defined ( my $file = readdir ( $dir ))) {
          next unless (-f "$dirPath/$file");
          next unless ( $file =~ m/.*\.pm/);
          my ($className) = ($file =~ m/(.*)\.pm/);
          $className = 'EBox::Event::Watcher::' . $className;
          # Test the class
          eval "use $className";
          if ( $@ ) {
              EBox::warn('Error loading class: $className');
              next;
          }
          # It should be an event watcher
          next unless ( $className->isa('EBox::Event::Watcher::Base'));
          # It shouldn't be the base event watcher
          next if ( $className eq 'EBox::Event::Watcher::Base' );

          push ( @watchers, $className );
      }
      closedir ( $dir );

      return \@watchers;

  }



1;

