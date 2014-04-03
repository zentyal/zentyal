# Copyright (C) 2014 Zentyal S.L.
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

# Class:
#
#   EBox::Object::Model::DynamicObjectTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   object table which basically contains object's name and a reference
#   to a member <EBox::Object::Model::ObjectMemberTable>
#
#
use strict;
use warnings;

package EBox::Objects::Model::DynamicObjectTable;

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Types::Select;

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my $tableHead = [
        new EBox::Types::Text(
            'fieldName'     => 'name',
            'printableName' => __('Name'),
            'localizable'   => 1,
            'size'          => '20',
            'unique'        => 0,
            'editable'      => 1,
            'optional'      => 0,
        ),
        new EBox::Types::IPAddr(
            fieldName       => 'filter',
            printableName   => __('Filter by network (CIDR format)'),
            editable        => 1,
            optional        => 1,
        ),
        new EBox::Types::Select(
            'fieldName'     => 'type',
            'printableName' => __('Object type'),
            'populate'      => sub { $self->_populateTypes() },
            'editable'      => 1,
        ),
        new EBox::Types::HasMany(
            'fieldName' => 'members',
            'printableName' => __('Members'),
            'foreignModel' => 'DynamicMemberTable',
            'view' => '/Objects/View/DynamicMemberTable',
            'backView' => '/Objects/View/DynamicMemberTable',
        )
    ];

    my $dataTable = {
        'tableName'             => 'DynamicObjectTable',
        'pageTitle'             => __('Objects'),
        'printableTableName'    => __('Dynamic Objects'),
        'automaticRemove'       => 1,
        'defaultController'     => '/Objects/Controller/DynamicObjectTable',
        'HTTPUrlView'           => 'Objects/Composite/Objects',
        'defaultActions'        => [ 'add', 'del', 'editField', 'changeView' ],
        'tableDescription'      => $tableHead,
        'class'                 => 'dataTable',
        'help'                  => _objectHelp(),
        'printableRowName'      => __('dynamic object'),
        'sortedBy'              => 'name',
    };

    return $dataTable;
}

sub _populateTypes
{
    my ($self) = @_;

    my $module = $self->parentModule();
    my $state = $module->get_state();
    my $registered = $state->{dynamicObjects};

    my $types = [];
    foreach my $name (keys %{$registered}) {
        my $obj = $registered->{$name};
        push (@{$types}, { value => $obj->{name}, printableValue => $obj->{printableName} });
    }
    return $types;
}

sub _objectHelp
{
    return __('Dynamic objects are managed by Zentyal, adding and removing ' .
              'members based on the filter criteria which can be used in ' .
              'other modules. The members of these kind of objects are ' .
              'always host addresses.');
}

1;
