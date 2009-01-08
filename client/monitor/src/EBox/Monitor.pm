# Copyright 2008 (C) eBox Technologies S.L.
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

# Class: EBox::Monitor
#
#   This module is intended to monitor several standard things among
#   others:
#
#      - cpu
#      - load
#      - processes
#      - swap
#      - memory usage
#      - disk usage
#

package EBox::Monitor;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::Model::ModelProvider
            EBox::ServiceModule::ServiceInterface);

use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

# Measures
use EBox::Monitor::Measure::Manager;

use Sys::Hostname;

# Constants
use constant COLLECTD_SERVICE    => 'ebox.collectd';
use constant COLLECTD_CONF_FILE  => '/etc/collectd/collectd.conf';
use constant THRESHOLD_CONF_FILE => '/etc/collectd/thresholds.conf';
use constant RRD_BASE_DIR        => EBox::Config::var() . 'lib/collectd/rrd/' . hostname() . '/';
use constant QUERY_INTERVAL      => 10;

# Method: _create
#
# Overrides:
#
#       <Ebox::Module::_create>
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'monitor',
                                      printableName => __('Monitor'),
                                      domain => 'ebox-monitor',
                                      @_);
    bless($self, $class);

    $self->_setupMeasures();
    return $self;
}

# Group: Public methods

# Method: domain
#
# Overrides:
#
#       <EBox::Module::domain>
#
sub domain
{
    return 'ebox-monitor';
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return
      [
          'EBox::Monitor::Model::MeasureWatchers',
          'EBox::Monitor::Model::ThresholdConfiguration',
         ];
}

# Method: actions
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::actions>
#
sub actions
{
    return [];
}


# Method: usedFiles
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    return [
        { file   => COLLECTD_CONF_FILE,
          module => 'monitor',
          reason => __('Collectd main configuration file'),
        },
        { file   => THRESHOLD_CONF_FILE,
          module => 'monitor',
          reason => __('Collectd threshold configuration file'),
        },
       ];
}

# Method: enableActions
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::enableActions>
#
sub enableActions
{
    EBox::Sudo::root(EBox::Config::share() . '/ebox-monitor/ebox-monitor-enable');
}

# Method: serviceModuleName
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::serviceModuleName>
#
sub serviceModuleName
{
    return 'monitor';
}

# Method: isRunning
#
# Overrides:
#
#       <EBox::ServiceModule::ServiceInterface::isRunning>
#
sub isRunning
{
    return EBox::Service::running(COLLECTD_SERVICE);
}

# Method: statusSummary
#
# Overrides:
#
#     <EBox::Module::statusSummary>
#
# Returns:
#
#   <EBox::Summary::Status> - the summary components
#
sub statusSummary
{
    my ($self) = @_;
    return new EBox::Summary::Status('monitor', 'Monitor',
                                     $self->isRunning(),
                                     $self->isEnabled());
}

# Method: menu
#
# Overrides:
#
#    <EBox::Module method>
#
sub menu
{
    my ($self, $root) = @_;
    my $item = new EBox::Menu::Item(
         'url' => 'Monitor/Index',
         'text' => __('Monitor'),
         'order' => 3);
    $root->add($item);
}

# Method: measuredData
#
#      Return the measured data for the desired measure and optionally
#      the desired instance of data
#
# Parameters:
#
#      measureName - String the measure name
#
#      instance - String the instance name *(Optional)* Default value: the
#      first described instance in the measure
#
# Returns:
#
#      hash ref - the data to be displayed in graphs which is
#      explained in <EBox::Monitor::Measure::Base::fetchData>
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given measure
#      name does not exist in the measure set
#
sub measuredData
{
    my ($self, $measureName, $instance) = @_;

    $measureName or throw EBox::Exceptions::MissingArgument('measureName');

    my $measure = $self->{measureManager}->measure($measureName);
    return $measure->fetchData(instance => $instance);

}

# Method: allMeasuredData
#
#      Return all the measured data to be displayed in graphs
#
# Returns:
#
#      array ref - each element contained data to be displayed in graphs
#      as it is described in <EBox::Monitor::Measure::Base::fetchData>
#
sub allMeasuredData
{
    my ($self) = @_;

    my @measuredData;
    foreach my $measure (@{$self->{measureManager}->measures()}) {
        if(@{$measure->instances()} > 0) {
            foreach my $instance (@{$measure->instances()}) {
                push(@measuredData,
                     $measure->fetchData(instance => $instance));
            }
        } else {
            push(@measuredData, $measure->fetchData());
        }
    }

    return \@measuredData;
}

# Method: measures
#
#      Return all the current registered measures to get measured data
#
# Returns:
#
#      array ref - each element contained an instance of a subclass of
#      <EBox::Monitor::Measure::Base>
#
sub measures
{
    my ($self) = @_;
    return $self->{measureManager}->measures();
}

# Method: thresholdConfigured
#
#      Return if a measure with a given data source is configured in
#      the threshold configuration
#
# Parameters:
#
#      measureName - String the measure name to search for a threshold
#      configuration
#
#      dataSource - String the data source name to filter the
#      threshold
#
# Returns:
#
#      true - if there is a configured threshold for this measure with
#      this data source
#
#      false - otherwise
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given measure
#      name does not exist in the measure set
#
sub thresholdConfigured
{
    my ($self, $measureName, $dataSource) = @_;

    $measureName or throw EBox::Exceptions::MissingArgument('measureName');
    $dataSource or throw EBox::Exceptions::MissingArgument('dataSource');

    my $measure = $self->{measureManager}->measure($measureName);
    my $measureWatchersMod = $self->model('MeasureWatchers');
    my $row = $measureWatchersMod->findValue(measure => $measure->name());
    if ( defined($row) ) {
        my $thresholds = $row->subModel('thresholds');
        my $threshold = $thresholds->findValue(dataSource => $dataSource);
        return defined($threshold);
    } else {
        throw EBox::Exceptions::DataNotFound(data  => 'measure name',
                                             value => $measure->name());
    }

}

# Group: Public static methods

# Method: RRDBaseDirPath
#
#      Return the RRD base directory path
#
# Returns:
#
#      String - the RRD base directory Path
#
sub RRDBaseDirPath
{
    return RRD_BASE_DIR;
}

# Method: QueryInterval
#
#      Return the collectd query interval to plugins
#
# Return:
#
#      Int - the query interval
#
sub QueryInterval
{
    return QUERY_INTERVAL;
}

# Group: Protected methods

# Method: _stopService
#
# Overrides:
#
#       <EBox::Module::_stopService>
#
sub _stopService
{
    EBox::Service::manage(COLLECTD_SERVICE, 'stop');
}

# Method: _regenConfig
#
#      It regenertates the monitor service configuration
#
# Overrides:
#
#      <EBox::Module::_regenConfig>
#
sub _regenConfig
{
    my ($self) = @_;

    $self->_setMonitorConf();
    $self->_doDaemon();

}

# Group: Private methods

# Method: _setMonitorConf
#
#    Set collectd configuration files
#
sub _setMonitorConf
{
    my ($self) = @_;

    # Order is important, don't swap procedure calls :D
    $self->_setThresholdConf();
    $self->_setMainConf();

}

# Method: _doDaemon
#
#    Set status for collectd daemon
#
sub _doDaemon
{
    my ($self) = @_;

    if ($self->isEnabled() and $self->isRunning()) {
        EBox::Service::manage(COLLECTD_SERVICE,'restart');
    } elsif ($self->isEnabled()) {
        EBox::Service::manage(COLLECTD_SERVICE,'start');
    } elsif (not $self->isEnabled() and $self->isRunning()) {
        EBox::Service::manage(COLLECTD_SERVICE,'stop');
    }

}

# Setup measures
sub _setupMeasures
{
    my ($self) = @_;

    $self->{measureManager} = EBox::Monitor::Measure::Manager->Instance();
    $self->{measureManager}->register('EBox::Monitor::Measure::Load');
    $self->{measureManager}->register('EBox::Monitor::Measure::CPU');
    $self->{measureManager}->register('EBox::Monitor::Measure::Df');
    $self->{measureManager}->register('EBox::Monitor::Measure::Memory');

}

# Write down the main configuration file
sub _setMainConf
{
    my ($self) = @_;

    $self->writeConfFile(COLLECTD_CONF_FILE,
                         'monitor/collectd.conf.mas',
                         [
                          (interval       => $self->QueryInterval()),
                          (loadPerlPlugin => $self->_thresholdConfigured()),
                         ]
                        );
}

# Write down the threshold configuration file
sub _setThresholdConf
{
    my ($self) = @_;

    my $measureWatchersModel = $self->model('MeasureWatchers');
    my @thresholds = ();

    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('events') ) {
        my $evtsMod = $gl->modInstance('events');
        if ( $evtsMod->isEnabled() and $evtsMod->isEnabledWatcher('EBox::Event::Watcher::Monitor')->value() ) {
            foreach my $measureWatcher (@{$measureWatchersModel->rows()}) {
                my $confModel = $measureWatcher->subModel('thresholds');
                my $measureInstance = $self->{measureManager}->measure($measureWatcher->valueByName('measure'));
                foreach my $confRow (@{$confModel->findAll(enabled => 1)}) {
                    my %threshold = ( measure  => $measureInstance->simpleName(),
                                      type     => $measureInstance->simpleName(),
                                      invert   => $confRow->valueByName('invert'),
                                      persist  => $confRow->valueByName('persist'),
                                     );
                    if ( $confRow->valueByName('measureInstance') ne 'none' ) {
                        $threshold{instance} = $confRow->valueByName('measureInstance');
                    }
                    if ( $confRow->valueByName('typeInstance') ne 'none' ) {
                        $threshold{typeInstance} = $confRow->valueByName('typeInstance');
                    }
                    foreach my $bound (qw(warningMin failureMin warningMax failureMax)) {
                        my $boundValue = $confRow->valueByName($bound);
                        if (defined($boundValue)) {
                            $threshold{$bound} = $boundValue;
                        }
                    }
                    push(@thresholds, \%threshold);
                }
            }
        } else {
            EBox::warn('No threshold configuration is saved since monitor watcher '
                       . 'or events module are not enabled');
        }
    }
    if (@thresholds > 0) {
        $self->{thresholdConfigured} = 1;
    }

    $self->writeConfFile(THRESHOLD_CONF_FILE,
                         'monitor/thresholds.conf.mas',
                         [
                             (thresholds => \@thresholds),
                            ]
                        );

}

# Check if there is threshold configuration and it is enabled or not
# Done by <_setThresholdConf> as a side effect
sub _thresholdConfigured
{
    my ($self) = @_;

    if( defined($self->{thresholdConfigured}) ) {
        return $self->{thresholdConfigured};
    } else {
        return 0;
    }

}

1;
