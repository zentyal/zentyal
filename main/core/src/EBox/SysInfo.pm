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

package EBox::SysInfo;

use base qw(EBox::Module::Config);

use HTML::Entities;
use Sys::Hostname;
use Sys::CpuLoad;
use File::Slurp qw(read_file);
use TryCatch;

use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Html;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Section;
use EBox::Dashboard::List;
use EBox::Dashboard::Value;
use EBox::Dashboard::HTML;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo;
use EBox::Util::Version;
use EBox::Util::Software;
use EBox::Exceptions::Internal;

use constant LATEST_VERSION => '/var/lib/zentyal/latestversion';
use constant UPDATES_URL => 'http://update.zentyal.org/updates';
use constant SMARTADMINREPORT_CRON_FILE => '/etc/cron.d/smart_admin-status_report';
use constant SMARTADMINKM_CRON_FILE => '/etc/cron.d/smart_admin-kernel_management';
use constant SMARTADMIN_ALERT_CPU_CRON_FILE => '/etc/cron.d/smart_admin_alert_cpu';
use constant SMARTADMIN_ALERT_RAM_CRON_FILE => '/etc/cron.d/smart_admin_alert_ram';
use constant SMARTADMIN_ALERT_DISK_CRON_FILE => '/etc/cron.d/smart_admin_alert_disk';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'sysinfo',
                                      printableName => __('System Information'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Set lastMessageTime only if installing the first time
    unless ($version) {
        my $state = $self->get_state();
        $state->{lastMessageTime} = time();
        $state->{closedMessages} = {};
        $self->set_state($state);
    }
}

# Method: menu
#
#   Overriden method that returns the core menu entries:
#
#   - Summary
#   - Save/Cancel
#   - Logout
#   - SysInfo/General
#   - SysInfo/Backup
#   - SysInfo/Halt
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Dashboard/Index',
                                    'icon' => 'dashboard',
                                    'text' => __('Dashboard'),
                                    'tag' => 'home',
                                    'order' => 1));

    $root->add(new EBox::Menu::Item('url' => 'ServiceModule/StatusView',
                                    'text' => __('Module Status'),
                                    'icon' => 'mstatus',
                                    'tag' => 'system',
                                    'order' => 10));

    my $system = new EBox::Menu::Folder('name' => 'SysInfo',
                                        'icon' => 'system',
                                        'text' => __('System'),
                                        'tag' => 'system',
                                        'order' => 30);

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/Composite/General',
                                      'text' => __('General'),
                                      'order' => 10));

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/Composite/DateAndTime',
                                      'text' => __('Date/Time'),
                                      'order' => 20));

    if (-f '/var/lib/zentyal/.commercial-edition') {
        $system->add(new EBox::Menu::Item('url'   => 'SysInfo/View/Edition',
                                          'text'  => __('Server Edition'),
                                          'order' => 30,
                                         ));
    }

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/Backup',
                                      'text' => __('Configuration Backup'),
                                      'order' => 50));

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/View/Halt',
                                      'text' => __('Halt/Reboot'),
                                      'order' => 60));

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/SmartAdmin',
                                      'text' => __('Smart Admin'),
                                      'order' => 70));
                                      
    $root->add($system);
}

# Method: _setConf
#
# Overrides:
#
#   <EBox::Module::Base::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    # Time zone
    my $timezoneModel = $self->model('TimeZone');
    my $tz = $timezoneModel->row()->elementByName('timezone');
    my $tzStr = $tz->printableValue();
    EBox::Sudo::root("echo $tzStr > /etc/timezone",
                     "ln -sf /usr/share/zoneinfo/$tzStr /etc/localtime");

    # Host name
    my $hostNameModel = $self->model('HostName');
    my $hostname = $hostNameModel->value('hostname');
    if ($hostname) {
        my $cmd = EBox::Config::scripts() . "change-hostname $hostname";
        my $domain = $hostNameModel->value('hostdomain');
        if ($domain) {
            $cmd .= " $domain";
        }
        EBox::Sudo::root($cmd);
    }
    
    $self->setSmartAdminReportCron();
    $self->setSmartAdminKMCron();
    $self->setSmartAdminAlertRamCron();
    $self->setSmartAdminAlertDiskCron();
    $self->setSmartAdminAlertCpuCron();
}

# Method: fqdn
#
#    Return the fully qualified domain name (hostname + domain)
#
# Returns:
#
#    String - the fully qualified domain name
#
sub fqdn
{
    my ($self) = @_;

    my $model = $self->model('HostName');
    my $name = $model->hostnameValue();
    my $domain = $model->hostdomainValue();
    my $fqdn = $name . '.' . $domain;
    return $fqdn;
}

# Method: hostName
#
#    Return the hostname without domain
#
# Returns:
#
#    String - the hostname
#
sub hostName
{
    my ($self) = @_;

    my $model = $self->model('HostName');
    my $name = $model->hostnameValue();
    return $name;
}

sub hostDomain
{
    my ($self) = @_;

    my $model = $self->model('HostName');
    my $domain = $model->hostdomainValue();
    return $domain;
}

# we override aroundRestoreconfig to restore also state data (for the widget)
sub aroundRestoreConfig
{
    my ($self, $dir, @extraOptions) = @_;
    $self->SUPER::aroundRestoreConfig($dir, @extraOptions);
    $self->_load_state_from_file($dir);
}

#
# Method: widgets
#
#   Overriden method that returns the widgets offered by this module
#
# Overrides:
#
#       <EBox::Module::widgets>
#
sub widgets
{
    my $widgets = {
        'modules' => {
            'title' => __("Module Status"),
            'widget' => \&modulesWidget,
            'order' => 6,
            'default' => 1
        },
        'general' => {
            'title' => __("General Information"),
            'widget' => \&generalWidget,
            'order' => 1,
            'default' => 1
        },
        'processes' => {
            'title' => __("Process List"),
            'widget' => \&processesWidget
        },
    };

    unless (EBox::Config::boolean('disable_links_widget')) {
        $widgets->{'links'} = {
            'title' => __('Resources'),
            'widget' => \&linksWidget,
            'order' => 2,
            'default' => 1
        };
    }

    return $widgets;
}

sub modulesWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('status');
    $widget->add($section);

    my $global = EBox::Global->getInstance();
    my $typeClass = 'EBox::Module::Service';
    my %moduleStatus;
    my $numModules = 0;
    for my $class (@{$global->modInstancesOfType($typeClass)}) {
        $class->addModuleStatus($section);
        $numModules++;
    }

    # must be integer to not break JSON parse
    my $size = sprintf("%.0f", $numModules*0.15) + 1;
    $widget->{size} = $size;
}

sub generalWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('info');
    $widget->add($section);
    my $time_command = "LC_TIME=" . EBox::locale() . " /bin/date";
    my $time = `$time_command`;
    utf8::decode($time);

    my $version = $self->version();
    my $ignore = EBox::Config::boolean('widget_ignore_updates');
    unless ($ignore or (not -f LATEST_VERSION)) {
        my $url = UPDATES_URL;
        my $lastVersion;
        open (my $fh, LATEST_VERSION);
        read ($fh, $lastVersion, 16);
        chomp($lastVersion);
        close ($fh);

        if (EBox::Util::Version::compare($lastVersion, $version) == 1) {
            if (EBox::Global->communityEdition()) {
                my $available = __('available');
                $version .=
                    " (<a target='_blank' href='$url'>$lastVersion $available</a>)";
            }
        }
    }

    my $uptime_output=`uptime`;
    my ($uptime, $users, $la1, $la2, $la3) = $uptime_output =~ /.*up  *(.*),  (.*)users?,  load average: (.*), (.*), (.*)/;

    $section->add(new EBox::Dashboard::Value(__('Time'), $time));
    $section->add(new EBox::Dashboard::Value(__('Hostname'), hostname));
    $section->add(new EBox::Dashboard::Value(__('Core version'), $version));
    $section->add(new EBox::Dashboard::Value(__('Software'), __('Checking updates...'), 'ajax', '/SysInfo/SoftwareUpdates'));
    $section->add(new EBox::Dashboard::Value(__("System load"), join(', ', Sys::CpuLoad::load)));
    $section->add(new EBox::Dashboard::Value(__("Uptime"), $uptime));
    $section->add(new EBox::Dashboard::Value(__("Users"), $users));
}

sub processesWidget
{
    my ($self, $widget) = @_;
    my $section = new EBox::Dashboard::Section('foo');
    $widget->add($section);
    my $titles = ['PID','Name'];
    my $ids = [];
    my @processes = `ps ax | grep -v PID| awk '{ print \$1, \$5 }'`;
    my $rows = {};
    for my $p (@processes) {
        chomp($p);
        my ($pid, $name) = split(' ', $p);
        encode_entities($name);
        my $foopid = 'a' . $pid;
        push(@{$ids}, $foopid);
        $rows->{$foopid} = [$pid,$name];
    }
    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows));
}

sub linksWidget
{
    my ($self, $widget) = @_;
    my $section = new EBox::Dashboard::Section('links');
    $widget->add($section);

    # Write the links widget using mason
    my $global = $self->global();
    my @params = (
        softwarePackage => $global->modExists('software'),
        community => $global->communityEdition(),
        registered => ($global->edition() eq 'basic'),
    );

    my $html = EBox::Html::makeHtml('dashboard/links-widget.mas', @params);
    $section->add(new EBox::Dashboard::HTML($html));
}

sub addKnownWidget
{
    my ($self, $wname) = @_;

    my $widgets = $self->st_get('known/widgets');
    if (not $widgets) {
        $widgets  = {};
    }
    $widgets->{$wname} = 1;
    $self->st_set('known/widgets', $widgets);
}

sub isWidgetKnown
{
    my ($self, $wname) = @_;

    my $hash = $self->st_get('known/widgets');
    defined $hash or
        return 0;

    return exists $hash->{$wname};
}

sub getDashboard
{
    my ($self, $dashboard) = @_;

    return $self->st_get_list($dashboard);
}

sub setDashboard
{
    my ($self, $dashboard, $widgets) = @_;

    $self->st_set($dashboard, $widgets);
}

sub toggleElement
{
    my ($self, $element) = @_;

    my $hash = $self->st_get($element);
    $hash->{toggled} = not $hash->{toggled};
    $self->st_set($element, $hash);
}

sub toggledElements
{
    my ($self) = @_;
    my $toggled = $self->st_get('toggled');
    if (not defined $toggled) {
        return []
    }

    my @toggled = keys %{ $toggled };
    return \@toggled;
}

sub _restartAllServices
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $failed = '';
    EBox::info('Restarting all modules');
    foreach my $mod (@{$global->modInstancesOfType('EBox::Module::Service')}) {
        my $name = $mod->name();
        next if ($name eq 'network') or
                ($name eq 'firewall');
        try {
            $mod->restartService();
        } catch (EBox::Exceptions::Internal $e) {
            $failed .= "$name ";
        }
    }
    if ($failed ne "") {
        throw EBox::Exceptions::Internal("The following modules " .
            "failed while being restarted, their state is " .
            "unknown: $failed");
    }

    EBox::info('Restarting system logs');
    try {
        EBox::Sudo::root('service rsyslog restart',
                         'service cron restart');
    } catch (EBox::Exceptions::Internal $e) {
    }
}

my $_dashboardStatusStrings;
sub dashboardStatusStrings
{
    if (defined $_dashboardStatusStrings) {
        return $_dashboardStatusStrings;
    }

    $_dashboardStatusStrings = {
        'start_button' =>  __('Start'),
        'restart_button' =>  __('Restart'),
        'running' => {
            'text'   => __('Running'),
            'tip'   => __('The service is enabled and running'),
            'class' => 'summaryRunning'
        },
        'stopped' => {
            'text'  => __('Stopped'),
            'tip'   => __('The service is enabled, but not running'),
            'class' => 'summaryStopped'
        },
        'unmanaged' => {
             'text'  => __('Running unmanaged'),
             'tip'   => __('The service is running, but not enabled in Zentyal'),
             'class' => 'summaryDisabled'
        },
        'disabled' => {
            'text'  => __('Disabled'),
            'tip'   => __('The service is not enabled in Zentyal'),
            'class' => 'summaryDisabled'
        }
     };

    return $_dashboardStatusStrings;
}

# Method: setSmartAdminReportCron
#
#   configure crontab according to user configuration
#   to call our report script
#
sub setSmartAdminReportCron
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('SmartAdminReportSettings')->crontabStrings();

    my $nice = 10;
    my $script = '';
    if ($nice) {
        if ($nice =~ m/^\d+$/) {
            $script = "root /usr/bin/nice -n $nice " if $nice > 0;
        } 
    }

    my $destination = $strings->{mail};
    if (defined $destination) {
        $script .= EBox::Config::scripts() . "smart-admin-report > /usr/share/zentyal/www/smart-admin.report && /usr/sbin/sendmail " . $strings->{mail} . ' < /usr/share/zentyal/www/smart-admin.report >/dev/null 2>&1';
    } else {
        $script .= EBox::Config::scripts() . "smart-admin-report > /usr/share/zentyal/www/smart-admin.report >/dev/null 2>&1";
    }
  
    my $tmpFile = EBox::Config::tmp() . 'smartadmin_report-cron';
    open(my $tmp, '>', $tmpFile);

    my $onceList = $strings->{once};
    if ($onceList) {
        foreach my $once (@{ $onceList }) {
            push (@lines, "$once $script");
        }
    }
    for my $line (@lines) {
        print $tmp "$line\n";
    }

    close($tmp);

    my $dst = smartAdminReportCronFile();
    EBox::Sudo::root("install --mode=0644 $tmpFile $dst");
}

sub smartAdminReportCronFile
{
    return SMARTADMINREPORT_CRON_FILE;
}

# Method: setSmartAdminKMCron
#
#   configure crontab according to user configuration
#   to call our kernel management script
#
sub setSmartAdminKMCron
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('KernelManagement')->crontabStrings();

    if ($strings) {
        my $nice = 10;
        my $script = '';
        if ($nice) {
            if ($nice =~ m/^\d+$/) {
                $script = "root /usr/bin/nice -n $nice " if $nice > 0;
            } 
        }

        $script .= EBox::Config::scripts() . "kernel-management >/dev/null 2>&1";

        my $tmpFile = EBox::Config::tmp() . 'smartadmin_kernel-management';
        open(my $tmp, '>', $tmpFile);

        my $onceList = $strings->{once};
        if ($onceList) {
            foreach my $once (@{ $onceList }) {
                push (@lines, "$once $script");
            }
        }
        for my $line (@lines) {
            print $tmp "$line\n";
        }

        close($tmp);

        my $dst = smartAdminKMCronFile();
        EBox::Sudo::root("install --mode=0644 $tmpFile $dst");
    } else {
        if (-f SMARTADMINKM_CRON_FILE) {
            EBox::Sudo::root('rm -f '.SMARTADMINKM_CRON_FILE);
        }
    }
    
}

sub smartAdminKMCronFile
{
    return SMARTADMINKM_CRON_FILE;
}

# Method: setSmartAdminAlertRamCron
#
#   configure crontab according to user configuration
#   to call our ram alert script
#
sub setSmartAdminAlertRamCron
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('SmartAlerts')->crontabStringsRam();

    if ($strings) {
        my $nice = 10;
        my $script = '';
        if ($nice) {
            if ($nice =~ m/^\d+$/) {
                $script = "root /usr/bin/nice -n $nice " if $nice > 0;
            } 
        }

        $script .= EBox::Config::scripts() .'checker-ram "'.$strings->{resource}.'" "'.$strings->{alert_body}.'" "'.$strings->{telegram} .'" "'.$strings->{api_token}.'" >/dev/null 2>&1';

        my $tmpFile = EBox::Config::tmp() . 'smartadmin_alerts-ram';
        open(my $tmp, '>', $tmpFile);

        my $onceList = $strings->{once};
        if ($onceList) {
            foreach my $once (@{ $onceList }) {
                push (@lines, "$once $script");
            }
        }
        for my $line (@lines) {
            print $tmp "$line\n";
        }

        close($tmp);

        my $dst = smartAdminAlertRamCronFile();
        EBox::Sudo::root("install --mode=0644 $tmpFile $dst");
    } else {
        if (-f SMARTADMIN_ALERT_RAM_CRON_FILE) {
            EBox::Sudo::root('rm -f '.SMARTADMIN_ALERT_RAM_CRON_FILE);
        }
    }
}

sub smartAdminAlertRamCronFile
{
    return SMARTADMIN_ALERT_RAM_CRON_FILE;
}

# Method: setSmartAdminAlertDiskCron
#
#   configure crontab according to user configuration
#   to call our disk alert script
#
sub setSmartAdminAlertDiskCron
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('SmartAlerts')->crontabStringsDisk();

    if ($strings) {
        my $nice = 10;
        my $script = '';
        if ($nice) {
            if ($nice =~ m/^\d+$/) {
                $script = "root /usr/bin/nice -n $nice " if $nice > 0;
            } 
        }

        $script .= EBox::Config::scripts() .'checker-disk "'.$strings->{resource}.'" "'.$strings->{alert_body}.'" "'.$strings->{telegram} .'" "'.$strings->{api_token}.'" >/dev/null 2>&1';

        my $tmpFile = EBox::Config::tmp() . 'smartadmin_alerts-disk';
        open(my $tmp, '>', $tmpFile);

        my $onceList = $strings->{once};
        if ($onceList) {
            foreach my $once (@{ $onceList }) {
                push (@lines, "$once $script");
            }
        }
        for my $line (@lines) {
            print $tmp "$line\n";
        }

        close($tmp);

        my $dst = smartAdminAlertDiskCronFile();
        EBox::Sudo::root("install --mode=0644 $tmpFile $dst");
    } else {
        if (-f SMARTADMIN_ALERT_DISK_CRON_FILE) {
            EBox::Sudo::root('rm -f '.SMARTADMIN_ALERT_DISK_CRON_FILE);
        }
    }
    
}

sub smartAdminAlertDiskCronFile
{
    return SMARTADMIN_ALERT_DISK_CRON_FILE;
}

# Method: setSmartAdminAlertCpuCron
#
#   configure crontab according to user configuration
#   to call our cpu alert script
#
sub setSmartAdminAlertCpuCron
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('SmartAlerts')->crontabStringsCpu();

    if ($strings) {
        my $nice = 10;
        my $script = '';
        if ($nice) {
            if ($nice =~ m/^\d+$/) {
                $script = "root /usr/bin/nice -n $nice " if $nice > 0;
            } 
        }

        $script .= EBox::Config::scripts() .'checker-cpu "'.$strings->{resource}.'" "'.$strings->{alert_body}.'" "'.$strings->{telegram} .'" "'.$strings->{api_token}.'" >/dev/null 2>&1';

        my $tmpFile = EBox::Config::tmp() . 'smartadmin_alerts-cpu';
        open(my $tmp, '>', $tmpFile);

        my $onceList = $strings->{once};
        if ($onceList) {
            foreach my $once (@{ $onceList }) {
                push (@lines, "$once $script");
            }
        }
        for my $line (@lines) {
            print $tmp "$line\n";
        }

        close($tmp);

        my $dst = smartAdminAlertCpuCronFile();
        EBox::Sudo::root("install --mode=0644 $tmpFile $dst");
    } else {
        if (-f SMARTADMIN_ALERT_CPU_CRON_FILE) {
            EBox::Sudo::root('rm -f '.SMARTADMIN_ALERT_CPU_CRON_FILE);
        }
    }
}

sub smartAdminAlertCpuCronFile
{
    return SMARTADMIN_ALERT_CPU_CRON_FILE;
}

1;
