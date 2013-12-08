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

package EBox::Reporter::IDS;

# Class: EBox::Reporter::IDS
#
#      Perform the IDS consolidation
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

# Method: enabled
#
#      Currently, this reporter is disabled as it seems useless at
#      this moment
#
# Overrides:
#
#      <EBox::Reporter::Base::enabled>
#
sub enabled
{
    return 0;
}

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'ids';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'ids_event';
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
                    . q{SUBSTRING_INDEX(source, ':', 1) AS source_host,
                        COUNT(CASE WHEN priority = 1 THEN 1 ELSE NULL END) AS priority1,
                        COUNT(CASE WHEN priority = 2 THEN 1 ELSE NULL END) AS priority2,
                        COUNT(CASE WHEN priority = 3 THEN 1 ELSE NULL END) AS priority3,
                        COUNT(CASE WHEN priority = 4 THEN 1 ELSE NULL END) AS priority4,
                        COUNT(CASE WHEN priority = 5 THEN 1 ELSE NULL END) AS priority5
                       },
          from   => $self->name(),
          where  => $self->_rangeSQLStr($begin, $end),
          group  => $self->_groupSQLStr() . ', source_host' }
       );
    return $res;
}

1;
