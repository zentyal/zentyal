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

# Class:
#
#   EBox::Events::Model::ConfigureDispatchers
#
#   This class is used as a model to describe a table which will be
#   used to select the event dispatchers the user wants
#   to enable/disable and each dispatcher configuration.
#
#   It subclasses <EBox::Model::DataTable>
#
package EBox::Events::Model::ConfigureDispatchers;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Config;
use EBox::Exceptions::DataNotFound;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Link;
use EBox::Types::HasMany;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;

use TryCatch::Lite;

# Group: Public methods

# Method: headTitle
#
#       Get the i18ned name of the header where the model is contained, if any
#
# Returns:
#
#   string
#
sub headTitle
{
    my ($self) = @_;

    return undef;
}

# Method: syncRows
#
#      This method is overridden since the showed data is managed
#      differently.
#
#      - The data is already available from the Zentyal installation
#
#      - The adding/removal of event dispatchers is done dynamically
#        by fetching them from the DispatcherProvider modules
#
#
# Overrides:
#
#        <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    my %storedEventDispatchers;
    my %currentEventDispatchers;
    my $dispatchersRef = $self->_fetchDispatchers();
    foreach my $dispatcherFetched (@{$dispatchersRef}) {
        $currentEventDispatchers{$dispatcherFetched} = 1;
    }

    my $modified = 0;

    # Removing old ones
    foreach my $id (@{$currentIds}) {
        my $row;
        my $remove = 0;
        try {
            $row = $self->row($id);
            my $stored = $row->valueByName('dispatcher');
            $storedEventDispatchers{$stored} = 1;
            if (not exists $currentEventDispatchers{$stored}) {
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
    foreach my $dispatcher (keys (%currentEventDispatchers)) {
        next if (exists ($storedEventDispatchers{$dispatcher} ));
        # Create a new instance from this dispatcher
        eval "use $dispatcher";
        if ($@) {
            EBox::error("Error loading dispatcher: $@");
            next;
        }
        my $enabled = not $dispatcher->DisabledByDefault();
        my %params = (
                # and the same with watchers
                'dispatcher'        => $dispatcher,
                # The value is obtained dynamically
                'receiver'               => '',
                # The dispatchers are disabled by default
                'enabled'                => $enabled,
                'configuration_selected' => 'configuration_' . $dispatcher->ConfigurationMethod(),
                'readOnly'               => not $dispatcher->EditableByUser(),
                );

        if ($dispatcher->ConfigurationMethod() eq 'none') {
            $params{configuration_none} = '';
        }

        $self->addRow(%params);
        $modified = 1;
    }

    return $modified;
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
    my @tableHeader = (
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
        ),
        new EBox::Types::Text(
            fieldName     => 'dispatcher',
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
            subtypes      => [
               new EBox::Types::Link(
                   fieldName => 'configuration_link',
                   editable  => 0,
                   volatile  => 1,
                   acquirer  => \&acquireURL,
               ),
               new EBox::Types::HasMany(
                   fieldName            => 'configuration_model',
                   backView             => '/Events/Composite/General',
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
    );

    my $dataTable =
    {
        tableName          => 'ConfigureDispatchers',
        printableTableName => __('Configure Dispatchers'),
        actions => {
            editField  => '/Events/Controller/ConfigureDispatchers',
            changeView => '/Events/Controller/ConfigureDispatchers',
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
    if ($@) {
        EBox::error("When loading dispatcher: $className: $@");
        return undef;
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

    my $className = $instancedType->row()->valueByName('dispatcher'); #XXX eror here

    eval "use $className";
    if ($@) {
        EBox::error("When loading dispatcher $className: $@");
        return undef;
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

    my $className = $instancedType->row()->valueByName('dispatcher');

    eval "use $className";
    if ($@) {
        EBox::error("When loading dispatcher $className: $@");
        return undef;
    }

    return $className->ConfigureURL();
}

# Function: acquireConfModel
#
#       Callback function used to gather the URL
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

    my $className = $row->valueByName('dispatcher');

    eval "use $className";
    if ($@) {
        EBox::error("When loading dispatcher $className: $@");
        return undef;
    }

    return $className->ConfigureModel();
}

sub enableDispatcher
{
    my ($self, $dispatcher, $enabled) = @_;
    my $row = $self->findRow(dispatcher => $dispatcher);
    if (not $row) {
        throw EBox::Exceptions::DataNotFound(data => 'dispatcher', value => $dispatcher);
    }

    $row->elementByName('enabled')->setValue($enabled);
    $row->store();
}

sub isEnabledDispatcher
{
    my ($self, $dispatcher) = @_;
    my $row = $self->findRow(dispatcher => $dispatcher);
    if (not $row) {
        throw EBox::Exceptions::DataNotFound(data => 'dispatcher', value => $dispatcher);
    }

    return $row->valueByName('enabled');
}

# Group: Private methods

# Fetch the current dispatchers on the system
# Return an array ref with all the class names
sub _fetchDispatchers
{
    my ($self) = @_;

    my $mods = EBox::Global->modInstancesOfType('EBox::Events::DispatcherProvider');
    my @dispatchers = map { "EBox::Event::Dispatcher::$_" } map { @{$_->eventDispatchers()} } @{$mods};
    return \@dispatchers;
}

1;
