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

# Class:
#
#   EBox::Events::Model::ConfigureWatchers
#
#   This class is used as a model to describe a table which will be
#   used to select the event watchers the user wants to enable/disable
#
#   It subclasses <EBox::Model::DataTable>
#

use strict;
use warnings;

package EBox::Events::Model::ConfigureWatchers;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Config;
use EBox::Exceptions::DataNotFound;
use EBox::Gettext;
use EBox::Model::Manager;
use EBox::Types::HasMany;
use EBox::Types::Link;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;

use TryCatch::Lite;

# Group: Public methods

# Method: syncRows
#
#      This method is overridden since the showed data is managed
#      differently.
#
#      - The data is already available from the Zentyal installation
#
#      - The adding/removal of event watchers is done dynamically
#        by fetching them from the WatcherProvider modules
#
#
# Overrides:
#
#        <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    my %storedEventWatchers;
    my %currentEventWatchers;
    my $watchersRef = $self->_fetchWatchers();
    foreach my $watcherFetched (@{$watchersRef}) {
        $currentEventWatchers{$watcherFetched} = 'true';
    }

    my $modified = 0;

    # Removing old ones
    foreach my $id (@{$currentIds}) {
        my $row;
        my $remove = 0;
        try {
            $row = $self->row($id);
            my $stored = $row->valueByName('watcher');
            $storedEventWatchers{$stored} = 1;
            eval "use $stored";
            if (exists $currentEventWatchers{$stored}) {
                # Check its ability
                my $able = $self->_checkWatcherAbility($stored);
                if (not $able and $self->_checkWatcherHidden($stored)) {
                    $remove = 1;
                } else {
                    $self->setTypedRow($id, undef, readOnly => not $able);
                }
            } else {
                $remove = 1;
            }
        } catch {
            $remove = 1;
        }
        if ($remove) {
            $self->removeRow($id);
            $modified = 1;
        }
    }

    # Adding new ones
    foreach my $watcher (keys (%currentEventWatchers)) {
        next if (exists $storedEventWatchers{$watcher});
        eval "use $watcher";
        my $able = $self->_checkWatcherAbility($watcher);
        next if (not $able and $self->_checkWatcherHidden($watcher));
        my $enabled = not $watcher->DisabledByDefault();
        my %params = ('watcher' => $watcher,
                # The value is obtained dynamically
                'description'  => undef,
                'enabled'      => $enabled,
                'configuration_selected' => 'configuration_' . $watcher->ConfigurationMethod(),
                'readOnly'     => not $able,
                );
        if ( $watcher->ConfigurationMethod() eq 'none' ) {
            $params{configuration_none} = '';
        }
        $self->addRow( %params );
        $modified = 1;
    }

    return $modified;
}

# Method: updatedRowNotify
#
#   Callback when the row has been updated. In this table model,
#   the main change is to switch the state from enabled to disabled
#   and viceversa.
#
# Overrides:
#
#    <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    # Get whether the event watcher is enabled or not
    my $enabled = $row->valueByName('enabled');
    my $className = $row->valueByName('watcher');

    # if the class name is a the log one, check if any log observer is ready
    if ($className =~ m/::Log$/ and $enabled) {
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
             fieldName     => 'watcher',
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
                 backView             => '/Events/Composite/General',
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
        tableName           => 'ConfigureWatchers',
        printableTableName  => __('Configure Events'),
        actions => {
            editField  => '/Events/Controller/ConfigureWatchers',
            changeView => '/Events/Controller/ConfigureWatchers',
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
    if ($@) {
        return undef;
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
    my $row = $instancedType->row();
    if (not $row) {
        return undef;
    }

    my $className = $row->valueByName('watcher');

    eval "use $className";
    if ($@) {
        return undef;
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

    my $className = $row->valueByName('watcher');

    eval "use $className";
    if ($@) {
        return undef;
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

    my $className = $instancedType->row()->valueByName('watcher');

    eval "use $className";
    if ($@) {
        return undef;
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

sub enableWatcher
{
    my ($self, $watcher, $enabled) = @_;
    my $row = $self->findRow(watcher => $watcher);
    if (not $row) {
        throw EBox::Exceptions::DataNotFound(data => 'watcher', value => $watcher);
    }

    $row->elementByName('enabled')->setValue($enabled);
    $row->store();
}

sub isEnabledWatcher
{
    my ($self, $watcher) = @_;
    my $row = $self->findRow(watcher => $watcher);
    if (not $row) {
        throw EBox::Exceptions::DataNotFound(data => 'watcher', value => $watcher);
    }

    return $row->valueByName('enabled');
}

# Group: Private methods

# Fetch the current watchers on the system
# Return an array ref with all the class names
sub _fetchWatchers
{
    my ($self) = @_;

    my $mods = EBox::Global->modInstancesOfType('EBox::Events::WatcherProvider');
    my @watchers = map { "EBox::Event::Watcher::$_" } map { @{$_->eventWatchers()} } @{$mods};
    return \@watchers;
}

# FIXME: check this
# Method to check if there are any log watcher enabled
sub _checkLogWatchers
{
    my ($self) = @_;

    my $manager = EBox::Model::Manager->instance();

    my $logWatcherConfModel = $manager->model('/' . $self->{confmodule}->name()
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
sub _checkWatcherAbility
{
    my ($self, $watcherClassName) = @_;

    return $watcherClassName->Able();
}

# This method checks if the event watcher must be hidden if not able
# to watch the events in order to not confuse the user
sub _checkWatcherHidden
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
    return __sx('Want to receive an alert when something has gone wrong in your system? Get one of the {oh}Commercial Editions{ch} to enable all automatic alerts.',
                oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
}

1;
