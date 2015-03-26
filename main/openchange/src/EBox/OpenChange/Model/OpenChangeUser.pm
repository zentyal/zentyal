# Copyright 2013 Zentyal S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

use strict;
use warnings;

package EBox::OpenChange::Model::OpenChangeUser;
use base 'EBox::Model::DataForm';

use EBox::Gettext;

sub _table
{
    my ($self) = @_;

    my $tableDescription = [
        new EBox::Types::Boolean(
            fieldName     => 'enabled',
            printableName => __('Enable OpenChange account'),
            editable      => 1,
            defaultValue  => 1,
           ),
    ];

    my $dataTable = {
        tableName          => 'OpenChangeUser',
        printableTableName => 'OpenChange',
        pageTitle          => undef,
        modelDomain        => 'OpenChange',
        defaultActions     => ['add', 'del', 'editField', 'changeView' ],
        tableDescription   => $tableDescription,
        help => __('This affects both new users and groups with mail account in a managed mail domain')
    };

    return $dataTable;
}

1;
