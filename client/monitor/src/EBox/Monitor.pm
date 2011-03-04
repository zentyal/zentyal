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
use Sys::Hostname;
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
use File::Spec;
use File::Slurp;

# Constants
use constant COLLECTD_INIT        => 'collectd';
use constant COLLECTD_UPSTART     => 'ebox.collectd';
use constant COLLECTD_CONF_FILE   => '/etc/collectd/collectd.conf';
use constant THRESHOLDS_CONF_FILE => '/etc/collectd/thresholds.conf';
use constant SERVICE_STOPPED_FILE => EBox::Config::tmp() . 'monitor_stopped';
use constant DEFAULT_COLLECTD_FILE => '/etc/default/collectd';
use constant RUNTIME_MEASURES     => EBox::Config::conf() . 'monitor/plugins';

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
                                      printableName => __n('Monitor'),
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
          reason => __x('{daemon} main configuration file',
                        daemon => 'collectd'),
        },
        { file   => THRESHOLDS_CONF_FILE,
          module => 'monitor',
          reason => __x('{daemon} thresholds configuration file',
                       daemon => 'collectd'),
        },
        { file   => DEFAULT_COLLECTD_FILE,
          module => 'monitor',
          reason => __x('{daemon} default configuration file',
                       daemon => 'collectd'),
        },
       ];
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
         'separator' => 'Core',
         'order' => 70);
    $root->add($item);
}

# Method: depends
#
#      Monitor depends on Remote Services configuration only if the
#      module exists
#
# Overrides:
#
#      <EBox::Module::Base::depends>
#
sub depends
{
    my ($self) = @_;

    my $dependsList = $self->SUPER::depends();
    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('remoteservices') ) {
        push(@{$dependsList}, 'remoteservices');
    }

    return $dependsList;
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
    my $atLeastOneReady;
    foreach my $measure (@{$self->{measureManager}->measures()}) {
        try  {
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
            $atLeastOneReady = 1;
        } otherwise {
            my $ex = shift;
            my $error = join ' ', @{ $ex->error() };
            if ($error =~ m/No such file or directory/) {
                # need to save changes, ignoring..
            } else {
                # rethrow exception
                $ex->throw();
            }
        };
    }

    if (not $atLeastOneReady) {
        # none measure is ready, need to save changes
        throw EBox::Exceptions::Internal('Need to save changes to see measures');
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

# Method: stoppedServiceFilePath
#
#     Path to the file to indicate the monitor service was stopped on
#     purpose. The action is done by creating the file
#
# Returns:
#
#     String - the path to the file
#
sub stoppedServiceFilePath
{
    return SERVICE_STOPPED_FILE;
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
            name         => COLLECTD_UPSTART,
            type         => 'upstart',
            precondition => \&_notStoppedOnPurpose,
        },
    ];
}

# Group: Private methods

# Method: _setDirs
#
#    Create and set the directories required to communicate Zentyal event
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
        $self->writeConfFile(DEFAULT_COLLECTD_FILE, 'monitor/collectd.default.mas', []);
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
        $self->_registerRuntimeMeasures();
    } catch EBox::Exceptions::Internal with {
        # Catch exceptions since it is possible that the monitor
        # module has never been configured (enable once)
    };
}

# Write down the main configuration file
sub _setMainConf
{
    my ($self) = @_;

    my $hostname       = hostname();
    my @networkServers = ();

    # Send stats to Zentyal Cloud with the server name if the host is subscribed
    my $global = EBox::Global->getInstance(1);
    if ( $global->modExists('remoteservices') ) {
        my $rs = $global->modInstance('remoteservices');
        if ( $rs->eBoxSubscribed() ) {
            $hostname = $rs->subscribedHostname();
            @networkServers = @{$rs->monitorGathererIPAddresses()};
            $self->_linkRRDs($hostname);
        } else {
            $self->_linkRRDs();
        }
    }

    $self->writeConfFile(COLLECTD_CONF_FILE,
                         'monitor/collectd.conf.mas',
                         [
                          (interval       => EBox::Monitor::Configuration->QueryInterval()),
                          (mountPoints    => $self->_mountPointsToMonitor()),
                          (hostname       => $hostname),
                          (networkServers => \@networkServers),
                          (loadPerlPlugin => $self->_thresholdConfigured()),
                         ]
                        );
}

# Write down the threshold configuration file
sub _setThresholdConf
{
    my ($self) = @_;

    my $measureWatchersModel = $self->model('MeasureWatchers');
    my %thresholds = ();

    my $gl = EBox::Global->getInstance(1);
    if ( $gl->modExists('events') ) {
        my $evtsMod = $gl->modInstance('events');
        if ( $evtsMod->isEnabled() and $evtsMod->isEnabledWatcher('EBox::Event::Watcher::Monitor')->value() ) {
            foreach my $id (@{$measureWatchersModel->ids()}) {
                my $measureWatcher = $measureWatchersModel->row($id);
                my $confModel = $measureWatcher->subModel('thresholds');
                try {
                    my $measureInstance = $self->{measureManager}->measure($measureWatcher->valueByName('measure'));
                    foreach my $confRow (@{$confModel->findDumpThresholds()}) {
                        my %threshold = ( measure => $measureInstance->plugin(),
                                          type    => $measureInstance->plugin(),
                                          invert  => $confRow->valueByName('invert'),
                                          persist => $confRow->valueByName('persist'),
                                         );
                        if ( $confRow->valueByName('measureInstance') ne 'none' ) {
                            $threshold{instance} = $confRow->valueByName('measureInstance');
                        }
                        if ( $confRow->valueByName('typeInstance') ne 'none' ) {
                            $threshold{typeInstance} = $confRow->valueByName('typeInstance');
                        }
                        if ( $confRow->valueByName('dataSource') ne 'none' ) {
                            $threshold{dataSource} = $confRow->valueByName('dataSource');
                        }
                        foreach my $bound (qw(warningMin failureMin warningMax failureMax)) {
                            my $boundValue = $confRow->valueByName($bound);
                            if (defined($boundValue)) {
                                $threshold{$bound} = $boundValue;
                            }
                        }
                        my $key = $measureInstance->plugin();
                        if ( exists($threshold{instance}) ) {
                            $key .= '-' . $threshold{instance};
                        }
                        unless (exists ( $thresholds{$key} )) {
                            $thresholds{$key} = [];
                        }
                        push(@{$thresholds{$key}}, \%threshold);
                    }
                } catch EBox::Exceptions::DataNotFound with {
                    # The measure has disappear in some moment, we ignore their thresholds them
                    my ($exc) = @_;
                    EBox::warn($exc);
                };
            }
        } else {
            EBox::warn('No threshold configuration is saved since monitor watcher '
                       . 'or events module are not enabled');
        }
    }
    if (keys(%thresholds) > 0) {
        $self->{thresholdConfigured} = 1;
    }

    $self->writeConfFile(THRESHOLDS_CONF_FILE,
                         'monitor/thresholds.conf.mas',
                         [
                             (thresholds => \%thresholds),
                            ]
                        );

}

# Link to RRDs subscribed hostname to the real one created if Zentyal is
# subscribed to the Cloud in order to preserve the monitoring data prior to
# subscribe
sub _linkRRDs
{
    my ($self, $subscribedHostname) = @_;

    my $rrdBaseDirPath = EBox::Monitor::Configuration::RRDBaseDirPath();

    # Get the parent path
    my @directories = File::Spec->splitdir($rrdBaseDirPath);
    pop(@directories);
    pop(@directories);
    my $parentPath = File::Spec->catdir(@directories);

    if ( $subscribedHostname ) {
        my $subDirPath = "$parentPath/$subscribedHostname";
        unless ( -e $subDirPath ) {
            EBox::Sudo::root("ln -s $rrdBaseDirPath $subDirPath");
        }
    } else {
        opendir(my $dh, $parentPath);
        while ( defined(my $subdir = readdir($dh)) ) {
            if ( -l "$parentPath/$subdir" ) {
                EBox::Sudo::root("rm $parentPath/$subdir");
            }
        }
        closedir($dh);
    }

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

# Return those mount points which are good to monitor
# That is, the ones which have a device
sub _mountPointsToMonitor
{
    my ($self) = @_;

    my $dfMeasure = $self->{measureManager}->measure('Df');
    my @printableTypeInstances = map { $dfMeasure->printableTypeInstance($_) } @{$dfMeasure->typeInstances()};
    return \@printableTypeInstances;
}

# Check if the monitor service has been stopped on purpose in order
# not to check if the service must be running
sub _notStoppedOnPurpose
{
    # Check if someone has written the file in the Zentyal tmp dir
    return not (-e SERVICE_STOPPED_FILE);
}

# Load and register those measures that are installed in special directory
sub _registerRuntimeMeasures
{
    my ($self) = @_;

    if ( -r RUNTIME_MEASURES ) {
        my @lines = File::Slurp::read_file(RUNTIME_MEASURES);
        foreach my $line (@lines) {
            chomp($line);
            $line =~ s/\s//g;
            try {
                $self->{measureManager}->register($line);
            } otherwise {
                # Cannot load the runtime measure
            };
        }
    }
}


1;
