# Copyright (C) 2014 Zentyal S. L.
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

package EBox::HA::Model::ClusterState;

# Class: EBox::HA::Model::ClusterState
#
#     Model to store the cluster state. It cannot be
#     <EBox::HA::Model::Cluster> due to show a set of fields or other
#     depending on this state.
#

use base 'EBox::Model::DataForm';

use EBox::Types::Boolean;
use EBox::Types::Text;

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#       <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @fields = (
        new EBox::Types::Boolean(
            fieldName     => 'bootstraped',
            editable      => 1,
            defaultValue  => 0,
        ),
        new EBox::Types::Text(
            fieldName     => 'leaveRequest',
            editable      => 1,
            defaultValue  => "",
        ),
    );
    my $dataTable =
    {
        tableName => 'ClusterState',
        defaultActions => [ 'editField', 'changeView' ],
        modelDomain => 'HA',
        tableDescription => \@fields,
    };

    return $dataTable;
}

1;
