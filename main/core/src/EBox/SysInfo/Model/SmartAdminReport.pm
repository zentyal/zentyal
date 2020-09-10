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
use strict;
use warnings;

# Class: EBox::SysInfo::Model::SmartAdminReport
#
#   This model is used to manage the system status report feature
#
package EBox::SysInfo::Model::SmartAdminReport;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::SysInfo::Types::Run;
use EBox::SysInfo::Types::Status;
use EBox::SysInfo::Types::Download;

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
        new EBox::SysInfo::Types::Run(
           fieldName => 'run',
           printableName => __('Run checker'),
        ),
        new EBox::SysInfo::Types::Status(
           fieldName => 'status',
           printableName => __('Execution status'),
        ),
        new EBox::SysInfo::Types::Download(
           fieldName => 'download',
           printableName => __('Download full report'),
        ),
    );

    my $dataTable =
    {
        tableName          => 'SystemStatusReport',
        modelDomain        => 'SysInfo',
        printableTableName => __('System status report'),
        tableDescription   => \@tableHeader,
        defaultActions     => [ 'changeView' ],
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