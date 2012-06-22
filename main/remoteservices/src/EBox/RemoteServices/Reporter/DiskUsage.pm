# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::RemoteServices::Reporter::DiskUsage;

# Class: EBox::RemoteServices::Reporter::DiskUsage
#
#      Perform the mail consolidation
#

use warnings;
use strict;

use base 'EBox::RemoteServices::Reporter::Base';

# Group: Public methods

# Method: module
#
# Overrides:
#
#      <EBox::RemoteServices::Reporter::Base::module>
#
sub module
{
    return 'sysinfo';
}

# Method: name
#
# Overrides:
#
#      <EBox::RemoteServices::Reporter::Base::name>
#
sub name
{
    return 'sysinfo_disk_usage';
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

1;
