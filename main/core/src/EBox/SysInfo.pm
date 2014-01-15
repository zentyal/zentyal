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

package EBox::SysInfo;

use base qw(EBox::Module::Config EBox::Report::DiskUsageProvider);

use HTML::Entities;
use Sys::Hostname;
use Sys::CpuLoad;
use File::Slurp qw(read_file);
use TryCatch::Lite;

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
use EBox::Report::DiskUsage;
use EBox::Report::RAID;
use EBox::Util::Version;
use EBox::Util::Software;
use EBox::Exceptions::Internal;

use constant LATEST_VERSION => '/var/lib/zentyal/latestversion';
use constant UPDATES_URL => 'http://update.zentyal.org/updates';

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
                                    'separator' => 'Core',
                                    'order' => 10));

    $root->add(new EBox::Menu::Item('url' => 'ServiceModule/StatusView',
                                    'text' => __('Module Status'),
                                    'icon' => 'mstatus',
                                    'separator' => 'Core',
                                    'order' => 20));

    my $system = new EBox::Menu::Folder('name' => 'SysInfo',
                                        'icon' => 'system',
                                        'text' => __('System'),
                                        'order' => 30);

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/Composite/General',
                                      'text' => __('General'),
                                      'order' => 10));

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/Backup',
                                      'text' => __('Import/Export Configuration'),
                                      'order' => 50));

    if (EBox::Config::boolean('debug')) {
        $system->add(new EBox::Menu::Item('url' => 'SysInfo/View/Debug',
                                          'text' => __('Debug'),
                                          'order' => 55));
    }

    $system->add(new EBox::Menu::Item('url' => 'SysInfo/View/Halt',
                                      'text' => __('Halt/Reboot'),
                                      'order' => 60));
    $root->add($system);

    my $maint = new EBox::Menu::Folder('name' => 'Maintenance',
                                       'text' => __('Maintenance'),
                                       'icon' => 'maintenance',
                                       'separator' => 'Core',
                                       'order' => 70);

    $maint->add(new EBox::Menu::Item('url' => 'Report/DiskUsage',
                                     'order' => 40,
                                     'text' => __('Disk Usage')));

    $maint->add(new EBox::Menu::Item('url' => 'Report/RAID',
                                     'order' => 50,
                                     'text' => __('RAID')));
    $root->add($maint);
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
                     "cp -f /usr/share/zoneinfo/$tzStr /etc/localtime");

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
}

sub fqdn
{
    my ($self) = @_;

    my $model = $self->model('HostName');
    my $name = $model->hostnameValue();
    my $domain = $model->hostdomainValue();
    my $fqdn = $name . '.' . $domain;
    return $fqdn;
}

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

    my $qaUpdates = 0;
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $qaUpdates = $rs->subscriptionLevel() > 0;
    }

    my $version = $self->version();
    my $ignore = EBox::Config::boolean('widget_ignore_updates');
    unless ($ignore) {
        my $url = UPDATES_URL;
        my $lastVersion;
        open (my $fh, LATEST_VERSION);
        read ($fh, $lastVersion, 16);
        chomp($lastVersion);
        close ($fh);

        if (EBox::Util::Version::compare($lastVersion, $version) == 1) {
            unless ($qaUpdates) {
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
        rsPackage => $global->modExists('remoteservices'),
        softwarePackage => $global->modExists('software'),
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

sub _facilitiesForDiskUsage
{
    my ($self, @params) = @_;

    return EBox::Backup->_facilitiesForDiskUsage(@params);
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


1;
