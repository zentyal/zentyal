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

package EBox::Reporter::OpenVPN;

# Class: EBox::Reporter::OpenVPN
#
#      Perform the OpenVPN consolidation
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
    return 'openvpn';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'openvpn';
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
                    . q{daemon_name, daemon_type, from_cert AS certificate,
                        COUNT(event) AS connections},
          from   => $self->name(),
          where  => $self->_rangeSQLStr($begin, $end) . q{ AND event = 'connectionInitiated'},
          group  => $self->_groupSQLStr() . ', daemon_name, daemon_type, certificate' }
       );
    return $res;
}

1;
