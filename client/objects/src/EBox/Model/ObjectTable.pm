# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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
package EBox::Objects::Model::ObjectTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::Text;
use EBox::Types::HasMany;
use EBox::Sudo;

use Net::IP;

use strict;
use warnings;

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
                                'view' => '/ebox/Objects/View/MemberTable',
                                'backView' => '/ebox/Objects/View/MemberTable',
                             )

          );

    my $dataTable = 
        { 
            'tableName' => 'ObjectTable',
            'pageTitle' => __('Objects'),
            'printableTableName' => __('Object list'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Objects/Controller/ObjectTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('Objects'),
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

    my $objects = EBox::Global->modInstance('objects');

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

# Method: addObject
#
#   Add object to the objects table. Note this method must exist
#   because we must provide an easy way to migrate old objects module
#   to this new one.
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
#                ipaddr_ip   - member's ipaddr 
#                ipaddr_mask - member's mask
#                macaddr     - member's mac address *(optional)*
#
#   Example:
#
#       name => 'administration',
#       members => [ 
#                   { 'name'         => 'accounting',
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

   my $id = $self->addRow('name' => $name, 'id' => $params{'id'});
   unless (defined($id)) {
       throw EBox::Exceptions::Internal("Couldn't add object's name: $name");
   }

   my $members = delete $params{'members'};
   return unless (defined($members) and @{$members} > 0);

   my $memberModel =
                   EBox::Model::ModelManager::instance()->model('MemberTable');

   $memberModel->setDirectory($self->{'directory'} . "/$id/members");
   foreach my $member (@{$members}) {
       $memberModel->addRow(%{$member});
   }
}

1;

