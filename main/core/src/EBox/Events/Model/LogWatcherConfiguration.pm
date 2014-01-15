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
# Class: EBox::Events::Model::LogWatcherConfiguration
#
# This class is the model to configurate Log watcher. It has as many
# rows as logger exist in eBox
#
# The fields are the following:
#
#    - name - the logger name (i18ned)
#    - filtering - model to configure as many filters as you may need
#    - enabled - enabled the event notification for that logger
#

package EBox::Events::Model::LogWatcherConfiguration;

use base 'EBox::Model::DataTable';

use EBox::Exceptions::DataNotFound;
use EBox::Events::Model::LogFiltering;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::Manager;
use EBox::Types::HasMany;
use EBox::Types::Text;

# Core modules
use TryCatch::Lite;

# Constants
use constant FILTERING_MODEL_NAME => 'LogWatcherFiltering';

# Group: Public methods

# Method: setUpModels
#
#     Set in model manager the dynamic models for log watcher
#     configuration per domain
#
#     The result of this method is to include in model manager the
#     dynamic models (one per log domain)
#
sub setUpModels
{
    my ($self) = @_;

    my $manager = EBox::Model::Manager->instance();

    my $readOnly = $self->parentModule()->isReadOnly();
    my $logs = EBox::Global->getInstance($readOnly)->modInstance('logs');
    my $logDomainTables = $logs->getAllTables(1);
    if (defined ( $logDomainTables)) {
        while (my ($domain, $tableInfo) = each %{$logDomainTables}) {
            next if ($domain eq 'events'); # avoid observe recursively itself!
            $manager->addModel($self->_createFilteringModel($domain, $tableInfo));
        }
    }
}

# Method: syncRows
#
# Overrides:
#
#        <EBox::Model::DataTable::syncRows>
#
#   It is overriden because this table is kind of different in
#   comparation to the normal use of generic data tables.
#
#   - The user does not add rows. When we detect the table is
#   empty we populate the table with the available log domains.
#
#   - We check if we have to add/remove one the log domains. That happens
#   when a new module is installed or an existing one is removed.
#
sub syncRows
{
    my ($self, $currentIds) = @_;

    my $anyChange = undef;
    my $logs = EBox::Global->modInstance('logs');

    # Set up every dynamic model
    $self->setUpModels();

    # Fetch the current log domains stored in conf
    my %storedLogDomains;
    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        $storedLogDomains{$row->valueByName('domain')} = 1;
    }

    # Fetch the current available log domains
    my %currentLogDomains;
    my $currentTables = $logs->getAllTables(1);
    foreach my $table (keys (%{$currentTables})) {
        next if ($table eq 'events'); # ignore events table
        $currentLogDomains{$table} = 1;
    }

    # Add new domains to conf
    foreach my $domain (keys %currentLogDomains) {
        next if (exists $storedLogDomains{$domain});
        $self->addRow('domain' => $domain, 'enabled' => 0);
        $anyChange = 1;
    }

    # Remove non-existing domains from conf
    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        my $domain = $row->valueByName('domain');
        next if (exists $currentLogDomains{$domain});
        $self->removeRow($id);
        $self->_removeFilteringModel($domain);
        $anyChange = 1;
    }

    return $anyChange;
}

# Method: updatedRowNotify
#
# Overrides:
#
#   <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    $self->_warnIfParentWatcherNotEnabled($row);
}

# Method: addedRowNotify
#
# Overrides:
#
#     <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $row, $force) = @_;
    $self->_warnIfParentWatcherNotEnabled($row);
}

sub _warnIfParentWatcherNotEnabled
{
    my ($self, $row) = @_;
    # Warn if the parent log observer is not enabled
    if ($row->valueByName('enabled')) {
        my $watchersModel = $self->parentModule()->model('ConfigureWatchers');
        my $watcherEnabled = $watchersModel->isEnabledWatcher('EBox::Event::Watcher::Log');
        if (not $watcherEnabled) {
            $self->setMessage(__('Warning! The log watcher is not enabled. '
                                 . 'Enable to be notified when logs happen.')
                                 . '<br/>'
                                 . $self->message());
        }
    }
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Text(
             fieldName     => 'domain',
             printableName => __('Domain'),
             editable      => 0,
             ),
         new EBox::Types::HasMany(
             fieldName     => 'filters',
             printableName => __('Filtering'),
             foreignModelAcquirer => \&acquireFilteringModel,
             backView      => '/Events/View/LogWatcherConfiguration?directory=Log',
             ),
        );

    my $dataForm = {
        tableName           => 'LogWatcherConfiguration',
        printableTableName  => __('Configure log watchers'),
        modelDomain         => 'Events',
        printableRowName    => __('Log watcher'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        class               => 'dataTable',
        help                => '',
        enableProperty      => 1,
        defaultEnabledValue => 0,
    };

    return $dataForm;
}

# Group: Callback functions

# Function: acquireFilteringModel
#
#       Callback function used to gather the foreignModel and its view
#       in order to configure the log event watcher filters
#
# Parameters:
#
#       row - hash ref with the content what is stored in GConf
#       regarding to this row.
#
# Returns:
#
#      String - the foreign model to configurate the filters
#      associated to the log event watcher
#
sub acquireFilteringModel
{
    my ($row) = @_;

    my $logDomain = $row->valueByName('domain');

    return 'events/' . FILTERING_MODEL_NAME . "_$logDomain";
}

# Group: Private methods

# Create a new filtering model given a
# log domain and notify this new model to model manager
sub _createFilteringModel
{
    my ($self, $domain, $domainTableInfo) = @_;

    if (not defined $domainTableInfo) {
        my $logs = EBox::Global->modInstance('logs');
        $domainTableInfo = $logs->getTableInfo($domain);
    }

    my $filteringModel = new EBox::Events::Model::LogFiltering(confmodule => $self->{confmodule},
                                                               directory  => $self->{confdir},
                                                               tableInfo  => $domainTableInfo);
    return $filteringModel;
}

# Remove an existing filtering model given a
# log domain and notify this removal to model manager
sub _removeFilteringModel
{
    my ($self, $domain) = @_;

    my $modelManager = EBox::Model::Manager->instance();
    $modelManager->removeModel('events/' . FILTERING_MODEL_NAME . "_$domain");
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to
#   provide a custom HTML title with breadcrumbs
#
sub viewCustomizer
{
    my ($self) = @_;

    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([
                {
                    title => __('Events'),
                    link  => '/Events/Composite/General',
                },
                {
                    title => __('Log Observer Watcher'),
                    link  => ''
                }
            ]);

    return $custom;
}

1;
