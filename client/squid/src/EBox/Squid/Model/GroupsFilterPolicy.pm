# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Squid::Model::GroupsFilterPolicy;
use base 'EBox::Model::DataTable';

use strict;
use warnings;


use EBox::Global;
use EBox::Gettext;
use EBox::Types::Link;
use EBox::Types::Text;
use EBox::Types::HasMany;



# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    
    bless $self, $class;
    return $self;
}


# Method: _table
#
#       The table description 
#
sub _table
{
  my @tableHeader =
    (
     new EBox::Types::Select(
                             fieldName     => 'group',
                             printableName => __('Group'),

                             populate => \&populateGroup,

                             unique        => 1,
                             editable      => 1,
                            ),
     new EBox::Types::Int(
                          fieldName => 'id',
                          printableName => 'id',
                          unique        =>  1,
                          hidden        => 1,
                         ),
     new EBox::Types::HasMany (
                                      'fieldName' => 'configuration',
                                      'printableName' => __('Filter configuration'),
                                      'foreignModel' => 'FilterSettings',
                                      'view' => '/ebox/Squid/Composite/FilterSettings',
                                      'backView' => '/ebox/Squid/View/GroupsFilterPolicy', 
                                      'editable'  => 1,
                            ),
    );

  my $dataTable =
    {
     tableName          => __PACKAGE__->nameFromClass,
     printableTableName => __(q{User groups configuration}),
     modelDomain        => 'squid',
     'defaultController' => '/ebox/Squid/Controller/GroupsFilterPolicy',
     'defaultActions' => [      
                          'add', 'del',
                          'editField',
                          'changeView'
                         ],
     tableDescription   => \@tableHeader,
     class              => 'dataTable',
     order              => 0,
     printableRowName   => __('group'),
     help               =>'',
    };

}


sub populateGroup
{
    my $userMod = EBox::Global->modInstance('users');
    my @groups = map ( 
                { 
                    value => $_->{gid}, 
                    printableValue => $_->{account}
                }, $userMod->groups()
            );
    return \@groups;
}


sub _groupModel
{
    my $users = EBox::Global->getInstance()->modInstance('users');
     return $users->model('Groups');
}


sub _findRowByGroup 
{
    my ($self, $group) = @_;
    
    my $id = $self->_groupId($group);
    return $self->findRow(group => $id);
}




sub _groupId
{
    my ($self, $group) = @_;

    my $groupsModel = $self->_groupModel();
    return $groupsModel->findId(group => $group);
}


sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ($action eq 'add') {
        # check that groups do not have overlapping users
    }

}


sub usersByGroup
{

}

sub defaultConfiguration
{

}


1;
