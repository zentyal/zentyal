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

package EBox::Reporter::Users;

# Class: EBox::Reporter::Users
#
#      Perform the weak password reporting
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

use EBox::RemoteServices::Audit::Password;
use EBox::Reporter::Password;

# Group: Public methods

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'remoteservices';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'remoteservices_passwd_users';
}

# Method: timestampField
#
# Overrides:
#
#     <EBox::Exceptions::Reporter::Base::timestampField>
#
sub timestampField
{
    my ($self) = @_;

    return $self->name() . '.' . $self->SUPER::timestampField();
}

# Method: logPeriod
#
#      The password guessing is done weekly
#
# Overrides:
#
#      <EBox::Reporter::Base::logPeriod>
#
sub logPeriod
{
    return 60 * 60 * 24 * 7;
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

    my $passwordTableName = EBox::Reporter::Password->name();
    my $passwordTSF       = EBox::Reporter::Password->timestampField();
    my $res = $self->{db}->query_hash(
        { select => $self->_hourSQLStr()
            . q{, COUNT(CASE level WHEN 'weak' THEN 1 ELSE NULL END) AS weak,
                  COUNT(CASE level WHEN 'average' THEN 1 ELSE NULL END) AS average,
                  nUsers AS nusers },
          from   => $self->name() . qq{ LEFT JOIN $passwordTableName ON DATE_FORMAT(} . $self->timestampField()
                    . q{, '%y-%m-%d %H:00:00')}
                    . " = DATE_FORMAT(${passwordTableName}.$passwordTSF, " . q{'%y-%m-%d %H:00:00')},
          where  => $self->_rangeSQLStr($begin, $end),
          group  => $self->_groupSQLStr(),
      });
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

    my $nUsers = EBox::RemoteServices::Audit::Password::nUsers();
    my @data = ( { nusers => $nUsers } );
    return \@data;
}

1;
