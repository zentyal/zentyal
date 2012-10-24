# Copyright (C)
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::CalendarResource
#
#   Extends the user schema to enable managing resources for
#   calendaring and scheduling.

package EBox::CalendarResource;

use base qw(EBox::Module::Service EBox::LdapModule);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use EBox::CalendarResourceLdapUser;


# Method: _create
#
# Overrides:
#
#       <Ebox::Module::_create>
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'calendarresource',
				      printableName => __('Calendar Resource'),
				      domain => 'calendarresource',
				      @_);
    bless ($self, $class);
    return $self;
}

# Method: actions
#
# Overrides:
#
#       <EBox::Module::Service::actions>
#
sub actions
{
    return [
        {
            'action' => __('Add calendaring and scheduling LDAP schemas'),
            'reason' => __('Zentyal will need these schemas to store' .
			   ' calendaring and scheduling information for' .
			   ' users.'),
            'module' => 'calendarresource'
        },
    ];
}

# Method: enableActions
#
# Overrides:
#
#       <EBox::Module::Service::enableActions>
#
sub enableActions
{
    my ($self) = @_;

    $self->performLDAPActions();

    # Execute enable-module script
    $self->SUPER::enableActions();
}

# Method: _ldapModImplementation
#
#      All modules using any of the functions in LdapUserBase.pm
#      should override this method to return the implementation
#      of that interface.
#
# Returns:
#
#       An object implementing EBox::LdapUserBase
#
sub _ldapModImplementation
{
    return new EBox::CalendarResourceLdapUser();
}

1;
