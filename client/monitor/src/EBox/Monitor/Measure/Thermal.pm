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

# Class: EBox::Monitor::Measure::Thermal
#
#     This measure collects the thermal information which is CPU
#     temperature and cooling device
#

package EBox::Monitor::Measure::Thermal;

use strict;
use warnings;

use base qw(EBox::Monitor::Measure::Base);

use EBox::Gettext;

# Constants
use constant DIRNAME_SYSFS  => '/sys/class/thermal';
use constant DIRNAME_PROCFS => '/proc/acpi/thermal_zone';

# Constructor: new
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    bless($self, $class);

    return $self;
}

# Method: enabled
#
# Overrides:
#
#       <EBox::Monitor::Measure::Base::enabled>
#
# Returns:
#
#       true - if exists /proc/acpi/thermal_zone or /sys/class/thermal
#
#       false - otherwise
#
sub enabled
{

    my $dir = '';
    if ( -r DIRNAME_SYSFS and -x DIRNAME_SYSFS ) {
        $dir = DIRNAME_SYSFS;
    } elsif ( -r DIRNAME_PROCFS and -x DIRNAME_PROCFS ) {
        $dir = DIRNAME_PROCFS;
    } else {
        return 0;
    }

    my @files = <$dir/*>;
    return (@files > 0);

}

# Group: Protected methods

# Method: _description
#
#       Gives the description for the measure
#
# Overrides:
#
#       <EBox::Monitor::Measure::Base::_description>
#
# Returns:
#
#       hash ref - the description
#
sub _description
{
    my ($self) = @_;

    # FIXME: Give support for cooling_device using /sys/class/thermal

    my (@printableLabels, @typeInstances, @measureInstances, @types, %printableInstances, $dir);
    if ( -r DIRNAME_SYSFS and -x DIRNAME_SYSFS ) {
        # Sysfs is up
#         @typeInstances = qw(temperature cooling_state);
#         @types = qw(temperature gauge);
        @typeInstances = qw(temperature);
        @types = qw(temperature);
        $dir = DIRNAME_SYSFS;
        @printableLabels = ( __('temperature')); #, __('cooling state'));
    } elsif ( -r DIRNAME_PROCFS and -x DIRNAME_PROCFS ) {
        # Procfs is up
        @typeInstances = qw(temperature);
        @types = qw(temperature);
        $dir = DIRNAME_PROCFS;
        @printableLabels = ( __('temperature') );
    }
    my $baseDir = EBox::Monitor::Configuration::RRDBaseDirPath();
    foreach my $subDir (<${baseDir}thermal-*>) {
        my ($suffix) = $subDir =~ m:thermal-(.*?)$:g;
        my $what;
        if ( $suffix =~ m:cooling_device: ) {
            $what = __('cooling device') . ' ' . substr($suffix, -1);
        } else {
            $what = __('sensor') . ' ' . substr($suffix, -1);
            push(@measureInstances, $suffix);
            $printableInstances{$suffix} = __x('Temperature for {what}',
                                               what => $what);
        }
    }

    return {
        printableName      => __('Thermal'),
        help               => __x('Collect thermal information (CPU sensors temperature) '
                                  . 'if possible from {dir}', dir => $dir),
        instances          => \@measureInstances,
        printableInstances => \%printableInstances,
        printableLabels    => \@printableLabels,
        typeInstances      => \@typeInstances,
        types              => \@types,
        type               => 'degree',
    };
}

1;
