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

package EBox::Reporter::Mail;

# Class: EBox::Reporter::Mail
#
#      Perform the mail consolidation
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
    return 'mail';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'mail_message';
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
                    . q{client_host_ip, SUBSTRING_INDEX(from_address, '@', 1) AS user_from,
                        SUBSTRING_INDEX(from_address, '@', -1) AS domain_from,
                        SUBSTRING_INDEX(to_address, '@', 1) AS user_to,
                        SUBSTRING_INDEX(to_address, '@', -1) AS domain_to,
                        SUM(COALESCE(message_size,0)) AS bytes, COUNT(*) AS messages,
                        message_type, event},
          from   => $self->name(),
          where  => $self->_rangeSQLStr($begin, $end),
          group  => $self->_groupSQLStr() . ', client_host_ip, user_from, domain_from, user_to, domain_to, message_type, event' }
       );
    return $res;
}

1;
