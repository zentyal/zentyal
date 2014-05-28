# Copyright (C) 2008-2014 Zentyal S.L.
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

use base qw(EBox::Module::Service EBox::Events::WatcherProvider EBox::SysInfo::Observer);

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
use EBox::Exceptions::Internal;

use EBox::Monitor::Configuration;
# Measures
use EBox::Monitor::Measure::Manager;

# Core modules
use TryCatch::Lite;
use File::Spec;
use File::Slurp;
use JSON;

# Constants
use constant COLLECTD_INIT        => 'collectd';
use constant COLLECTD_UPSTART     => 'ebox.collectd';
use constant COLLECTD_CONF_FILE   => '/etc/collectd/collectd.conf';
use constant THRESHOLDS_CONF_FILE => '/etc/collectd/thresholds.conf';
use constant SERVICE_STOPPED_FILE => EBox::Config::tmp() . 'monitor_stopped';
use constant DEFAULT_COLLECTD_FILE => '/etc/default/collectd';
use constant RUNTIME_MEASURES     => EBox::Config::conf() . 'monitor/plugins';
use constant NOTIFICATION_CONF    => EBox::Config::conf() . 'monitor/notif.conf';

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
                                      printableName => __('Monitoring'),
                                      @_);
    bless($self, $class);

    return $self;
}

# Group: Public methods

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

# Method: eventWatchers
#
# Overrides:
#
#      <EBox::Events::WatcherProvider::eventWatchers>
#
sub eventWatchers
{
    return [ 'Monitor' ];
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

    my $folder = new EBox::Menu::Folder('name' => 'Maintenance',
                                        'text' => __('Maintenance'),
                                        'icon' => 'maintenance',
                                        'separator' => 'Core',
                                        'order' => 70);

    my $item = new EBox::Menu::Item('url' => 'Maintenance/Monitor',
                                    'text' => $self->printableName(),
                                    'order' => 10);
    $folder->add($item);

    $root->add($folder);
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
#      typeInstance - String the type instance name *(Optional)* It
#      only makes sense if the graphPerTypeInstance is on
#
#      - Named parameters
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
    my ($self, %params) = @_;

    my ($measureName, $period, $instance, $typeInstance) =
      ($params{measureName}, $params{period}, $params{instance}, $params{typeInstance});

    $measureName or throw EBox::Exceptions::MissingArgument('measureName');
    my ($periodData) = grep { $_->{name} eq $period } @{EBox::Monitor::Configuration::TimePeriods()};
    unless(defined($periodData)) {
        throw EBox::Exceptions::InvalidData(
            data   => 'period',
            value  => $period,
            advice => 'It must be one of the following: '
                      . join(', ', map { $_->{name} } @{EBox::Monitor::Configuration::TimePeriods()}));
    }

    my $measure = $self->_measureManager()->measure($measureName);
    return $measure->fetchData(instance     => $instance,
                               typeInstance => $typeInstance,
                               resolution   => $periodData->{resolution},
                               start        => 'end-' . $periodData->{timeValue});
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
    foreach my $measure (@{$self->_measureManager()->measures()}) {
        try  {
            if(@{$measure->instances()} > 0) {
                foreach my $instance (@{$measure->instances()}) {
                    if ( $measure->graphPerTypeInstance() ) {
                        foreach my $typeInstance (@{$measure->typeInstances()}) {
                            push(@measuredData,
                                 $measure->fetchData(instance     => $instance,
                                                     typeInstance => $typeInstance,
                                                     resolution   => $periodData->{resolution},
                                                     start        => 'end-' . $periodData->{timeValue}));
                        }
                    } else {
                        push(@measuredData,
                             $measure->fetchData(instance   => $instance,
                                                 resolution => $periodData->{resolution},
                                                 start      => 'end-' . $periodData->{timeValue}));
                    }
                }
            } else {
                if ( $measure->graphPerTypeInstance() ) {
                    foreach my $typeInstance (@{$measure->typeInstances()}) {
                        push(@measuredData,
                             $measure->fetchData(typeInstance => $typeInstance,
                                                 resolution   => $periodData->{resolution},
                                                 start        => 'end-' . $periodData->{timeValue}));
                    }
                } else {
                    push(@measuredData,
                         $measure->fetchData(resolution => $periodData->{resolution},
                                             start      => 'end-' . $periodData->{timeValue}));
                }
            }
            $atLeastOneReady = 1;
        } catch ($e) {
            my $error = $e->stringify();
            if ($error =~ m/No such file or directory/) {
                # need to save changes, ignoring..
                EBox::debug("Showing all measures: $error");
            } else {
                # rethrow exception
                $e->throw();
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
    return $self->_measureManager()->measures();
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

    return $self->_measureManager()->measure($name);
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

    my $measure = $self->_measureManager()->measure($measureName);
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

# Get the measure manager which holds all measures this module can manage
sub _measureManager
{
    my ($self) = @_;

    unless (exists $self->{measureManager}) {
        $self->_setupMeasures();
    }
    return $self->{measureManager};
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
    } catch (EBox::Exceptions::Internal $e) {
        # Catch exceptions since it is possible that the monitor
        # module has never been configured (enable once)
    }
}

# Write down the main configuration file
sub _setMainConf
{
    my ($self) = @_;

    my $hostname      = $self->global()->modInstance('sysinfo')->fqdn();
    my @networkServers = ();

    my $oldFqdn = $self->_oldHostname();
    if (not $oldFqdn) {
        $self->_setOldHostname($hostname);
    } elsif ($oldFqdn ne $hostname) {
        $self->_changeRRDDirs($oldFqdn, $hostname);
        $self->_removeSubscriptionLink(1); # to assure we have a link pointing to
                                           # the good directory
        $self->_setOldHostname($hostname);
    }

    # Send stats to Zentyal Remote with the server name if the host is subscribed
    my $global = EBox::Global->getInstance(1);
    if ( $global->modExists('remoteservices') ) {
        my $rs = $global->modInstance('remoteservices');
        if ( $rs->eBoxSubscribed() ) {
            $hostname = $rs->subscribedUUID();
            @networkServers = @{$rs->monitorGathererIPAddresses()};
            $self->_makeSubscriptionLink($hostname);
        } else {
            $self->_removeSubscriptionLink(1);
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
    my %persistAfterThresholds;

    # FIXME: workaround to avoid crash saving changes after first enable
    #my $gl = EBox::Global->getInstance(1);
    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('events') ) {
        my $evtsMod = $gl->modInstance('events');
        if ( $evtsMod->isEnabled() and $evtsMod->isEnabledWatcher('EBox::Event::Watcher::Monitor') ) {
            foreach my $id (@{$measureWatchersModel->ids()}) {
                my $measureWatcher = $measureWatchersModel->row($id);
                my $confModel = $measureWatcher->subModel('thresholds');
                try {
                    my $measureInstance = $self->_measureManager()->measure($measureWatcher->valueByName('measure'));
                    foreach my $confRow (@{$confModel->findDumpThresholds()}) {
                        my $persistElement = $confRow->elementByName('persist');
                        my $persist = 1;
                        if ( $persistElement->selectedType() eq 'persist_once' ) {
                            $persist = 0;
                        }

                        my %threshold = ( measure => $measureInstance->plugin(),
                                          type    => $measureInstance->plugin(),
                                          invert  => $confRow->valueByName('invert'),
                                          persist => $persist,
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
                        # Add threshold to the persist_after list if required
                        if ( $threshold{persist} and $persistElement->selectedType('persist_after') ) {
                            my $after = $persistElement->value();
                            $threshold{instance} = '' unless ( defined($threshold{instance}) );
                            $threshold{typeInstance} = '' unless ( defined($threshold{typeInstance}) );
                            $persistAfterThresholds{$threshold{measure}}->{$threshold{instance}}->{$threshold{type}}->{$threshold{typeInstance}}->{warn}->{after} = $after;
                            $persistAfterThresholds{$threshold{measure}}->{$threshold{instance}}->{$threshold{type}}->{$threshold{typeInstance}}->{error}->{after} = $after;
                        }
                    }
                } catch (EBox::Exceptions::DataNotFound $e) {
                    # The measure has disappear in some moment, we ignore their thresholds them
                    EBox::warn($e);
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

    if (keys(%persistAfterThresholds) > 0 ) {
        unless ( -d EBox::Config::conf() . 'monitor' ) {
            mkdir(EBox::Config::conf() . 'monitor');
        }

        EBox::Sudo::root('rm -f ' . NOTIFICATION_CONF);
        File::Slurp::write_file(NOTIFICATION_CONF,
                                encode_json(\%persistAfterThresholds));
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
sub _makeSubscriptionLink
{
    my ($self, $subscribedHostname) = @_;
    my $rrdBaseDirPath = $self->rrdBaseDirPath();

    my $subDirPath =  EBox::Monitor::Configuration::RRDBaseDirForFqdn($subscribedHostname);
    $subDirPath =~ s{/+$}{};

    # -e will fail if it is a sym link, we want this
    EBox::debug("_linkRRDS $rrdBaseDirPath -> $subDirPath");
    if ( -d $rrdBaseDirPath and (not -e $subDirPath) ) {
        EBox::info("creating subs linl $rrdBaseDirPath -> $subDirPath");
        EBox::Sudo::root("ln -sf $rrdBaseDirPath $subDirPath");
    } # else, collectd creates the directory
}

sub _removeSubscriptionLink
{
    my ($self, $stopService) = @_;
    my $parentPath = EBox::Monitor::Configuration::RRD_BASE_DIR;
    opendir(my $dh, $parentPath);
    while ( defined(my $subdir = readdir($dh)) ) {
        if ($subdir =~ m{^[0-9a-zA-Z-]+$} and length($subdir) == 36) {
            # Stop the service before removing to avoid race conditions
            $self->_stopService() if $stopService;
            my $path = "$parentPath/$subdir";
            # seems a subscription directory link, check if is a symbolink link
            if (EBox::Sudo::fileTest('-L', $path) or (not EBox::Sudo::fileTest('-e', $path)) ) {
                EBox::Sudo::root("rm '$path'");
            } else {
                # to avoid lose data we will move it to rrd path based in
                # hostname (it overwrites rrd base path if exists but the
                # subscription dir has mode updated data)
                my $rrdBaseDirPath = $self->rrdBaseDirPath();
                EBox::Sudo::root(
                                  "rm -rf '$rrdBaseDirPath'",
                                  "mv -f  '$path' '$rrdBaseDirPath'"
                                 );
            }
            last;
        }
    }
    closedir($dh);
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

    my $dfMeasure = $self->_measureManager()->measure('Df');
    return $dfMeasure->mountPoints();
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
            } catch {
                # Cannot load the runtime measure
            }
        }
    }
}

sub rrdBaseDirPath
{
    my ($self) = @_;
    my $fqdn     = $self->global()->modInstance('sysinfo')->fqdn();
    my $rrdBaseDirPath = EBox::Monitor::Configuration::RRDBaseDirForFqdn($fqdn);
    return $rrdBaseDirPath;
}

# mark as change so it is restarted in next save
sub fqdnChangedDone
{
    my ($self, $old , $new) = @_;
    $self->_setOldHostname($old);
    $self->setAsChanged(1);
}

sub _changeRRDDirs
{
    my ($self, $old, $new) = @_;
    my $newDir = EBox::Monitor::Configuration::RRDBaseDirForFqdn($new);
    my $oldDir = EBox::Monitor::Configuration::RRDBaseDirForFqdn($old);

    my $existsOld = EBox::Sudo::fileTest('-e', $oldDir);
    if (not $existsOld) {
        EBox::info("Old collectd directory $existsOld, don't exists. Nothing to do");
        return
    }
    my $existsNew = EBox::Sudo::fileTest('-e', $newDir);
    if ($existsNew) {
        EBox::info("A collectd directory with the new hostname($newDir) already exists, letting $oldDir untouched");
        $self->_setOldHostname($new);
        return;
    }

    $oldDir =~ s{/$}{};
    $newDir =~ s{/$}{};
    EBox::Sudo::root("mv '$oldDir' '$newDir'");
    EBox::info("A collectd directory $oldDir moved to $newDir ");
    $self->_setOldHostname($new);
}

sub _oldHostname
{
    my ($self) = @_;
    return $self->get_state()->{old_hostname};
}

sub _setOldHostname
{
    my ($self, $hostname) = @_;
    my $state = $self->get_state();
    $state->{old_hostname} = $hostname;
    $self->set_state($state);
}

1;
