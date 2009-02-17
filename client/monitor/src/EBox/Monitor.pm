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

use base qw(EBox::Module::Service EBox::Model::ModelProvider);

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Service;
use EBox::Sudo;
use EBox::Validate qw( :all );

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

use EBox::Monitor::Configuration;
# Measures
use EBox::Monitor::Measure::Manager;

# Core modules
use Error qw(:try);

# Constants
use constant COLLECTD_SERVICE    => 'ebox.collectd';
use constant COLLECTD_CONF_FILE  => '/etc/collectd/collectd.conf';
use constant THRESHOLD_CONF_FILE => '/etc/collectd/thresholds.conf';

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
#       <EBox::Module::Service::actions>
#
sub actions
{
    return [];
}


# Method: usedFiles
#
# Overrides:
#
#       <EBox::Module::Service::usedFiles>
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
#       <EBox::Module::Service::enableActions>
#
sub enableActions
{
    EBox::Sudo::root(EBox::Config::share() . '/ebox-monitor/ebox-monitor-enable');
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
#      period - String the period's time
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
#      <EBox::Exceptions::InvalidData> - thrown if the given period is
#      not one of the defined ones
#
sub measuredData
{
    my ($self, $measureName, $period, $instance) = @_;

    $measureName or throw EBox::Exceptions::MissingArgument('measureName');
    my ($periodData) = grep { $_->{name} eq $period } @{EBox::Monitor::Configuration::TimePeriods()};
    unless(defined($periodData)) {
        throw EBox::Exceptions::InvalidData(
            data   => 'period',
            value  => $period,
            advice => 'It must be one of the following: '
                      . join(', ', map { $_->{name} } @{EBox::Monitor::Configuration::TimePeriods()}));
    }

    my $measure = $self->{measureManager}->measure($measureName);
    return $measure->fetchData(instance   => $instance,
                               resolution => $periodData->{resolution},
                               start      => 'end-' . $periodData->{timeValue});

}

# Method: allMeasuredData
#
#      Return all the measured data to be displayed in graphs
#
# Parameters:
#
#      period - String the period to return data.  It must be one of
#               the returned by
#               <EBox::Monitor::Configuration::TimePeriods> as keys
#               *(Optional)* Default value: 'lastHour'
#
# Returns:
#
#      array ref - each element contained data to be displayed in graphs
#      as it is described in <EBox::Monitor::Measure::Base::fetchData>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the given period is
#      not one of the selectable ones
#
sub allMeasuredData
{
    my ($self, $period) = @_;

    unless(defined($period)) {
        $period = 'lastHour';
    }
    my $timePeriods = EBox::Monitor::Configuration->TimePeriods();
    my ($periodData) = grep { $period eq $_->{name} } @{$timePeriods};
    unless(defined($periodData)) {
        throw EBox::Exceptions::InvalidData(data   => 'period',
                                            value  => $period,
                                            advice => 'It must be one of the following: '
                                              . join(', ', map { $_->{name} }@{$timePeriods}));
    }

    my @measuredData;
    foreach my $measure (@{$self->{measureManager}->measures()}) {
        if(@{$measure->instances()} > 0) {
            foreach my $instance (@{$measure->instances()}) {
                push(@measuredData,
                     $measure->fetchData(instance   => $instance,
                                         resolution => $periodData->{resolution},
                                         start      => 'end-' . $periodData->{timeValue}));
            }
        } else {
            push(@measuredData,
                 $measure->fetchData(resolution => $periodData->{resolution},
                                     start      => 'end-' . $periodData->{timeValue}));
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

# Method: measure
#
#      Return the instance of a measure
#
# Parameters:
#
#      name - String the measure's name (class or simple name)
#
# Returns:
#
#      an instance of a subclass of <EBox::Monitor::Measure::Base>
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given measure
#      name does not exist in the measure set
#
sub measure
{
    my ($self, $name) = @_;

    $name or throw EBox::Exceptions::MissingArgument('name');

    return $self->{measureManager}->measure($name);

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

# Group: Protected methods

# Method: _setConf
#
#      It regenerates the monitor service configuration
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->_setDirs();
    $self->_setMonitorConf();

}

# Method: _daemons
#
#      Services manages by monitor module
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            name => COLLECTD_SERVICE,
        },
    ];
}

# Group: Private methods

# Method: _setDirs
#
#    Create and set the directories required to communicate eBox event
#    daemon and monitor modules
#
sub _setDirs
{
    unless (-d EBox::Monitor::Configuration::EventsReadyDir() ) {
        EBox::Sudo::root('mkdir -p ' . EBox::Monitor::Configuration::EventsReadyDir());
    }
    my $eBoxUser = EBox::Config::user();
    EBox::Sudo::root("chown -R $eBoxUser.$eBoxUser " . EBox::Monitor::Configuration::MainVarRun());

}

# Method: _setMonitorConf
#
#    Set collectd configuration files
#
sub _setMonitorConf
{
    my ($self) = @_;

    if ( $self->isEnabled() ) {
        # Order is important, don't swap procedure calls :D
        $self->_setThresholdConf();
        $self->_setMainConf();
    }

}

# Setup measures
sub _setupMeasures
{
    my ($self) = @_;

    try {
        $self->{measureManager} = EBox::Monitor::Measure::Manager->Instance();
        $self->{measureManager}->register('EBox::Monitor::Measure::Load');
        $self->{measureManager}->register('EBox::Monitor::Measure::CPU');
        $self->{measureManager}->register('EBox::Monitor::Measure::Df');
        $self->{measureManager}->register('EBox::Monitor::Measure::Memory');
        $self->{measureManager}->register('EBox::Monitor::Measure::Thermal');
    } catch EBox::Exceptions::Internal with {
        # Catch exceptions since it is possible that the monitor
        # module has never been configured (enable once)
    };

}

# Write down the main configuration file
sub _setMainConf
{
    my ($self) = @_;

    $self->writeConfFile(COLLECTD_CONF_FILE,
                         'monitor/collectd.conf.mas',
                         [
                          (interval       => EBox::Monitor::Configuration->QueryInterval()),
                          (loadPerlPlugin => 1),# $self->_thresholdConfigured()),
                         ]
                        );
}

# Write down the threshold configuration file
sub _setThresholdConf
{
    my ($self) = @_;

    my $measureWatchersModel = $self->model('MeasureWatchers');
    my %thresholds = ();

    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('events') ) {
        my $evtsMod = $gl->modInstance('events');
        if ( $evtsMod->isEnabled() and $evtsMod->isEnabledWatcher('EBox::Event::Watcher::Monitor')->value() ) {
            foreach my $id (@{$measureWatchersModel->ids()}) {
                my $measureWatcher = $measureWatchersModel->row($id);
                my $confModel = $measureWatcher->subModel('thresholds');
                my $measureInstance = $self->{measureManager}->measure($measureWatcher->valueByName('measure'));
                foreach my $confRow (@{$confModel->findDumpThresholds()}) {
                    my %threshold = ( measure => $measureInstance->simpleName(),
                                      type    => $measureInstance->simpleName(),
                                      invert  => $confRow->valueByName('invert'),
                                      persist => $confRow->valueByName('persist'),
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
                    my $key = $measureInstance->simpleName();
                    if ( exists($threshold{instance}) ) {
                        $key .= '-' . $threshold{instance};
                    }
                    unless (exists ( $thresholds{key} )) {
                        $thresholds{$key} = [];
                    }
                    push(@{$thresholds{$key}}, \%threshold);
                }
            }
        } else {
            EBox::warn('No threshold configuration is saved since monitor watcher '
                       . 'or events module are not enabled');
        }
    }
    if (keys(%thresholds) > 0) {
        $self->{thresholdConfigured} = 1;
    }

    $self->writeConfFile(THRESHOLD_CONF_FILE,
                         'monitor/thresholds.conf.mas',
                         [
                             (thresholds => \%thresholds),
                            ]
                        );

}

# Check if there is threshold configuration and it is enabled or not
# Done by <_setThresholdConf> as a side effect
# FIXME: Until collectd 4.5.2 this code will not be used
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
