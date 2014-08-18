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

# Class: EBox::Monitor::Measure::Df
#
#     This measure collects the file system usage information as it
#     does "df" tool.
#
#     Only mounted partitions will be shown.
#

use strict;
use warnings;

package EBox::Monitor::Measure::Df;

use base qw(EBox::Monitor::Measure::Base);

use EBox::FileSystem;
use EBox::Gettext;

# Constructor: new
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    bless($self, $class);

    return $self;
}

# Method: mountPoints
#
#       Get the mount points to monitor its disk usage
#
# Returns:
#
#       array ref - containing the mount points to monitor
#                   It excludes nfs, ro and /media mounted file systems.
#
sub mountPoints
{
    my ($self) = @_;

    # Set by _description
    return $self->{mountPoints};
}

# Group: Protected methods

# Method: _description
#
#       Gives the description for the measure.
#
#       Each partition is a plugin instance and the types for each
#       instance are used, free and reserved.
#
# Returns:
#
#       hash ref - the description
#
sub _description
{
    my ($self) = @_;

    $self->{mountPoints} = [];

    # this doesn't return fs mounted under /media
    my $fileSysS = EBox::FileSystem::partitionsFileSystems(1);

    my (@pluginInstances, %printableInstances) = ((),());
    foreach my $fileSys (keys %{$fileSysS}) {
        if ($fileSysS->{$fileSys}->{type} eq 'nfs') {
            next;
        }

        my $mountPoint = $fileSysS->{$fileSys}->{mountPoint};
        if ($mountPoint eq '/') {
            push(@pluginInstances, 'root');
            $printableInstances{'root'} = __x('Disk usage in {partition}', partition => '/');
            push(@{$self->{mountPoints}}, '/');
        } else {
            my @options = split ',', $fileSysS->{$fileSys}->{options};
            my $roFs = 0;
            foreach my $opt (@options) {
                if ($opt eq 'ro') {
                    $roFs = 1;
                    last;
                }
            }

            # no monitorize if read-only
            next if ($roFs);

            $mountPoint =~ s:/:-:g;
            $mountPoint = substr($mountPoint, 1);
            push(@pluginInstances, $mountPoint);
            $printableInstances{$mountPoint} = __x('Disk usage in {partition}',
                                                   partition => $fileSysS->{$fileSys}->{mountPoint});
            push(@{$self->{mountPoints}}, $fileSysS->{$fileSys}->{mountPoint});
        }
    }

    return {
        printableName   => __('File system usage'),
        help            => __('Collect the mounted file system usage information as "df" command does'),
        instances       => \@pluginInstances,
        printableInstances => \%printableInstances,
        types           => [ 'df_complex' ],
        printableTypeInstances => { free     => __('free'),
                                    used     => __('used'),
                                    reserved => __('reserved') },
        typeInstances   => [qw(free used reserved)],
        printableLabels => [__('free'), __('used'), __('reserved')],
        type            => 'byte',
    };
}

1;
