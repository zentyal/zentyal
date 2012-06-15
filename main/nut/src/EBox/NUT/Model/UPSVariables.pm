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

package EBox::NUT::Model::UPSVariables;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my $tableHead = [
        new EBox::Types::Text(
            fieldName => 'variable',
            printableName => __('Variable'),
            editable => 0,
        ),
        new EBox::Types::Text(
            fieldName => 'value',
            printableName => __('Value'),
            editable => 0,
        ),
    ];

    my $dataTable = {
        tableName => 'UPSVariables',
        printableTableName => __('UPS Variables'),
        modelDomain => 'NUT',
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => $tableHead,
        class => 'dataTable',
        printableRowName => __('variable'),
        insertPosition => 'back',
        sortedBy => 'variable',
        help => __('This is the list of the variables published by the UPS. ' .
                   'Some of them may be read only'),
    };

    return $dataTable;
}

1;
