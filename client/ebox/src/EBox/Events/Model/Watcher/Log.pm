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

use base 'EBox::Model::DataTable';

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Model::ModelManager;
use EBox::Types::HasMany;
use EBox::Types::Text;

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

      return $self;

  }

# Method: rows
#
# Overrides:
#
#        <EBox::Model::DataTable>
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
sub rows
{
    my ($self, $filter, $page) = @_;

    my $logs = $self->{logs};

    # Fetch the current log domains stored in gconf 
    my $currentRows = $self->SUPER::rows();
    my %storedLogDomains;
    foreach my $row (@{$currentRows}) {
        $storedLogDomains{$row->{'valueHash'}->{'domain'}->value()} = 1;
    }

    # Fetch the current available log domains
    my %currentLogDomains;
    my $currentTables = $logs->getAllTables();
    foreach my $table (keys (%{$currentTables})) {
        $currentLogDomains{$table} = 1;
    }

    # Add new domains to gconf
    foreach my $domain (keys %currentLogDomains) {
        next if (exists $storedLogDomains{$domain});
        $self->addRow('domain' => $domain, 'enabled' => 0);
        $self->_createFilteringModel($domain);
    }

    # Remove non-existing domains from gconf
    foreach my $row (@{$currentRows}) {
        my $domain = $row->{'valueHash'}->{'domain'}->value();
        next if (exists $currentLogDomains{$domain});
        $self->removeRow($row->{'id'});
        $self->_removeFilteringModel($domain);
    }

    return $self->SUPER::rows($filter, $page);

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
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
                      help                => __(''),
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

    my $logDomain = $row->{domain};

    return '/events/' . FILTERING_MODEL_NAME . "/$logDomain";

}

# Group: Private methods

# Create a new filtering model given a
# log domain and notify this new model to model manager
sub _createFilteringModel # (domain)
{
    my ($self, $domain) = @_;

    my $domainTableInfo = $self->{logs}->getTableInfo($domain);

    my $filteringModel = new EBox::Events::Model::Watcher::LogFiltering(
                                                                        tableInfo => $domainTableInfo,
                                                                       );
    my $modelManager = EBox::Model::ModelManager->instance();

    $modelManager->addModel('/events/' . FILTERING_MODEL_NAME . "/$domain",
                            $filteringModel);

}

# Remove an existing filtering model given a
# log domain and notify this removal to model manager
sub _removeFilteringModel # (domain)
{
    my ($self, $domain) = @_;

    my $modelManager = EBox::Model::ModelManager->instance();

    $modelManager->removeModel('/events/' . FILTERING_MODEL_NAME . "/$domain");

}

1;
