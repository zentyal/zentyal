# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::IMProxy::Model::Rules;

# Class: EBox::IMProxy::Model::Rules
#
#   Class description
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::IMProxy::Model::Model> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;

}

sub objectModel
{
    return EBox::Global->modInstance('objects')->{'objectModel'};
}

# Group: Protected methods

# Method: _table
#
#       Model description
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
        new EBox::Types::Select(
            'fieldName' => 'object',
            'printableName' => __('Object'),
            'foreignModel' => \&objectModel,
            'foreignField' => 'name',
            'editable' => 1),
        new EBox::Types::Boolean (
            'fieldName' => 'accept',
            'printableName' => __('Accept'),
            'editable' => 1
        ),
    );

    my $dataTable =
    {
        tableName          => 'Rules',
        printableTableName => __('Filtering rules'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        printableRowName   => __('rule'),
        help               => __('help message'),
    };
    return $dataTable;
}

1;
