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

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Model::Manager;
use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Sudo;

use Net::IP;

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub addObject
{
    my ($self, %params) = @_;

    my $name = $params{name};
    throw EBox::Exceptions::MissingArgument('name') unless defined $name;

    my $id = $self->addRow(%params);
    unless (defined $id) {
        throw EBox::Exceptions::Internal("Couldn't add object's name: $name");
    }

    return $id;
}

sub _table
{
    my $tableHead = [
        new EBox::Types::Text(
            'fieldName' => 'name',
            'printableName' => __('Internal name'),
            'localizable' => 1,
            'size' => '20',
            'unique' => 1,
            'editable' => 0,
            'hidden' => 1,
            'optional' => 0,
        ),
        new EBox::Types::Text(
            'fieldName' => 'printableName',
            'printableName' => __('Name'),
            'localizable' => 1,
            'size' => '20',
            'unique' => 0,
            'editable' => 0,
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
        'defaultActions'        => [ 'changeView' ],
        'tableDescription'      => $tableHead,
        'class'                 => 'dataTable',
        'help'                  => _objectHelp(),
        'printableRowName'      => __('dynamic object'),
        'sortedBy'              => 'name',
    };

    return $dataTable;
}

sub _objectHelp
{
    return __('Objects are an abstraction of machines and network addresses ' .
              'which can be used in other modules. Any change on an object ' .
              'is automatically synched in all the modules using it');
}

1;
