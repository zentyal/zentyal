# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::SysInfo;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::Report::DiskUsageProvider);

use Sys::Hostname;
use Sys::CpuLoad;

use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Section;
use EBox::Dashboard::List;
use EBox::Dashboard::Value;
use EBox::Dashboard::ModuleStatus;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Report::RAID;


sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'sysinfo',
                                          printableName => __('System information'),
                                          @_);
	bless($self, $class);
	return $self;
}


sub _facilitiesForDiskUsage
{
    my ($self, @params) = @_;
    return EBox::Backup->_facilitiesForDiskUsage(@params);
}

sub modulesWidget
{
    my ($self, $widget) = @_;
    my $section = new EBox::Dashboard::Section('status');
    $widget->add($section);

    my $global = EBox::Global->getInstance();
    my $typeClass = 'EBox::ServiceModule::ServiceInterface';
    my %moduleStatus;
    for my $class (@{$global->modInstancesOfType($typeClass)}) {
        my $modName = $class->name();
        my $modPrintName = ucfirst($class->printableName());
        my $enabled = $class->isEnabled();
        my $running = $class->isRunning();
        $section->add(new EBox::Dashboard::ModuleStatus($modName, $modPrintName, $enabled, $running));
    }
}

sub generalWidget
{
    my ($self, $widget) = @_;
    my $section = new EBox::Dashboard::Section('info');
    $widget->add($section);
    my $time_command = "LC_TIME=" . EBox::locale() . " /bin/date";
    my $time = `$time_command`;
    
    $section->add(new EBox::Dashboard::Value(__("Time"), $time));
    $section->add(new EBox::Dashboard::Value(__("Host name"), hostname));
    $section->add(new EBox::Dashboard::Value(
    __("eBox version"),
    EBox::Config::version));
    $section->add(new EBox::Dashboard::Value(
        __("System load"), join(', ', Sys::CpuLoad::load)));
}

sub testWidget
{
    my ($self, $widget) = @_;
    my $section = new EBox::Dashboard::Section('foo');
    $widget->add($section);
    my $titles = ['PID','name'];
    my $ids = [];
    my @processes = `ps ax | grep -v PID| awk '{ print \$1, \$5 }'`;
    my $rows = {};
    for my $p (@processes) {
        chomp($p);
        my ($pid, $name) = split(' ', $p);
        my $foopid = 'a' . $pid;
        push(@{$ids}, $foopid);
        $rows->{$foopid} = [$pid,$name];
    }
    $section->add(new EBox::Dashboard::List('Info', $titles, $ids, $rows));
}

#
# Method: widgets
#
#   Overriden method that returns the widgets offered by this module
#
sub widgets
{
    return {
        'modules' => {
            'title' => __("Module status"),
            'widget' => \&modulesWidget,
            'default' => 1
        },
        'general' => {
            'title' => __("General information"),
            'widget' => \&generalWidget,
            'default' => 1
        },
        'test' => {
            'title' => __("Test"),
            'widget' => \&testWidget
        },
        'test2' => {
            'title' => __("Test2"),
            'widget' => \&testWidget
        },
        'test3' => {
            'title' => __("Test3"),
            'widget' => \&testWidget
        }
    };
}

sub addKnownWidget()
{
    my ($self,$wname) = @_;
    my $list = $self->st_get_list("known/widgets");
    push(@{$list},$wname);
    $self->st_set_list("known/widgets", "string", $list);
}

sub isWidgetKnown()
{
    my ($self, $wname) = @_;
    my $list = $self->st_get_list("known/widgets");
    my @results = grep(/^$wname$/,@{$list});
    if(@results) {
        return 1;
    } else {
        return undef;
    }
}

sub getDashboard()
{
    my ($self,$dashboard) = @_;
    return $self->st_get_list("$dashboard/widgets");
}

sub setDashboard()
{
    my ($self,$dashboard,$widgets) = @_;
    $self->st_set_list("$dashboard/widgets", "string", $widgets);
}

sub toggleElement()
{
    my ($self,$element) = @_;
    my $toggled = $self->st_get_bool("toggled/$element");
    $self->st_set_bool("toggled/$element",!$toggled);
}

sub toggledElements()
{
    my ($self) = @_;
    return $self->st_hash_from_dir("toggled");
}

#
# Method: menu
#
#   	Overriden method that returns the core menu entries: 
#		
#	- Summary
#	- Save/Cancel
#	- Logout
#	- EBox/General
#	- EBox/Backup
#	- EBox/Halt
#	- EBox/Bug
sub menu
{
	my ($self, $root) = @_;

	$root->add(new EBox::Menu::Item('url' => 'Dashboard/Index',
					'text' => __('Dashboard'),
					'order' => 1));

	$root->add(new EBox::Menu::Item('url' => 'ServiceModule/StatusView',
					'text' => __('Module status'),
					'order' => 2));


	my $folder = new EBox::Menu::Folder('name' => 'EBox',
					    'text' => __('System'),
					    'order' => 3);

	$folder->add(new EBox::Menu::Item('url' => 'EBox/General',
					  'text' => __('General')));

	$folder->add(new EBox::Menu::Item('url' => 'Report/DiskUsage',
					  'text' => __('Disk usage Information')));
	if (EBox::Report::RAID::enabled()) {
	$folder->add(new EBox::Menu::Item(
			 'url' => 'Report/RAID',
             'text' => __('RAID Information'))
		    );
	}


	$folder->add(new EBox::Menu::Item('url' => 'EBox/Backup',
					  'text' => __('Backup')));

	$folder->add(new EBox::Menu::Item('url' => 'EBox/Halt',
					  'text' => __('Halt/Reboot')));

#	$folder->add(new EBox::Menu::Item('url' => 'EBox/Bug',
#					  'text' => __('Bug report')));



	$root->add($folder);
}

1;
