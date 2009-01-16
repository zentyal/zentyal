# Copyright 2009 (C) eBox Technologies S.L.
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

# Class: EBox::Collectd::Thermal
#
#    Backporting thermal plugin from collectd 4.5.2.
#
#    Original C code
#    Copyright (C) 2008  Michał Mirosław
#
#    Documentation is available on:
#
#     http://collectd.org/documentation/manpages/collectd-perl.5.shtml
#

package EBox::Collectd::Thermal;

use strict;
use warnings;

# Core

# External uses
use Collectd qw(:all);

# Constants
use constant DIRNAME_SYSFS => '/sys/class/thermal';
use constant DIRNAME_PROCFS => '/proc/acpi/thermal_zone';
use constant {
    TEMP => 0,
    COOLING_DEV => 1,
};

plugin_register(TYPE_INIT, 'thermal', 'thermal_init');
plugin_register(TYPE_SHUTDOWN, 'thermal', 'thermal_shutdown');

# Class
my $vl_temp_template = {};
my $vl_state_template = {};

# Group: Public plugin procedures

# Procedure: thermal_init
#
#      Init plugin
#
# Returns:
#
#      True - if it may be loaded
#
#      False - otherwise
#
sub thermal_init
{
    my $ret = 0;
    if ( -r DIRNAME_SYSFS and -x DIRNAME_SYSFS ) {
        $ret = plugin_register(TYPE_READ, 'thermal', 'thermal_sysfs_read');
    } elsif ( -r DIRNAME_PROCFS and -x DIRNAME_PROCFS ) {
        $ret = plugin_register(TYPE_READ, 'thermal', 'thermal_procfs_read');
    }

    if ( $ret ) {
        $vl_temp_template = {
            interval      => $interval_g,
            host          => $hostname_g,
            plugin        => 'thermal',
            type_instance => 'temperature'
           };
        $vl_state_template = $vl_temp_template;
        $vl_state_template->{type_instance} = 'cooling_state';
    }

    return $ret;

}

# Procedure: thermal_shutdown
#
#      Shutdown plugin
#
# Returns:
#
#      1
#
sub thermal_shutdown
{
    return 1;
}

# Procedure: thermal_sysfs_read
#
#      Read data from sysfs and submit results to collectd
#
sub thermal_sysfs_read
{
    return walk_directory(DIRNAME_SYSFS, \&thermal_sysfs_device_read, undef);

}

# Procedure: thermal_procfs_read
#
#      Read data from procfs and submit results to collectd
#
sub thermal_procfs_read
{
    return walk_directory(DIRNAME_PROCFS, \&thermal_procfs_device_read, undef);
}

# Procedure: thermal_sysfs_device_read
#
#     Read file from sysfs
#
# Parameters:
#
#     dirName - String the directory name (SYSFS)
#
#     fileName - String the file name inside dirName
#
sub thermal_sysfs_device_read
{
    my ($dir, $name) = @_;

    my $ok = 0;

    # Read temperature
    my $fileName = sprintf('%s/%s/temp', DIRNAME_SYSFS, $name);
    unless ( length($fileName) > 0 ) {
        return 0;
    }
    open(my $file, '<', $fileName);
    my @data = <$file>;
    close($file);

    chomp($data[0]);
    my $temp = $data[0] / 1000.0;

    if (defined($temp)) {
        thermal_submit($name, TEMP, $temp);
        $ok++;
    }

    # Read cur_state
    $fileName =  sprintf('%s/%s/cur_state', DIRNAME_SYSFS, $name);
    unless ( length($fileName) > 0 ) {
        return 0;
    }
    open($file, '<', $fileName);
    @data = <$file>;
    close($file);

    chomp($data[0]);
    my $state = $data[0] + 0;

    if ( defined($state) ) {
        thermal_submit($name, COOLING_DEV, $state);
        $ok++;
    }

    return ($ok > 0) ? 1 : 0;
}

# Procedure: thermal_procfs_device_read
#
#     Read file from procfs
#
# Parameters:
#
#     dirName - String the directory name (PROCFS)
#
#     fileName - String the file name inside dirName
#
sub thermal_procfs_device_read
{
    my ($dir, $name) = @_;

    # rechot ~ # cat /proc/acpi/thermal_zone/THRM/temperature
    # temperature:             55 C

    my $fileName = sprintf('%s/%s/temperature', DIRNAME_PROCFS, $name);
    unless ( length($fileName) > 0) {
        return 0;
    }

    open(my $file, '<', $fileName);
    my @data = <$file>;
    close($file);

    chomp($data[0]);
    my ($celsius, $add);
    my ($number, $measure) = $data[0] =~ m/^temperature:\s+(\d+)\s(.)$/g;

    if ($measure eq 'C') {
        $celsius = 1;
        $add = 0;
    } elsif ( $measure eq 'F' ) {
        $celsius = 5/9;
        $add = -32;
    } elsif ( $measure eq 'K' ) {
        $celsius = 1;
        $add = -273.15;
    }

    my $temp = ($number + $add) * $celsius;

    thermal_submit($name, TEMP, $temp);
    return 1;

}

# Group: Private procedures

# Executes func_p in every file of dirName
sub walk_directory
{
    my ($dirName, $func_p, $user_data) = @_;

    my ($success, $failure) = (0, 0);
    my ($dir, $file);
    opendir($dir, $dirName)
      or die "Cannot open $dirName: $!";

    while(defined($file = readdir($dir))) {
        next if ($file eq '.' or $file eq '..');
        my $status = $func_p->($dirName, $file, $user_data);
        if ( $status ) {
            $success++;
        } else {
            $failure++;
        }
    }
    closedir($dir);

    if( ($success == 0) and ($failure > 0)) {
        return 0;
    }
    return 1;
}

# Submit the value to collectd
#
# Parameters:
#
#     plugin_instance - String the plugin instance
#
#     dt - Int the device type
#
#     value - Float the value to submit
#
sub thermal_submit
{
    my ($plugin_instance, $dt, $value) = @_;

    my $vl;
    my $type;
    if ( $dt == TEMP ) {
        $vl = $vl_temp_template;
        $type = 'temperature';
    } else {
        $vl = $vl_state_template;
        $type = 'gauge';
    }
    $vl->{values} = [ $value ];
    $vl->{time} = time();
    $vl->{plugin} = 'thermal';
    $vl->{plugin_instance} = $plugin_instance;
    $vl->{type} = $type;

    plugin_dispatch_values( $type, $vl );

}

1;
