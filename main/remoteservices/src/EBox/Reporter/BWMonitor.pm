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

package EBox::Reporter::BWMonitor;

# Class: EBox::Reporter::BWMonitor
#
#      Perform the bwmonitor consolidation
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'bwmonitor';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'bwmonitor_usage';
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

    my $res = $self->{db}->query_hash(
        { select => $self->_hourSQLStr() . ','
                    . q{client, username, SUM(inttotalrecv) AS inttotalrecv,
                        SUM(inttotalsent) AS inttotalsent, SUM(inttcp) AS inttcp,
                        SUM(intudp) AS intudp, SUM(inticmp) AS inticmp,
                        SUM(exttotalrecv) AS exttotalrecv,
                        SUM(exttotalsent) AS exttotalsent,
                        SUM(exttcp) AS exttcp, SUM(extudp) AS extudp,
                        SUM(exticmp) AS exticmp},
          from   => $self->name(),
          where  => $self->_rangeSQLStr($begin, $end),
          group  => $self->_groupSQLStr() . ', client, username' }
       );
    return $res;
}

1;
