# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Reporter::SambaDiskUsage;

# Class: EBox::Reporter::SambaDiskUsage
#
#      Perform the samba average usage per hour per share
#      consolidation
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

use EBox::Global;

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'samba';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'samba_disk_usage';
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

    my $res = $self->{db}->query_hash(
        { select => $self->_hourSQLStr() . ','
                    . q{share, type, CAST(AVG(size) AS UNSIGNED INTEGER) AS size},
          from   => $self->name(),
          where  => $self->_rangeSQLStr($begin, $end),
          group  => $self->_groupSQLStr() . ', share, type',
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

    my $sambaMod = EBox::Global->getInstance(1)->modInstance($self->module());

    my $stats = [];
    # Get information for each share
    my $sharesInfo = $sambaMod->shares(1);
    foreach my $share (@{$sharesInfo}) {
        my $entry = {};
        $entry->{'share'} = $share->{'share'};
        $entry->{'type'} = ($share->{'groupShare'} ? 'Group' : 'Custom');

        # Calculate share size
        $entry->{'size'} = _shareSize($share->{'path'});

        push (@{$stats}, $entry);
    }

    my $userShares = $sambaMod->userShares();
    foreach my $user (@{$userShares}) {
        my $entry = {};
        $entry->{'share'} = $user->{'user'};
        $entry->{'type'} = 'User';

        # Calculate share size
        $entry->{'size'} = 0;
        foreach my $share (@{$user->{'shares'}}) {
            $entry->{'size'} += _shareSize($share);
        }

        push (@{$stats}, $entry);
    }

    return $stats;
}

# Group: Private methods

sub _shareSize
{
    my ($path) = @_;
    if ( EBox::Sudo::fileTest('-d', $path) ) {
        my $du = EBox::Sudo::root("du -sb '$path'");
        my @du_split = split(/\t/, $du->[0]);
        return int( $du_split[0] );
    } else {
        return 0; # The path does not exist
    }
}

1;
