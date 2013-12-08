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

package EBox::Reporter::SambaVirusShare;

# Class: EBox::Reporter::SambaVirusShare
#
#      Perform the report of virus depending on the share
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
    return 'samba_quarantine';
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

    my $resFiles = $self->{db}->query_hash(
        { select => $self->_hourSQLStr() . ','
                    . q{filename, COUNT(*) AS virus_num},
          from   => $self->name(),
          where  => $self->_rangeSQLStr($begin, $end) . q{ AND event = 'quarantine' },
          group  => $self->_groupSQLStr() . ', filename'
         });

    my @res;
    if ( @{$resFiles} > 0 ) {
        my $sambaMod = EBox::Global->getInstance(1)->modInstance($self->module());
        # Then, group them again but now accumulating by share
        my %byShare;
        foreach my $row (@{$resFiles}) {
            my $share = $sambaMod->shareByFilename($row->{filename});
            if ($share) {
                $byShare{$row->{hour}}->{$share->{'share'}}->{virus_num} += $row->{virus_num};
                $byShare{$row->{hour}}->{$share->{'share'}}->{type} = $share->{type};
            }
        }
        # Convert result to the expected format
        foreach my $hour (keys %byShare) {
            foreach my $share (keys %{$byShare{$hour}}) {
                push(@res, { hour      => $hour,
                             share     => $share,
                             type      => $byShare{$hour}->{$share}->{type},
                             virus_num => $byShare{$hour}->{$share}->{virus_num} });
            }
        }
    }
    return \@res;
}

1;
