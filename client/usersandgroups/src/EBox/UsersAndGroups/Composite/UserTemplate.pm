# Copyright (C) 2009 eBox technologies S.L.
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

# Class: EBox::UsersAndGroups::Composite::UserTemplate

package EBox::UsersAndGroups::Composite::UserTemplate;

use base 'EBox::Model::Composite';

use strict;
use warnings;

## eBox uses
use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#         Constructor for the default user template 
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new();

      return $self;

  }

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
  {

      my $users = EBox::Global->modInstance('users');

      my $description =
        {
         components      => [ _userModels() ],
         layout          => 'top-bottom',
         name            => 'UserTemplate',
         compositeDomain => 'Users',
         help =>
             __('These configuration options are used when a new user account is created.')
        };

      return $description;

  }

sub precondition
{
    return (scalar(_userModels()) > 0);
}

sub preconditionFailMsg
{
    return __("There isn't any configurable option");
}

sub _userModels
{
      my $users = EBox::Global->modInstance('users');
      return @{$users->defaultUserModels()};
}

sub pageTitle
{
    return __('Default User Template');
}

sub menuFolder
{
    return 'UsersAndGroups';
}

# Method: components
#
#   Overrides <EBox::Model::Composite::components> as a workaround to
#   avoid the components being cached.
#
#   We need to skip that cache as some ldap modules can be unconfigured the
#   first time this composite is called. Without this workaround components are
#   called just once, that is during the life time of an apache process a given
#   ldap module is enabled it won't  show up until we restart apache
sub components
{
    my ($self) = @_;
    $self->_setDescription($self->_description());
    return $self->SUPER::components();
}

1;
