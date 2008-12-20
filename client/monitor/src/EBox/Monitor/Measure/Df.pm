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

use EBox::Report::DiskUsage;
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

    # TODO: Move this method to EBox::FileSystem
    my $fileSysS = EBox::Report::DiskUsage::partitionsFileSystems();

    my @rrds = ();
    my @printableLabels = ();
    foreach my $fileSys (keys %{$fileSysS}) {
        if ( $fileSysS->{$fileSys}->{mountPoint} eq '/' ) {
            push(@rrds, 'df-root.rrd');
        } else {
            my $mountPoint = $fileSysS->{$fileSys}->{mountPoint};
            $mountPoint =~ s:/:-:g;
            push(@rrds, "df-${mountPoint}.rdd");
        }
        push(@printableLabels, __x('free in {partition}',
                                   partition => $fileSysS->{$fileSys}->{mountPoint}));
        push(@printableLabels, __x('used in {partition}',
                                   partition => $fileSysS->{$fileSys}->{mountPoint}));
    }

    return {
        printableName   => __('File system usage'),
        help            => __('Collect the mounted file system usage information as "df" command does'),
        dataSources     => [ 'free', 'used' ],
        printableLabels => \@printableLabels,
        realms          => [ 'df' ],
        printableRealms => { 'df' => __('File system usage') },
        rrds            => \@rrds,
        type            => 'byte',
    };
}

1;
