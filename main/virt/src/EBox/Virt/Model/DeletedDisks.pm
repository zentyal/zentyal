# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Virt::Model::DeletedDisks;

use base 'EBox::Model::DataTable';

sub _table
{
    my $dataTable =
    {
        tableName => 'DeletedDisks',
        defaultActions => ['add', 'del', 'editField',  'changeView' ],
        tableDescription => [ new EBox::Types::Text(fieldName => 'file', editable => 1) ],
        class => 'dataTable',
        modelDomain => 'Virt',
    };

    return $dataTable;
}

1;
