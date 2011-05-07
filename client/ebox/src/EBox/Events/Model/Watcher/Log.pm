# Copyright (C) 2008-2010 eBox Technologies S.L.
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

# Class: EBox::Events::Model::Watcher::Log
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

package EBox::Events::Model::Watcher::Log;
use strict;
use warnings;

use base 'EBox::Model::DataTable';

use EBox::Exceptions::DataNotFound;
use EBox::Events::Model::Watcher::LogFiltering;
use EBox::Gettext;
use EBox::Global;
use EBox::Model::ModelManager;
use EBox::Types::HasMany;
use EBox::Types::Text;

# Core modules
use Error qw(:try);

# Constants
use constant FILTERING_MODEL_NAME => 'LogWatcherFiltering';

# Group: Public methods

# Constructor: new
#
#     Create the configure the log watchers
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Events::Model::Watcher::Log>
#
sub new
  {
      my $class = shift;

      my $self = $class->SUPER::new(@_);
      bless ( $self, $class);

      $self->{logs} = EBox::Global->modInstance('logs');
      $self->{models} = [];

      return $self;

  }

# Method: subModels
#
#     Return the list of models which has to be included in model
#     manager
#
# Returns:
#
#     array ref - containing all models
#
sub subModels
{

    my ($self) = @_;

    $self->_setUpModels();
    return $self->{models};

}

# Method: _ids
#
# Overrides:
#
#        <EBox::Model::DataTable::_ids>
#
#   It is overriden to work around an issue that affects
#   the removal of unexisting rows.
#
#   It returns ids which actually exist
sub _ids
{
    my ($self) = @_;

    my $currentIds = $self->SUPER::_ids();

    my $logs = $self->{logs};

    # Set up every model
    $self->_setUpModels();

    # Fetch the current available log domains
    my %currentLogDomains;
    my $currentTables = $logs->getAllTables();
    foreach my $table (keys (%{$currentTables})) {
        $currentLogDomains{$table} = 1;
    }

    my @realIds;
    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        my $domain = $row->valueByName('domain');
        push (@realIds, $id) if (exists $currentLogDomains{$domain});
    }

    return \@realIds;
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
    my $logs = $self->{logs};
    my $modChanged = Box::Global->getInstance()->modIsChanged('events');

    # Set up every model
    $self->_setUpModels();

    # Fetch the current log domains stored in gconf
    my %storedLogDomains;
    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        $storedLogDomains{$row->valueByName('domain')} = 1;
    }

    # Fetch the current available log domains
    my %currentLogDomains;
    my $currentTables = $logs->getAllTables();
    foreach my $table (keys (%{$currentTables})) {
        # ignore events table
        if ($table eq 'events') {
            next;
        }
        $currentLogDomains{$table} = 1;
    }

    # Add new domains to gconf
    foreach my $domain (keys %currentLogDomains) {
        next if (exists $storedLogDomains{$domain});
        $self->addRow('domain' => $domain, 'enabled' => 0);
        $anyChange = 1;
    }

    # Remove non-existing domains from gconf
    foreach my $id (@{$currentIds}) {
        my $row = $self->row($id);
        my $domain = $row->valueByName('domain');
        next if (exists $currentLogDomains{$domain});
        $self->removeRow($id);
        $self->_removeFilteringModel($domain);
        $anyChange = 1;
    }


    if ($anyChange and (not $modChanged)) {
        $self->{gconfodule}->_saveConfig();
        EBox::Global->getInstance()->modRestarted('logs');
    }

    return $anyChange;
}

# Method: updatedRowNotify
#
# Overrides:
#
#     <EBox::Model::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $oldRow, $force) = @_;

    my $row = $self->row($oldRow->id());

    # Warn if the parent log observer is not enabled
    if ( $row->valueByName('enabled') ) {
        my $manager = EBox::Model::ModelManager->instance();
        my $eventModel = $manager->model('ConfigureEventDataTable');
        my $logConfRow = $eventModel->findValue( eventWatcher => 'EBox::Event::Watcher::Log' );
        unless ( $logConfRow->valueByName('enabled') ) {
            $self->setMessage(__('Warning! The log watcher is not enabled. '
                                 . 'Enable to be notified when logs happen. '
                                 . $self->message()));
        }
    }

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

    # Warn if the parent log observer is not enabled
    if ( $row->valueByName('enabled') ) {
        my $manager = EBox::Model::ModelManager->instance();
        my $eventModel = $manager->model('ConfigureEventDataTable');
        my $logConfRow = $eventModel->findValue( eventWatcher => 'EBox::Event::Watcher::Log' );
        unless ( $logConfRow->valueByName('enabled') ) {
            $self->setMessage(__('Warning! The log watcher is not enabled. '
                                 . 'Enable to be notified when logs happen. '
                                 . $self->message()));
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
                                  backview      => '/ebox/Events/View/LogWatcherConfiguration?directory=Log',
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

    return '/events/' . FILTERING_MODEL_NAME . "/$logDomain";

}

# Group: Private methods

# Set up the already created models
sub _setUpModels
{

    my ($self) = @_;

    my $logDomainTables = $self->{logs}->getAllTables();
    if ( defined ( $logDomainTables )) {
        while (my ($domain, $tableInfo) = each %{$logDomainTables}) {
            if ($domain eq 'events') {
                # avoid observe recuservely itself!
                next;
            }
            push ( @{$self->{models}},
                   $self->_createFilteringModel($domain, $tableInfo));

        }
    }

}

# Create a new filtering model given a
# log domain and notify this new model to model manager
sub _createFilteringModel # (domain)
{
    my ($self, $domain, $domainTableInfo) = @_;
    if (not defined $domainTableInfo) {
      $domainTableInfo = $self->{logs}->getTableInfo($domain);
    }


    my $filteringModel = new EBox::Events::Model::Watcher::LogFiltering(
                                                                     gconfmodule => $self->{gconfmodule},
                                                                     directory   => $self->{gconfdir},
                                                                     tableInfo => $domainTableInfo,
                                                                    );

    return $filteringModel;

}

# Remove an existing filtering model given a
# log domain and notify this removal to model manager
sub _removeFilteringModel # (domain)
{
    my ($self, $domain) = @_;

    my $modelManager = EBox::Model::ModelManager->instance();

    $modelManager->removeModel('/events/' . FILTERING_MODEL_NAME . "/$domain");

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
                link  => '/ebox/Events/Composite/GeneralComposite',
                },
                {
                title => __('Log Observer Watcher'),
                link  => ''
                }
        ]);

        return $custom;
}

1;
