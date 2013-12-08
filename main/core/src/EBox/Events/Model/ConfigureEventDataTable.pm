# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Model::ModelManager;
use EBox::Types::HasMany;
use EBox::Types::Link;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;

use Error qw(:try);

# Constants:
#
#      WATCHERS_DIR - String directory where the Watchers lie

use constant WATCHERS_DIR => EBox::Config::perlPath() . 'EBox/Event/Watcher';
use constant CONF_DIR => EBox::Config::conf() . 'events/';
use constant ENABLED_WATCHERS_DIR => CONF_DIR . 'WatcherEnabled/';

use constant SB_URL => 'https://store.zentyal.com/small-business-edition.html/?utm_source=zentyal&utm_medium=events&utm_campaign=smallbusiness_edition';
use constant ENT_URL => 'https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=events&utm_campaign=enterprise_edition';

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

# Method: syncRows
#
#      This method is overridden since the showed data is managed
#      differently.
#
#      - The data is already available from the Zentyal installation
#
#      - The adding/removal of event watchers is done dynamically
#      reading the directories where the event watchers are placed
#
#
# Overrides:
#
#        <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    my $modIsChanged = EBox::Global->getInstance()->modIsChanged('events');

    my %storedEventWatchers;
    my %currentEventWatchers;
    my $watchersRef = $self->_fetchWatchers();
    foreach my $watcherFetched (@{$watchersRef}) {
        $currentEventWatchers{$watcherFetched} = 'true';
    }

    my $modified = undef;
    # Removing old ones
    foreach my $id (@{$currentIds}) {
        my $row;
        my $removed = 0;
        try {
            $row = $self->row($id);
        } catch EBox::Exceptions::Base with {
            $self->removeRow( $id );
            $modified = 1;
            $removed  = 1;
        };
        unless ( defined($row) ) {
            $modified = 1;
            $removed  = 1;
        }
        next if ($removed);
        my $stored = $row->valueByName('eventWatcher');
        $storedEventWatchers{$stored} = 'true';
        if ( exists ( $currentEventWatchers{$stored} )) {
            # Check its ability
            my $able = $self->_checkWatcherAbility($stored);
            if ( not $able and $self->_checkWatcherHidden($stored) ) {
                $self->removeRow($id);
            } else {
                $self->setTypedRow($id, undef, readOnly => not $able);
            }
        } else {
            $self->removeRow( $id );
        }
        $modified = 1;
    }

    # Adding new ones
    foreach my $watcher (keys ( %currentEventWatchers )) {
        next if ( exists ( $storedEventWatchers{$watcher} ));
        eval "use $watcher";
        my $able = $self->_checkWatcherAbility($watcher);
        next if ( not $able and $self->_checkWatcherHidden($watcher) );
        my $enabled = not $watcher->DisabledByDefault();
        my %params = ('eventWatcher' => $watcher,
                # The value is obtained dynamically
                'description'  => undef,
                'enabled'      => $enabled,
                'configuration_selected' => 'configuration_'
                . $watcher->ConfigurationMethod(),
                'readOnly'     => not $able,
                );
        if ( $watcher->ConfigurationMethod() eq 'none' ) {
            $params{configuration_none} = '';
        }
        $self->addRow( %params );
        $modified = 1;
    }

    if ($modified and not $modIsChanged) {
        $self->{'gconfmodule'}->_saveConfig();
        EBox::Global->getInstance()->modRestarted('events');
    }
    return $modified;
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
    my $newRow = $self->row($rowRef->id());
    my $enabled = $newRow->valueByName('enabled');
    my $className = $newRow->valueByName('eventWatcher');

    # if the class name is a the log one, check if any log observer is ready
    if ( $className =~ m/::Log$/ and $enabled) {
        $self->_checkLogWatchers();
    }
}

# Method: pageTitle
#
#   Overrides:
#
#       <EBox::Model::Composite::headTitle>
#
# Returns:
#
#
#   undef
sub pageTitle
{
    return undef;
}

# Method: headTitle
#
#   Overrides:
#
#       <EBox::Model::Composite::headTitle>
#
# Returns:
#
#
#   undef
sub headTitle
{
    return undef;
}


# Group: Protected methods

# Method: _table
#
#       The table description which consists of three fields:
#
#       name        - <EBox::Types::Text>
#       description - <EBox::Types::Text>
#       configuration - <EBox::Types::Union>
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
             size          => 12,
             unique        => 1,
             filter        => \&filterName,
             ),
         new EBox::Types::Text(
             fieldName     => 'description',
             printableName => __('Description'),
             size          => 30,
             # The value is obtained dynamically
             volatile      => 1,
             filter        => \&filterDescription,
             ),
         new EBox::Types::Union(
             fieldName     => 'configuration',
             printableName => __('Configuration'),
             editable      => 0,
             subtypes      =>
             [
             new EBox::Types::Link(
                 fieldName               => 'configuration_link',
                 volatile                => 1,
                 acquirer                => \&acquireURL,
                 ),
             new EBox::Types::HasMany(
                 fieldName            => 'configuration_model',
                 foreignModelAcquirer => \&acquireConfModel,
                 backView             => '/Events/Composite/GeneralComposite',
                 ),
             new EBox::Types::Union::Text(
                 fieldName        => 'configuration_none',
                 printableName    => __('None'),
                 ),
             ]
                 ),
             );

    my $dataTable =
    {
        tableName           => 'ConfigureEventDataTable',
        printableTableName  => __('Configure Events'),
        actions => {
            editField  => '/Events/Controller/ConfigureEventDataTable',
            changeView => '/Events/Controller/ConfigureEventDataTable',
        },
        tableDescription    => \@tableHeader,
        class               => 'dataTable',
        rowUnique           => 1,
        printableRowName    => __('event'),
        help                => __('Enable/Disable each event watcher monitoring'),
        enableProperty      => 1,
        defaultEnabledValue => 0,
    };

    return $dataTable;
}

# Group: Callback functions

# Function: filterName
#
#     Callback used to filter the output of the name field. It
#     localises the event name to the configured locale.
#
# Parameters:
#
#     instancedType - <EBox::Types::Text> the cell containing the value
#
# Return:
#
#     String - localised the event name
#
sub filterName
{
    my ($instanceType) = @_;

    my $className = $instanceType->value();

    eval "use $className";
    if ( $@ ) {
        # Error loading class -> watcher to remove
        return;
    }
    my $watcher = $className->new();

    return $watcher->name();
}

# Function: filterDescription
#
#     Callback used to gather the value of the description field. It
#     localises the event description to the configured locale.
#
# Parameters:
#
#     instancedType - <EBox::Types::Text> the cell which will contain
#     the description
#
# Return:
#
#     String - localised the description name
#
sub filterDescription
{
    my ($instancedType) = @_;

    my $className = $instancedType->row()->valueByName('eventWatcher');

    eval "use $className";
    if ( $@ ) {
        # Error loading class -> watcher to remove
        return;
    }
    my $watcher = $className->new();

    return $watcher->description();
}

# Function: acquireConfModel
#
#       Callback function used to gather the foreignModel and its view
#       in order to configure the event watcher
#
# Parameters:
#
#       row - hash ref with the content what is stored in GConf
#       regarding to this row.
#
# Returns:
#
#      String - the foreign model to configurate the watcher
#
sub acquireConfModel
{
    my ($row) = @_;

    my $className = $row->valueByName('eventWatcher');

    eval "use $className";
    if ( $@ ) {
        # Error loading class -> watcher to remove
        # Return the fallback model
        return 'Fallback';
    }

    return $className->ConfigureModel();
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

    my $className = $instancedType->row()->valueByName('eventWatcher');

    eval "use $className";
    if ( $@ ) {
        # Error loading class -> dispatcher to remove
        return;
    }

    return $className->ConfigureURL();
}

# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message
#      if needed
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    my $subscriptionLevel = -1;

    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $subscriptionLevel = $rs->subscriptionLevel();
    }
    unless ($subscriptionLevel > 0) {
        $customizer->setPermanentMessage($self->_commercialMsg(), 'ad');
    }

    return $customizer;
}

# Group: Private methods

# Fetch the current watchers on the system
# Return an array ref with all the class names
sub _fetchWatchers
{
    my ($self) = @_;

    my @watchers;

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
            EBox::warn("Error loading class: $className");
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

# Method to check if there are any log watcher enabled
sub _checkLogWatchers
{
    my ($self) = @_;

    my $manager = EBox::Model::ModelManager->instance();

    my $logWatcherConfModel = $manager->model('/' . $self->{gconfmodule}->name()
                                              . '/LogWatcherConfiguration');

    # Find those log watchers that are enabled
    unless ( $logWatcherConfModel->find( enabled => 1 ) ) {
        $self->setMessage(__('Warning! There is no log domain watcher enabled. '
                             . q{Please, go to 'Configuration' to enable at least }
                             . 'one to be notified when a log in this domain happens. ')
                          . $self->message()
                         );
    }
}

# This method checks if the event watcher is able to monitor the
# event. For example, a RAID watcher makes no sense if the disk
# subsystem does not work with RAID
sub _checkWatcherAbility # (watcherClassName)
{
    my ($self, $watcherClassName) = @_;

    return $watcherClassName->Able();
}

# This method checks if the event watcher must be hidden if not able
# to watch the events in order to not confuse the user
sub _checkWatcherHidden # (watcherClassName)
{
    my ($self, $watcherClassName) = @_;

    return $watcherClassName->HiddenIfNotAble();

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    my $subscriptionLevel = -1;

    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $subscriptionLevel = $rs->subscriptionLevel();
    }
    unless ($subscriptionLevel > 0) {
        $customizer->setPermanentMessage($self->_commercialMsg(), 'ad');
    }

    return $customizer;
}

# Return the commercial message
sub _commercialMsg
{
    return __sx('Want to receive an alert when something has gone wrong in your system? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch} to enable all automatic alerts.',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">',
                ch => '</a>');
}

# this method has been overriden to avoid errors like: 'modelInstance
# /events/LogWatcherFiltering/mailfilter-smtpFilter does not exist.'
# The error is raised in syncRows, becasue adding the row to new subModel
# call this and in it is base version it tries to call models that are
# not yet intitiated
sub filesPathsForRow
{
    return [];
}

1;
