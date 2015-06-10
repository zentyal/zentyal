# Copyright (C) 2005-2007 Warp Networks S.L.
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

use strict;
use warnings;

package EBox::LdapUserBase;

use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);
    return $self;
}


# Method: _preAddOU
#
#   When a new ou is going to be created this method is called,
#   just before ldap add
#
# Parameters:
#
#   entry - The future OU LDAP entry
#
sub _preAddOU
{
}

sub _preAddOUFailed
{
}

# Method: _addOU
#
#    When a new ou is created this method is called
#
# Parameters:
#
#   ou - created ou
sub _addOU
{
}

sub _addOUFailed
{
}

# Method: _delOU
#
#    When a ou is deleted this method is called
#
# Parameters:
#
#   ou - deleted user
sub _delOU
{
}

# XXX no implemented yet modifyOU related methods

# Method: _preAddUser
#
#   When a new user is going to be created this method is called,
#   just before ldap add
#
# Parameters:
#
#   attrs - The user attributes of LDAP add operation
#
sub _preAddUser
{
}

sub _preAddUserFailed
{
}

# Method: _addUser
#
#    When a new user is created this method is called
#
# Parameters:
#
#   user - created user
sub _addUser
{
}

sub _addUserFailed
{
}

# Method: _preDelUser
#
#   When a new user is going to be deleted
#   TODO
#
#sub _preDelUser
#{
#}

# Method: _delUser
#
#    When a user is deleted this method is called
#
# Parameters:
#
#   user - deleted user
sub _delUser
{
}

# Method: _preModifyUser
#
#   When a user is going to be modified
#
sub _preModifyUser
{
}

# Method: _modifyUser
#
#   When a user is modified this method is called
#
# Parameters:
#
#   user - modified user
#
sub _modifyUser
{
}

# Method: _delUserWarning
#
#   When a user is to be deleted, modules should warn the sort of  data
#   (if any) is going to be removed
#
# Parameters:
#
#   user - user
#
# Returns:
#
#   array - Each element must be a string describing the sort of data
#   is going to be removed if the user is deleted. If nothing is going to
#   removed you must not return anything
#
sub _delUserWarning
{
}

# Method: _preAddContact
#
#   When a new contact is going to be created this method is called,
#   just before ldap add
#
# Parameters:
#
#   attrs - The contact attributes of LDAP add operation
#
sub _preAddContact
{
}

sub _preAddContactFailed
{
}

# Method: _addContact
#
#    When a new contact is created this method is called
#
# Parameters:
#
#   contact - created contact
sub _addContact
{
}

sub _addContactFailed
{
}

# Method: _preDelContact
#
#   When a new contact is going to be deleted
#   TODO
#
#sub _preDelContact
#{
#}

# Method: _delContact
#
#    When a contact is deleted this method is called
#
# Parameters:
#
#   contact - deleted contact
sub _delContact
{
}

# Method: _preModifyContact
#
#   When a contact is going to be modified
#   TODO
#
#sub _preModifyContact
#{
#}

# Method: _modifyContact
#
#   When a contact is modified this method is called
#
# Parameters:
#
#   contact - modified contact
#
sub _modifyContact
{
}

# Method: _preAddGroup
#
#   When a new group is going to be added
#
sub _preAddGroup
{
}

sub _preAddGroupFailed
{
}

# Method: _addGroup
#
#   When a new group is created this method is called
#
# Parameters:
#
#   group - created group
#
sub _addGroup
{
}

sub _addGroupFailed
{
}

# Method: _preModifyGroup
#
#   When a group is going to be modified this method is
#   called
#   TODO
#
#sub _preModifyGroup
#{
#}

# Method: _modifyGroup
#
#   When a group is modified this method is called
#
# Parameters:
#
#   group - modified group
#
sub _modifyGroup
{
}

# Method: _preDelGroup
#
#   When a group is going to be deleted this method is
#   called
#   TODO
#
#sub _preDelGroup
#{
#}

# Method: _delGroup
#
#   When a group is deleted this method is called
#
# Parameters:
#
#   group - deleted group
#
sub _delGroup
{
}

# Method: _delGroupWarning
#
#   When a group is to be deleted, modules should warn the sort of  data
#   (if any) is going to be removed
#
# Parameters:
#
#   group - group
#
# Returns:
#
#   array  - Each element must be a string describing the sort of data
#   is going to be removed if the group is deleted. If nothing is going to
#   removed you must not return anything
#
sub _delGroupWarning
{
}

# Method: _userAddOns
#
#    When a user is to be edited, this method is called to get customized
#    mason components from modules depending on users stored in LDAP.
#    Thus, these components will be showed below the basic user data
#    The method has to return a hash ref containing:
#    'path'   => MASON_COMPONENT_PATH_TO_BE_ADDED
#    'params' => PARAMETERS_FOR_MASON_COMPONENT
#
#    The method can also return undef to sigmnal there is not add on for the
#    module
#
# Parameters:
#
#   user - user
#
# Returns:
#
#   A hash ref containing:
#
#   path - mason component which is going to be added
#   params - parameters for the mason component
#
#   - or -
#
#   undef if there is not component to add
sub _userAddOns
{

}
# Method: noMultipleOUSupportComponent
#
# Override this method to return the component to show if this addon is disabled
# for being in a no-standar OU
#
# The default behaviour is to not return any component, thus ignoring silently
# the addon
#
#  See also standardNoMultipleOUSupportComponent for a defualt implementation
sub noMultipleOUSupportComponent
{
    return undef;
}

# Method: standardNoMultipleOUSupportComponent
#
#  Default implementation of a component for noMultipleOUSupportComponent
#
#  Parameters:
#     title -
#     msg - optional. If not given a default one will be used
sub standardNoMultipleOUSupportComponent
{
    my ($self, $title, $msg) = @_;
    if ((not $title)) {
        throw EBox::Exceptions::MissingArgument("Missing title");
    }
    if (not $msg) {
        $msg = __(q{This addon applies only to users in the default 'Users' container});
    }
    return {
        title =>  $title,
        path => '/samba/addonMsg.mas',
        params => {
              class => 'warning',
              msg  => $msg,
           }
       };
}

# Method: _groupAddOns
#
#     When a group is to be edited, this method is called to get customized
#     mason components from modules depending on groups stored in LDAP.
#     Thus, these components will be showed below the basic group data
#     The method has to return a hash ref containing:
#     'path'   => MASON_COMPONENT_PATH_TO_BE_ADDED
#     'params' => PARAMETERS_FOR_MASON_COMPONENT
#
# Parameters:
#
#       group - group to be edited
#
# Returns:
#
#       A hash ref containing:
#
#       path - mason component which is going to be added
#       params - parameters for the mason component
#
sub _groupAddOns
{

}

# Method: defaultUserModel
#
#   Returns the name of model that is used to compose a default template for
#   new user
#
# Returns:
#
#   string - model name
#
sub defaultUserModel
{
    return undef;
}

# Method: multipleOUSupport
#
#   Returns 1 if this module supports users in multiple OU's,
#   0 otherwise
#
sub multipleOUSupport
{
    return 0;
}

# Method: hiddenOUs
#
#   Returns array ref with the list of OU names to hide on the UI
#
sub hiddenOUs
{
    return [];
}

# Method: objectInDefaultContainer
#
#   Returns whether the module finds that the object is in the default container/
#
#   Currently is only used by EBox::Samba:notifyModsLdapUserBase to determine if we run the creation/deletion/modification notifications; they will be only called on a true return.
#
#   Default implementation is to call the isInDefaultContainer method on the object.
sub objectInDefaultContainer
{
    my ($self, $object) = @_;
    return $object->isInDefaultContainer();
}

1;
