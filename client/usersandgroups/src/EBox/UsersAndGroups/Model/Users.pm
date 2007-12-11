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

package EBox::UsersAndGroups::Model::Users;

# Class: EBox::UsersAndGroups::Model::Users
#
# 	This a class used it as a proxy for the users stored in LDAP.
# 	It is meant to improve the user experience when managing users,
# 	but it's just a interim solution. An integral approach needs to 
# 	be done.
# 	
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
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
					'fieldName' => 'fullname',
					'printableName' => __('Full name'),
					'size' => '12',
				      ),
		new EBox::Types::Link(
					'fieldName' => 'edit',
					'printableName' => __('Edit'),
				      ),

	 );

	my $dataTable = 
		{ 
			'tableName' => 'Users',
			'printableTableName' => __('Users'),
			'defaultController' =>
                'ebox/Users/Controller/Users',
			'defaultActions' =>
				['changeView'],
			'tableDescription' => \@tableHead,
			'menuNamespace' => 'UsersAndGroups/Users',
			'help' => __x('foo'),
		        'printableRowName' => __('user'),
                        'sortedBy' => 'name',
		};

	return $dataTable;
}

sub rows
{
	my ($self, $filter, $page) = @_;

	my $userMod = EBox::Global->modInstance('users');
	my @rows;
	for my $userInfo ($userMod->users()) {
		my $user = new EBox::Types::Text(
					'fieldName' => 'name',
					'printableName' => __('Name'),
					'size' => '12',
					'editable' => 1
				     	);
	
		my $userName = $userInfo->{'username'};
		$user->setValue($userName);
		$user->setModel($self);
		my $fullName = new EBox::Types::Text(
					'fieldName' => 'fullname',
					'printableName' => __('Full name'),
					'size' => '12',
					'editable' => 1
				     	);
		my $full = $userInfo->{'fullname'};
		$fullName->setValue($full);
		$fullName->setModel($self);
	
		my $link = new EBox::Types::Link(
					'fieldName' => 'edit',
					'printableName' => __('Edit'),
				     	);
		my $linkValue = "/ebox/UsersAndGroups/User?username=$userName";
		$link->setValue($linkValue);
		$link->setModel($self);
		push (@rows, { 'values' => [$user, $fullName, $link], 
				'printableValueHash' => 
					{
					 'name' => $userName, 
					 'fullname' => $full,
					 'edit' => ''
					}, 
				'id' => 'NOT_USED', 
				'readOnly' => 1});
	}

	return $self->_filterRows(\@rows, $filter, $page);
}

sub Viewer
{
	return '/ajax/tableUser.mas';
}

1;
