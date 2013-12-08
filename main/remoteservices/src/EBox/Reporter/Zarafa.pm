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

package EBox::Reporter::Zarafa;

# Class: EBox::Reporter::Zarafa
#
#      Perform the zarafa report code
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

use EBox::Global;
use POSIX;

# Group: Public methods

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'zarafa';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'zarafa_user_storage';
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
        { select => $self->_hourSQLStr() . ', username, fullname, email, soft_quota, hard_quota, size',
          from   => $self->name(),
          where  => $self->_rangeSQLStr($begin, $end),
          order  => $self->_groupSQLStr() . ', username' });
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

    my $zarafaMod = EBox::Global->getInstance(1)->modInstance($self->module());

    return [] unless ( $zarafaMod->isEnabled() );

    my $stats = $zarafaMod->stats();

    my @data = values(%{$stats});
    return \@data;
}

1;
