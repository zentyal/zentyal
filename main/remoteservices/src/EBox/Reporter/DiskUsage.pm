# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::Reporter::DiskUsage;

# Class: EBox::Reporter::DiskUsage
#
#      Perform the disk usage report code
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

use EBox::FileSystem;
use Filesys::Df qw(df);
use List::Util qw(sum);

# Group: Public methods

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'sysinfo';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'sysinfo_disk_usage';
}

# Method: logPeriod
#
# Overrides:
#
#      <EBox::Reporter::Base::logPeriod>
#
sub logPeriod
{
    return 60 * 60 * 24;
}

# Group: Protected methods

# Method: _consolidate
#
# Overrides:
#
#     <EBox::Exceptions::Reporter::Base::_consolidate>
#
sub _consolidate
{
    my ($self, $begin, $end) = @_;

    my $res = $self->{db}->query_hash( { select => $self->_hourSQLStr() . ',mountpoint, used, free',
                                         from   => $self->name(),
                                         where  => $self->_rangeSQLStr($begin, $end),
                                         group  => $self->_groupSQLStr() . ', mountpoint' });
    return $res;
}

# Method: _log
#
# Overrides:
#
#     <EBox::Exceptions::Reporter::Base::_log>
#
sub _log
{
    my ($self) = @_;

    my @data;

    my $fileSysS = EBox::FileSystem::partitionsFileSystems();
    foreach my $fileSys (keys %{$fileSysS}) {
        my $entry = {};
        $entry = {};
        my $mount = $fileSysS->{$fileSys}->{mountPoint};
        $entry->{'mountpoint'} = $mount;
        my $info = df($mount, 1);
        $entry->{'used'} = $info->{'used'};
        $entry->{'free'} = $info->{'bavail'};
        push(@data, $entry)
    }

    # Add the total disk usage column
    my $totalEntry = {};
    $totalEntry = {};
    $totalEntry->{'mountpoint'} = 'total';
    $totalEntry->{'used'} = sum(map { $_->{'used'} ? $_->{'used'} : 0 } @data);
    $totalEntry->{'free'} = sum(map { $_->{'free'} ? $_->{'free'} : 0 } @data);
    unshift(@data, $totalEntry);

    return \@data;
}

1;
