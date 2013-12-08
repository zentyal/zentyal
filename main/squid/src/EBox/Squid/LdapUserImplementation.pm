# Copyright (C) 2009-2012 Zentyal S.L.
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

package EBox::Squid::LdapUserImplementation;
use base qw(EBox::LdapUserBase);

use EBox::Gettext;
use EBox::Global;

sub _addUser
{
    my ($self, $user) = @_;
    $self->_groupUsersChanged('__USERS__');
}

sub _delUser
{
    my ($self, $user) = @_;
    $self->_groupUsersChanged('__USERS__');
}

sub _modifyGroup
{
    my ($self, $group) = @_;

    $group = $group->name();
    $self->_groupUsersChanged($group);
}

sub _groupUsersChanged
{
    my ($self, $group) = @_;

    my $squid = EBox::Global->modInstance('squid');
    my $rules = $squid->model('AccessRules');

    if ($rules->existsPoliciesForGroup($group)) {
        $squid->setAsChanged();
    }
}

sub _delGroup
{
    my ($self, $group) = @_;

    $group = $group->name();
    my $squid = EBox::Global->modInstance('squid');
    my $rules = $squid->model('AccessRules');
    $rules->delPoliciesForGroup($group);
}

sub _delGroupWarning
{
    my ($self, $group) = @_;

    $group = $group->name();
    my $squid = EBox::Global->modInstance('squid');
    my $rules = $squid->model('AccessRules');
    if ($rules->existsPoliciesForGroup($group)) {
        return (__('HTTP proxy access rules'));
    }
    return ();
}

1;
