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

# Class: EBox::Monitor::Measure::Df
#
#     This measure collects the file system usage information as it
#     does "df" tool.
#
#     Only mounted partitions will be shown
#

package EBox::Monitor::Measure::Df;

use strict;
use warnings;

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

# Group: Protected methods

# Method: _description
#
#       Gives the description for the measure
#
# Returns:
#
#       hash ref - the description
#
sub _description
{
    my ($self) = @_;

    # this doesn't return fs mounted under /media
    my $fileSysS = EBox::FileSystem::partitionsFileSystems(1);

    my (@typeInstances, %printableTypeInstances) = ((),());
    my @printableLabels = ();
    foreach my $fileSys (keys %{$fileSysS}) {
        my $mountPoint = $fileSysS->{$fileSys}->{mountPoint};

        if ($mountPoint eq '/') {
            push(@typeInstances, 'root');
            $printableTypeInstances{'root'} = '/';
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
            push(@typeInstances, $mountPoint);
            $printableTypeInstances{$mountPoint} = $fileSysS->{$fileSys}->{mountPoint};
        }
        push(@printableLabels, __x('used in {partition}',
                                   partition => $fileSysS->{$fileSys}->{mountPoint}));
        push(@printableLabels, __x('free in {partition}',
                                   partition => $fileSysS->{$fileSys}->{mountPoint}));
    }

    return {
        printableName   => __('File system usage'),
        help            => __('Collect the mounted file system usage information as "df" command does'),
        dataSources     => [ 'used', 'free' ],
        printableLabels => \@printableLabels,
        printableTypeInstances => \%printableTypeInstances,
        typeInstances   => \@typeInstances,
        type            => 'byte',
    };
}

1;
