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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::LTSP::Model::Clients
#
#   TODO: Document class
#

package EBox::LTSP::Model::Clients;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Select;


sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub objectModel
{
    return EBox::Global->modInstance('objects')->{'objectModel'};
}

sub _table
{

    my @fields =
    (
        new EBox::Types::Select(
            'fieldName' => 'object',
            'printableName' => __('Object'),
            'foreignModel' => \&objectModel,
            'foreignField' => 'name',
            'foreignNextPageField' => 'members',
            'editable' => 1,
            'help' => __(''),
        ),
    );

    my $dataTable =
    {
        'tableName' => 'Clients',
        'printableTableName' => __('Clients'),
        'printableRowName' => __('client'),
        'automaticRemove' => 1,
        'modelDomain' => 'LTSP',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@fields,
        'help' => 'Only those object members with a MAC address will have this profile applied to them.',
        'sortedBy' => 'object',
        'enableProperty' => 1,
        'defaultEnabledValue' => 1,
    };

    return $dataTable;
}

1;
