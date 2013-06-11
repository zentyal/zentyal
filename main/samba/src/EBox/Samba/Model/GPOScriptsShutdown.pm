# Copyright (C) 2013 Zentyal S.L.
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

# Class: EBox::Samba::Model::GPOScriptsShutdown
#
#
package EBox::Samba::Model::GPOScriptsShutdown;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;

# Method: _table
#
# Overrides:
#
#   <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableDesc = [
        new EBox::Types::Text(fieldName     => 'name',
                              printableName => __('Name')),
        new EBox::Types::Text(fieldName     => 'parameters',
                              printableName => __('Parameters')),
    ];

    my $dataTable = {
        tableName           => 'GPOScriptsShutdown',
        printableTableName  => __('Shutdown Scripts'),
        defaultActions      => ['add', 'delete', 'changeView'],
        tableDescription    => $tableDesc,
        printableRowName    => __('shutdown script'),
        sortedBy            => 'name',
        withoutActions      => 0,
        modelDomain         => 'Samba',
    };

    return $dataTable;
}

1;
