# Copyright (C) 2018 Zentyal S.L.
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
use strict;
use warnings;

package EBox::AntiVirus::Model::System;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::AntiVirus::Types::Status;
use EBox::AntiVirus::Types::Scan;
use EBox::AntiVirus::Types::Report;

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
       new EBox::AntiVirus::Types::Scan(
                                     fieldName => 'scan',
                                     printableName => __('Action'),
                                    ),
       new EBox::AntiVirus::Types::Status(
                                     fieldName => 'status',
                                     printableName => __('Status'),
                                    ),
       new EBox::AntiVirus::Types::Report(
                                     fieldName => 'report',
                                     printableName => __('Full Report'),
                                    ),
    );

    my $dataTable =
    {
        tableName          => 'System',
        printableTableName => __('System Scanning'),
        defaultActions     => [ 'changeView' ],
        tableDescription   => \@tableHeader,
        modelDomain        => 'AntiVirus',
        defaultEnabledValue => 1,
    };

    return $dataTable;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    if (@{$currentRows}) {
        return 0;
    } else {
        $self->add(status => 'noreport');
        return 1;
    }
}

1;
