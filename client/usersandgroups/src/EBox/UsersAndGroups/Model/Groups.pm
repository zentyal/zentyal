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

package EBox::UsersAndGroups::Model::Groups;

# Class: EBox::UsersAndGroups::Model::Groups
#
#       This a class used as a proxy for the groups stored in LDAP.
#       It is meant to improve the user experience when managing groups,
#       but it's just an interim solution. An integral approach needs to 
#       be done.
#       
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Model::Row;
use EBox::Exceptions::External;


use EBox::Types::Text;
use EBox::Types::Link;

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

         new EBox::Types::Text(
             'fieldName' => 'name',
             'printableName' => __('Name'),
             'size' => '12',
             ),
         new EBox::Types::Text(
             'fieldName' => 'description',
             'printableName' => __('Description'),
             'size' => '30',
             ),
         new EBox::Types::Link(
             'fieldName' => 'edit',
             'printableName' => __('Edit'),
             ),

        );

    my $dataTable = 
    { 
        'tableName' => 'Groups',
        'printableTableName' => __('Groups'),
        'defaultController' =>
            '/ebox/UsersAndGroups/Controller/Groups',
        'defaultActions' =>
            ['changeView'],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'UsersAndGroups/Groups',
#        'help' => __x('foo'),
        'printableRowName' => __('group'),
        'sortedBy' => 'name',
    };

    return $dataTable;
}



# Method: precondition
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub precondition
{
    my ($self) = @_;
    my $usersMod = EBox::Global->modInstance('users');
    unless ($usersMod->configured()) {
        $self->{preconFail} = 'notConfigured';
        return undef;
    }

    unless ($usersMod->groups()) {
        $self->{preconFail} = 'noGroups';
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconFail} eq 'notConfigured') {
        return __('You must enable the module Users in the module ' .
                'status section in order to use it.');
    } else {
        return __('There are no groups at the moment.');

    }
}

sub rows
{
    my ($self, $filter, $page) = @_;

    my $dir = $self->{'directory'};
    my $gconfmod = $self->{'gconfmodule'};

    my $userMod = EBox::Global->modInstance('users');

    unless ($userMod->configured()) {
        return [];
    }

    my @rows;
    foreach my $groupInfo ($userMod->groups()) {
        my $group = new EBox::Types::Text(
                'fieldName' => 'name',
                'printableName' => __('Name'),
                'size' => '12',
                'editable' => 1
                );
        my $groupName = $groupInfo->{'account'};
        $group->setValue($groupName);

        my $description = new EBox::Types::Text(
                'fieldName' => 'description',
                'printableName' => __('Description'),
                'size' => '30',
                'editable' => 1
                );
        my $desc = $groupInfo->{'desc'};
        defined $desc or
            $desc = '';
        $description->setValue($desc);

        my $link = new EBox::Types::Link(
                'fieldName' => 'edit',
                'printableName' => __('Edit'),
                );
         my $linkValue =  "/ebox/UsersAndGroups/Group?group=$groupName";
         $link->setValue($linkValue);

        my $row = EBox::Model::Row->new(dir => $dir, gconfmodule => $gconfmod);
        $row->setModel($self);
        $row->setId('NOT_USED');
        $row->setReadOnly(1);
        $row->addElement($group);
        $row->addElement($description);
        $row->addElement($link);

        push @rows, $row; 
    }

    return $self->_filterRows(\@rows, $filter, $page);
}

sub Viewer
{
    return '/ajax/tableUser.mas';
}

1;
