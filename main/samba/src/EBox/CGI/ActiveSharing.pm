# Copyright (C) 2005-2007 Warp Networks S.L
# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::CGI::Samba::ActiveSharing;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::SambaLdapUser;
use EBox::UsersAndGroups;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Samba::User;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups', @_);
    bless ($self, $class);
    return $self;
}

sub _group
{
    my ($self) = @_;

    my $smbldap = new EBox::SambaLdapUser;

    $self->_requireParam('group', __('group'));
    my $group = $self->unsafeParam('group');
    $self->{redirect} = "UsersAndGroups/Group?group=$group";
    $self->{errorchain} =  "UsersAndGroups/Group";

    $self->keepParam('group');

    $group = new EBox::UsersAndGroups::Group(dn => $group);

    $self->_requireParamAllowEmpty('sharename', __('share name'));
    my $name =  $self->param('sharename');

    if ($self->param('namechange') or $self->param('add')) {
        $smbldap->setGroupShare($group, $name);
    } elsif ($self->param('remove')) {
        $smbldap->removeGroupShare($group);
    }
}

sub _user
{
    my ($self) = @_;

    my $smbldap = new EBox::SambaLdapUser;

    $self->_requireParam('user', __('user'));
    my $user = $self->unsafeParam('user');
    $self->{redirect} = "UsersAndGroups/User?user=$user";
    $self->{errorchain} = "UsersAndGroups/User";

    $self->keepParam('user');

    my $zentyalUser = new EBox::UsersAndGroups::User(dn => $user);
    my $sambaUser = new EBox::Samba::User(samAccountName => $zentyalUser->get('uid'));
    my $accountEnabled = $self->param('accountEnabled');
    if ($accountEnabled eq 'yes') {
        $sambaUser->setAccountEnabled(1);
    } else {
        $sambaUser->setAccountEnabled(0);
    }
}

sub _process
{
    my ($self) = @_;

    if ($self->unsafeParam('user')) {
        $self->_user();
    } else {
        $self->_group();
    }
}

1;
