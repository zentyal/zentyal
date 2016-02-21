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
#   EBox::Logs::Model::ConfigureLogs
#
#   This class is used as a model to describe a table which will be
#   used to select the logs domains the user wants to enable/disable.
#
#   It subclasses <EBox::Model::DataTable>
#
#
#

package EBox::Logs::Model::ConfigureLogs;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Model::Manager;
use EBox::Validate qw(:all);
use EBox::Types::Boolean;
use EBox::Types::Int;
use EBox::Types::IPAddr;
use EBox::Types::Link;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Sudo;
use EBox::Exceptions::External;

# Core modules
use TryCatch;
use List::Util;

# Group: Public methods

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: enabledLogs
#
#   Return those log domains which must be logged.
#
# Returns:
#
#   Hashref containing the enabled logs.
#
#   Example:
#
#       { 'squid' =>  1, 'dhcp' => 1 }
#
#
sub enabledLogs
{
    my ($self) = @_;

    my %enabledLogs;
    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        next unless ($row->valueByName('enabled'));
        $enabledLogs{$row->valueByName('domain')}  = 1;
    }
    return \%enabledLogs;
}

# Method: syncRows
#
#       Override <EBox::Model::DataTable::syncRows>
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
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $changed = undef;
    # Fetch the current log domains stored in conf
    my %storedLogDomains;
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $domain = $row->valueByName('domain');
        if (not $domain) {
            EBox::warn("ConfigureLogs row $id has not domain element");
            next;
        }
        $storedLogDomains{$domain} = 1;
    }

    # Fetch the current available log domains
    my %currentLogDomains;
    my $logs = EBox::Global->modInstance('logs');
    foreach my $mod (@{ $logs->getLogsModules()}  ) {
      $currentLogDomains{$mod->name} = $mod;
    }

    # Add new domains to conf
    foreach my $domain (keys %currentLogDomains) {
        next if (exists $storedLogDomains{$domain});

        my @tableInfos;
        my $mod = $currentLogDomains{$domain};
        my $ti = $mod->tableInfo();

        if (ref $ti eq 'HASH') {
            EBox::warn('tableInfo() in ' . $mod->name .
             'must return a reference to a list of hashes not the hash itself');
            @tableInfos = ( $ti );
        }
        else {
            @tableInfos = @{ $ti };
        }

        my $enabled = not grep {
          $_->{'disabledByDefault'}
        } @tableInfos;

        $self->addRow(domain => $domain,
                      enabled => $enabled,
                      lifeTime => 168);
        $changed = 1;
    }

    # Remove non-existing domains from conf
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $domain = $row->valueByName('domain');
        next if (exists $currentLogDomains{$domain});
        $self->removeRow($row->id());
        $changed = 1;
    }

    return $changed;
}

# Method: validateTypedRow
#
#   Override <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (exists $params_r->{enabled} or exists $params_r->{enabled}) {
        my $enabled = exists $params_r->{enabled} ?
                             $params_r->{enabled}->value() :
                             $actual_r->{enabled}->value();
        my $domain = exists $params_r->{domain} ?
                            $params_r->{domain}->value() :
                            $actual_r->{domain}->value();

        if (not $enabled) {
            my $logs = EBox::Global->modInstance('logs');
            foreach my $mod (@{$logs->getLogsModules()}) {
                if ($mod->name eq $domain) {
                    my @tableInfos = @{ $mod->tableInfo() };

                    my $force = grep { $_->{'forceEnabled'} } @tableInfos;

                    throw EBox::Exceptions::External(
                        __x('This log is forced by its module. You can only disable it by disabling {module} module', module => $mod->printableName)
                    ) if ($force);

                    return;
                }
            }
        }
    }
}

sub addedRowNotify
{
    my ($self, $row) = @_;
    $self->_enableLogForRow($row);
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;
    $self->_enableLogForRow($row);
}

sub _enableLogForRow
{
    my ($self, $row) = @_;
    my $domain = $row->valueByName('domain');
    my $enabled = $row->valueByName('enabled');

    my $logs = EBox::Global->modInstance('logs');
    my $tables = $logs->getAllTables();
    my $index = List::Util::first { $tables->{$_}->{helper}->name() eq $domain }
        keys %{ $tables };

    if ($index) {
        $tables->{$index}->{helper}->enableLog($enabled);
    } else {
        EBox::warn("Domain: $domain does not exist in logs");
    }
}

# Group: Callback functions

# Function: filterDomain
#
#   This is a callback used to filter the output of the field domain.
#   It basically translates the log domain
#
# Parameters:
#
#   instancedType-  an object derivated of <EBox::Types::Abastract>
#
# Return:
#
#   string - translation
sub filterDomain
{
    my ($instancedType) = @_;
    my $global = EBox::Global->getInstance(); # XXX always RW it should be inocuous
    my $logs = $global->modInstance('logs');

    my $translation;
    my $moduleName = $instancedType->value();
    my $mod = $global->modInstance($moduleName);
    if ($mod) {
        my @tableNames = map { $_->{name} } @{ $logs->getModTableInfos($mod) };
        $translation = join __(', '), @tableNames;
    }

    if ($translation) {
        return $translation;
    } else {
        return $moduleName;
    }
}

sub _populateSelectLifeTime
{
    # life time values must be in hours
    return  [
                {
                    printableValue => __('never purge'),
                    value          =>  0,
                },
                {
                    printableValue => __('one hour'),
                    value          => 1,
                },
                {
                    printableValue => __('twelve hours'),
                    value          => 12,
                },
                {
                    printableValue => __('one day'),
                    value          => 24,
                },
                {
                    printableValue => __('three days'),
                    value          => 72,
                },
                {
                    printableValue => __('one week'),
                    value          =>  168,
                },
                {
                    printableValue => __('fifteeen days'),
                    value          =>  360,
                },
                {
                    printableValue => __('thirty days'),
                    value          =>  720,
                },
                {
                    printableValue => __('ninety days'),
                    value          =>  2160,
                },
                {
                    printableValue => __('one year'),
                    value          =>  8760,
                },
                {
                    printableValue => __('two years'),
                    value          =>  17520,
                },
           ];
}

# Group: Protected methods

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# This table is composed of four fields:
#
#   domain (<EBox::Types::Text>)
#   enabled (<EBox::Types::Boolean>)
#   lifeTime (<EBox::Types::Select>)
#   eventConf (<EBox::Types::Link>)
#
# The only avaiable action is edit and only makes sense for 'enabled'
# and lifeTime.
#
sub _table
{
    my @tableHead =
        (
         new EBox::Types::Text(
                    'fieldName' => 'domain',
                    'printableName' => __('Domain'),
                    'size' => '12',
                    'unique' => 1,
                    'editable' => 0,
                    'filter' => \&filterDomain
                              ),
         new EBox::Types::Boolean(
                    'fieldName' => 'enabled',
                    'printableName' => __('Enabled'),
                    'unique' => 0,
                    'trailingText' => '',
                    'editable' => 1,
                                 ),
         new EBox::Types::Select(
                 'fieldName'     => 'lifeTime',
                 'printableName' => __('Purge logs older than'),
                 'populate'      => \&_populateSelectLifeTime,
                 'editable'      => 1,
                 'defaultValue'  => 168, # one week
                                ),
        );

    my $dataTable =
        {
            'tableName' => 'ConfigureLogs',
            'printableTableName' => __('Current configuration'),
            'defaultController' => '/Logs/Controller/ConfigureLogs',
            'defaultActions' => [ 'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'order' => 0,
            'help' => __x('Enable/disable logging per-module basis'),
            'rowUnique' => 0,
            'printableRowName' => __('logs'),
        };

    return $dataTable;
}

1;
