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

package EBox::LdapUserBase;

use strict;
use warnings;

use EBox::Gettext;

sub new
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: _addUser
# 	
# 	When a new user is created this method is called
#
# Parameters: 
#
#   	user - user name to be created 
sub _addUser($$) # (user)
{

}

# Method: _delUser
#   
# 	When a user is deleted this method is called
#
# Parameters:
#
#   	user - user name to be deleted
sub _delUser($$) # (user)
{

}

# Method: _modifyUser
#   
#	 When a user is modified this method is called
#
# Parameters:
#
#   	user - user name to be modified
sub _modifyUser($$) # (user)
{

}

# Method: _delUserWarning
#   
# 	When a user is to be deleted, modules should warn the sort of  data
# 	(if any) is going to be removed
#
# Parameters:
#
#   	user - user name
#
# Returns:
#
#   	array ref - Each element must be a string describing the sort of data
#   	is going to be removed if the user is deleted. If nothing is going to
#   	removed you must not return anything
sub _delUserWarning($$) # (user)
{

}

# Method: _addGroup
# 	
# 	When a new user is created this method is called
#
# Parameters: 
#
#   	user - user name to be created 
sub _addGroup($$) # (group)
{

}

# Method: _modifyGroup
#   
#	 When a group is modified this method is called
#
# Parameters:
#
#   	group - group name to be modified
sub _modifyGroup($$) # (group)
{

}

# Method: _delGroup
#   
# 	When a group is deleted this method is called
#
# Parameters:
#
#   	group - group name to be deleted

sub _delGroup($$) # (group)
{

}

# Method: _delGroupWarning
#   
# 	When a group is to be deleted, modules should warn the sort of  data
# 	(if any) is going to be removed
#
# Parameters:
#
#   	group - group name
#
# Returns:
#
#   	array ref - Each element must be a string describing the sort of data
#   	is going to be removed if the group is deleted. If nothing is going to
#   	removed you must not return anything
sub _delGroupWarning($$) # (group)
{

}

# Method: _userAddOns
#   
# 	When a user is to be edited, this method is called to get customized
# 	mason components from modules depending on users stored in LDAP.
# 	Thus, these components will be showed below the basic user data
# 	The method has to return a hash ref containing:
# 	'path'   => MASON_COMPONENT_PATH_TO_BE_ADDED
# 	'params' => PARAMETERS_FOR_MASON_COMPONENT
#
# Parameters:
#
#   	user - user name to be edited
#
# Returns:
#
#   	A hash ref containing:
#
#   	path - mason component which is going to be added
#   	params - parameters for the mason component
sub _userAddOns($$)
{

}

# Method: _groupAddOns
#   
# 	When a group is to be edited, this method is called to get customized
# 	mason components from modules depending on groups stored in LDAP.
# 	Thus, these components will be showed below the basic group data
# 	The method has to return a hash ref containing:
# 	'path'   => MASON_COMPONENT_PATH_TO_BE_ADDED
# 	'params' => PARAMETERS_FOR_MASON_COMPONENT
#
# Parameters:
#
#   	group - group name to be edited
#
# Returns:
#
#   	A hash ref containing:
#
#   	path - mason component which is going to be added
#   	params - parameters for the mason component
sub _groupAddOns($$)
{

}

# Method: _includeLDAPSchemas
#   
# 	Those modules which need to use their own LDAP schemas must implement 
# 	this method. It must return an array with LDAP schemas.
#
# Returns:
#
#   	an array ref - containing in each element the full path of the schema 
#   	schema file to be include
sub _includeLDAPSchemas
{
	return [];	
}

# Method: _includeLDAPAcls
#   
# 	Those modules which need to include their own acls for the LDAP
# 	configuration must implement this method. It must return an array
# 	containing acl's
#
# Returns:
#
#   	an array ref - containing in each element an acl 
sub _includeLDAPAcls
{
	return [];
}

1;
