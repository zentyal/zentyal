# Copyright (C) 2008-2013 Zentyal S.L.
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
#   EBox::Object::Model::ObjectTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   object table which basically contains object's name and a reference
#   to a member <EBox::Object::Model::ObjectMemberTable>
#
#
use strict;
use warnings;

package EBox::Network::Model::ObjectTable;

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
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead =
        (

            new EBox::Types::Text
                            (
                                'fieldName' => 'name',
                                'printableName' => __('Name'),
                                'size' => '12',
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'members',
                                'printableName' => __('Members'),
                                'foreignModel' => 'MemberTable',
                                'view' => '/Network/View/MemberTable',
                                'backView' => '/Network/View/MemberTable',
                             )

          );

    my $dataTable =
        {
            'tableName' => 'ObjectTable',
            'pageTitle' => __('Objects'),
            'printableTableName' => __('Objects List'),
            'automaticRemove' => 1,
            'defaultController' => '/Network/Controller/ObjectTable',
            'HTTPUrlView'   => 'Network/View/ObjectTable',
            'defaultActions' => ['add', 'del', 'editField', 'changeView', 'clone' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => _objectHelp(),
            'printableRowName' => __('object'),
            'sortedBy' => 'name',
        };

    return $dataTable;
}

# Method: warnIfIdUsed
#
#	Overrides <EBox::Model::DataTable::warnIfIdUsed>
#
#	As there are some modules which do not use the model approach
#	we have to check manually if they are using an object using the
#	old-school way of ObjectObserver
sub warnIfIdUsed
{
    my ($self, $id) = @_;

    my $objects = EBox::Global->modInstance('network');

    if ($objects->objectInUse($id)) {
        throw EBox::Exceptions::DataInUse(
                __('This object is being used by another module'));
    }

}

# Method: validateRow
#
#      Override <EBox::Model::DataTable::validateRow> method
#
sub validateRow()
{
    my $self = shift;
    my $action = shift;
}

sub validateTypedRow
{
    my ($self, $action, $newValues) = @_;
    if ($action eq 'add') {
        $self->_checkName($newValues->{name}->value())
    }
}

# Method: addObject
#
#   Add object to the objects table.
#
# Parameters:
#
#   (NAMED)
#   id         - object's id *(optional*). It will be generated automatically
#                if none is passed
#   name       - object's name
#   members    - array ref containing the following hash ref in each value:
#
#                name        - member's name
#                address_selected - type of address, can be:
#                                'ipaddr', 'iprange' (default: ipdaddr)
#
#                ipaddr  parameters:
#                   ipaddr_ip   - member's ipaddr
#                   ipaddr_mask - member's mask
#                   macaddr     - member's mac address *(optional)*
#
#               iprange parameters:
#                   iprange_begin - begin of the range
#                   iprange_end   - end of range
#
#   readOnly   - the service can't be deleted or modified *(optional)*
#
#   Example:
#
#       name => 'administration',
#       members => [
#                   { 'name'         => 'accounting',
#                     'address_selected' => 'ipaddr',
#                     'ipaddr_ip'    => '192.168.1.3',
#                     'ipaddr_mask'  => '32',
#                     'macaddr'      => '00:00:00:FA:BA:DA'
#                   }
#                  ]
sub addObject
{
    my ($self, %params) = @_;

    my $name = delete $params{'name'};
    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    $self->_checkName($name);

    my $id = $self->addRow( 'name'      => $name,
                            'id'        => $params{'id'},
                            'readOnly'  => $params{'readOnly'});
    unless (defined($id)) {
        throw EBox::Exceptions::Internal("Couldn't add object's name: $name");
    }

    my $members = delete $params{'members'};
    return unless (defined($members) and @{$members} > 0);

    my $memberModel = EBox::Model::Manager::instance()->model('MemberTable');

    $memberModel->setDirectory($self->{'directory'} . "/$id/members");
    foreach my $member (@{$members}) {
        $member->{address_selected} or
            $member->{address_selected} = 'ipaddr';
        $member->{'readOnly'} = $params{'readOnly'};
        $memberModel->addRow(%{$member});
    }

    return $id;
}

sub _objectHelp
{
    return __('Objects are an abstraction of machines and network addresses ' .
              'which can be used in other modules. Any change on an object ' .
              'is automatically synched in all the modules using it');
}

sub _checkName
{
    my ($self, $name) = @_;
    if (uc $name eq 'ANY') {
        throw EBox::Exceptions::External(
__(q{'Any' is a reserved word that could not be used as object name to avoid confusions})
                                        );
    }

    if ($name =~ m/^\d+\.\d+\.\d+\.\d+$/) {
        throw EBox::Exceptions::External(
         'A object could not be named like a IP address'
                                        );
    }

    if ($name =~ m{^\d+\.\d+\.\d+\.\d+/\d+$}) {
        throw EBox::Exceptions::External(
         'A object could not be named like a IP address with netmask'
                                        );
    }
}

1;

