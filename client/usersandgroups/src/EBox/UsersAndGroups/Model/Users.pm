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
					'unique' => 1,
					'editable' => 1
				      )
	 );

	my $dataTable = 
		{ 
			'tableName' => 'Users',
			'printableTableName' => __('Users'),
			'defaultController' =>
				'/ebox/UsersAndGroups/Controller/Users',
			'defaultActions' =>
				[	
				'add', 'del',
				'move',  'editField',
				'changeView'
				],
			'tableDescription' => \@tableHead,
			'menuNamespace' => 'UsersAndGroups/Users',
			'class' => 'dataTable',
			'order' => 0,
			'help' => __x('foo'),
		        'rowUnique' => 0,
		        'printableRowName' => __('user'),
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
					'unique' => 1,
					'editable' => 1
				     	);
		$user->setValue($userInfo->{'username'});
		$user->setModel($self);
		push (@rows, { 'values' => [$user], 
				'printableValueHash' => {'name' =>
					$userInfo->{'username'}},
				'id' => 'NOT_USED', 
				'readOnly' => 1});
	}

	return $self->_filterRows(\@rows, $filter, $page);
}

1;
