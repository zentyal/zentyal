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

package EBox::Reporter::Password;

# Class: EBox::Reporter::Password
#
#      Perform the weak password reporting
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

use EBox::RemoteServices::Audit::Password;

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
    return 'remoteservices_passwd_report';
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

    my $res = $self->{db}->query_hash( { select => $self->_hourSQLStr() . ', username, fullname, email, level, source',
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

    my $weakPasswdUsers = EBox::RemoteServices::Audit::Password::reportUserCheck();

    unless (defined($weakPasswdUsers)) {
        # This happens when the audit is being done. Wait for next day to report
        return [];
    }

    my @data = ();
    foreach my $user ( @{$weakPasswdUsers} ) {
        my $entry = {};
        $entry->{username} = $user->{username};
        $entry->{level} = $user->{level};
        $entry->{source} = $user->{from};
        my $additionalInfo = EBox::RemoteServices::Audit::Password::additionalInfo($entry->{username});
        $entry->{fullname} = $additionalInfo->{fullname};
        $entry->{email}    = $additionalInfo->{email};
        push(@data, $entry);
    }
    return \@data;
}

1;
