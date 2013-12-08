# Copyright (C) 2009-2012 Zentyal S.L.
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

# Class: EBox::IDS
#
#      Class description
#

package EBox::IDS;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::LogObserver
           );

use Error qw(:try);

use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;
use EBox::Exceptions::Sudo::Command;
use EBox::IDSLogHelper;
use List::Util;

use constant SNORT_CONF_FILE => "/etc/snort/snort.conf";
use constant SNORT_DEBIAN_CONF_FILE => "/etc/snort/snort.debian.conf";
use constant SNORT_RULES_DIR => '/etc/snort/rules';

# Group: Protected methods

# Constructor: _create
#
#        Create an module
#
# Overrides:
#
#        <EBox::Module::Service::_create>
#
# Returns:
#
#        <EBox::IDS> - the recently created module
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ids',
                                      printableName => 'IDS',
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
            {
             'name' => 'snort',
             'type' => 'init.d',
             'precondition' => \&_snortNeeded
            }
           ];
}

# Method: _snortNeeded
#
#     Returns true if there are interfaces to listen, false otherwise.
#
sub _snortNeeded
{
    my ($self) = @_;

    my @validIfaces = @{$self->_validIfaces()};

    return (scalar(@validIfaces) > 0);
}

# Method: _validIfaces
#
#   Returns array reference with the enabled interfaces that
#   are not unset or trunk.
#
sub _validIfaces
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');
    my $ifacesModel = $self->model('Interfaces');
    my @ifaces;
    foreach my $row (@{$ifacesModel->enabledRows()}) {
        my $iface = $ifacesModel->row($row)->valueByName('iface');
        my $method = $net->ifaceMethod($iface);
        next if ($method eq 'notset' or $method eq 'trunk');
        push (@ifaces, $iface);
    }

    return \@ifaces;
}

# Method: _preSetConf
#
#       Stops snort before writing the configuration
#       (necessary to avoid problems when interfaces have changed)
#
sub _preSetConf
{
    my ($self) = @_;

    $self->_stopService();
}

# Method: _setConf
#
#        Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $rulesModel = $self->model('Rules');
    my @rules = map ($rulesModel->row($_)->valueByName('name'),
                   @{$rulesModel->enabledRows()});

    if ( $self->usingASU() ) {
        @rules = map { "emerging-$_" } @rules;
    }

    $self->writeConfFile(SNORT_CONF_FILE, 'ids/snort.conf.mas',
                         [ rules => \@rules ]);

    $self->writeConfFile(SNORT_DEBIAN_CONF_FILE, 'ids/snort.debian.conf.mas',
                         [ ifaces => $self->_validIfaces() ]);
}

# Group: Public methods

# Method: menu
#
#       Add an entry to the menu with this module
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'IDS/Composite/General',
                                    'text' => __('IDS'),
                                    'separator' => 'UTM',
                                    'order' => 320));
}

# Method: modelClasses
#
#       Return the model classes used by the module.
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
            'EBox::IDS::Model::Interfaces',
            'EBox::IDS::Model::Rules',

            'EBox::IDS::Model::Report::AlertDetails',
            'EBox::IDS::Model::Report::AlertGraph',
            'EBox::IDS::Model::Report::AlertReportOptions',
           ];
}

# Method: compositeClasses
#
#       Return the composite classes used by the module
#
# Overrides:
#
#       <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
            'EBox::IDS::Composite::General',
            'EBox::IDS::Composite::Report::AlertReport',
           ];
}

# Method: usedFiles
#
#        Indicate which files are required to overwrite to configure
#        the module to work. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    return [
        {
            'file' => SNORT_CONF_FILE,
            'module' => 'ids',
            'reason' => 'Add rules to snort configuration'
        },
        {
            'file' => SNORT_DEBIAN_CONF_FILE,
            'module' => 'ids',
            'reason' => 'Add interfaces to snort configuration'
        }
    ];
}

# Method: actions
#
#        Explain the actions the module must make to configure the
#        system. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::actions>
sub actions
{
    return [];
}

# Method: enableActions
#
#        Run those actions explain by <actions> to enable the module
#
# Overrides:
#
#        <EBox::Module::Service::enableActions>
#
sub enableActions
{

}

# Method: disableActions
#
#        Rollback those actions performed by <enableActions> to
#        disable the module
#
# Overrides:
#
#        <EBox::Module::Service::disableActions>
#
sub disableActions
{

}

# Method: logHelper
#
# Overrides:
#
#       <EBox::LogObserver::logHelper>
#
sub logHelper
{
    my ($self) = @_;

    return (new EBox::IDSLogHelper);
}

# Method: tableInfo
#
# Overrides:
#
#       <EBox::LogObserver::tableInfo>
#
sub tableInfo
{
    my ($self) = @_ ;

    my $titles = {
                  'timestamp'   => __('Date'),
                  'priority'    => __('Priority'),
                  'description' => __('Description'),
                  'source'      => __('Source'),
                  'dest'        => __('Destination'),
                  'protocol'    => __('Protocol'),
                  'event'       => __('Event'),
                 };

    my @order = qw(timestamp priority description source dest protocol event);

    return [{
            'name' => __('IDS'),
            'index' => 'ids',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'ids_event',
            'timecol' => 'timestamp',
            'events' => { 'alert' => __('Alert') },
            'eventcol' => 'event',
            'filter' => ['priority', 'description', 'source', 'dest'],
            'consolidate' => $self->_consolidate(),
           }];
}

sub _consolidate
{
    my ($self) = @_;

    my $table = 'ids_alert';

    my $spec = {
        accummulateColumns  => { alert => 0 },
        consolidateColumns => {
                                event => {
                                          conversor => sub { return 1; },
                                          accummulate => 'alert',
                                         },
                              },
    };

    return { $table => $spec };
}

sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report = {};

    $report->{'alerts'} = $self->runMonthlyQuery($beg, $end, {
        'select' => 'SUM(priority1) AS priority1, ' .
                    'SUM(priority2) AS priority2, ' .
                    'SUM(priority3) AS priority3, ' .
                    'SUM(priority4) AS priority4, ' .
                    'SUM(priority5) AS priority5',
        'from' => 'ids_report',
    }, { 'name' => 'alerts'});

    $report->{'top_alert_sources'} = $self->runQuery($beg, $end, {
        'select' => 'source, '.
                    'SUM(priority1) AS priority1, ' .
                    'SUM(priority2) AS priority2, ' .
                    'SUM(priority3) AS priority3, ' .
                    'SUM(priority4) AS priority4, ' .
                    'SUM(priority5) AS priority5',
        'from' => 'ids_report',
        'group' => 'source',
        'limit' => $options->{'max_top_alert_sources'},
        'order' => 'priority1,priority2,priority3,priority4,priority5 DESC'
    });
    return $report;
}

sub consolidateReportQueries
{
    return [
        {
            'target_table' => 'ids_report',
            'query' => {
                'select' => "split_part(source, ':', 1) AS source," .
     ' COUNT(CASE WHEN priority=1 THEN 1 ELSE NULL END  ) AS priority1, ' .
     ' COUNT(CASE WHEN priority=2 THEN 1 ELSE NULL END  ) AS priority2, ' .
     ' COUNT(CASE WHEN priority=3 THEN 1 ELSE NULL END  ) AS priority3, ' .
     ' COUNT(CASE WHEN priority=4 THEN 1 ELSE NULL END  ) AS priority4, ' .
     ' COUNT(CASE WHEN priority=5 THEN 1 ELSE NULL END  ) AS priority5 ',
                'from' => 'ids_event',
                'group' => "source"
            }
        }
    ];
}

# Method: usingASU
#
#    Get if the module is using ASU or not.
#
#    If a parameter is given, then it sets the value
#
# Parameters:
#
#    usingASU - Boolean Set if we are using ASU or not
#
# Returns:
#
#    Boolean - indicating whether we are using ASU or not
#
sub usingASU
{
    my ($self, $usingASU) = @_;

    my $key = 'using_asu';
    if (defined($usingASU)) {
        $self->st_set_bool($key, $usingASU);
    } else {
        if ( $self->st_entry_exists($key) ) {
            $usingASU = $self->st_get_bool($key);
        } else {
            # For now, checking emerging is in rules
            my $rulesDir = SNORT_RULES_DIR . '/';
            my @rules = <${rulesDir}emerging-*.rules>;
            $usingASU = (scalar(@rules) > 0);
        }
    }
    return $usingASU;
}

# Method: rulesNum
#
#     Get the number of available IDS rules
#
# Parameters:
#
#     force - Boolean indicating we are forcing to calculate again
#
# Returns:
#
#     Int - the number of available IDS rules
#
sub rulesNum
{
    my ($self, $force) = @_;

    my $key = 'rules_num';
    $force = 0 unless defined($force);

    my $rulesNum;
    if ( $force or (not $self->st_entry_exists($key)) ) {
        my @files;
        my $rulesDir = SNORT_RULES_DIR . '/';
        if ( $self->usingASU() ) {
            @files = <${rulesDir}emerging-*.rules>;
        } else {
            @files = <${rulesDir}*.rules>;
        }
        # Count the number of rules removing blank lines and comment lines
        my @numRules = map { `sed -e '/^#/d' -e '/^\$/d' $_ | wc -l` } @files;
        $rulesNum = List::Util::sum(@numRules);
        $self->st_set_int($key, $rulesNum);
    } else {
        $rulesNum = $self->st_get_int($key);
    }
    return $rulesNum;
}

# Group: Private methods

1;
