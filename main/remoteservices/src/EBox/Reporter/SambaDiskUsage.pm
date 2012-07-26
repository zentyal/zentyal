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
use Filesys::Df qw(df);

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
        #$entry->{'path'} = $share->{'path'};   # FIXME: Use or remove

        # User or group share
        $entry->{'type'} = ($share->{'groupShare'} ? 'group' : 'user');

        # Calculate and add share size
        my $info = df($share->{'path'}, 1);
        $entry->{'size'} = $info->{'used'};

        push (@{$stats}, $entry);
    }

    return $stats;
}


1;
