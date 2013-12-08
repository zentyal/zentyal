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

package EBox::Reporter::PrintersJobs;

# Class: EBox::Reporter::PrintersJobs
#
#      Perform the consolidation of printer jobs by printer
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

# TODO: Disabled until tested with samba4
sub enabled { return 0; }

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'printers';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'printers_usage';
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
                    . q{pj.printer, COUNT(*) AS jobs,
                        SUM(pages) AS pages, COUNT(DISTINCT pp.username) AS users},
          from   => 'printers_jobs AS pj JOIN printers_pages AS pp ON pj.job = pp.job',
          where  => $self->_rangeSQLStr($begin, $end) . q{ AND event = 'queued' },
          group  => $self->_groupSQLStr() . ', pj.printer'
         });
    return $res;
}

1;
