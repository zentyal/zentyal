# Copyright (C) 2005-2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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

package EBox::CGI::UsersAndGroups::Del;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups',
                      @_);

    bless($self, $class);
    return $self;
}

sub _warnUser
{
    my ($self, $object, $ldapObject) = @_;

    my $usersandgroups = EBox::Global->modInstance('users');
    my $warns = $usersandgroups->allWarnings($object, $ldapObject);

    if (@{$warns}) { # If any module wants to warn user
         $self->{template} = 'users/del.mas';
         $self->{redirect} = undef;
         my @array = ();
         push(@array, 'object' => $object);
         push(@array, 'name'   => $ldapObject);
         push(@array, 'data'   => $warns);
         $self->{params} = \@array;
         return 1;
    }

    return undef;
}

sub _process
{
    my $self = shift;

    $self->_requireParam('objectname', __('object name'));
    my $name = $self->unsafeParam('objectname');
    my ($deluser, $delgroup);

    if ($self->param('cancel')) {
        $self->_requireParam('object', __('object type'));
            my $object = $self->param('object');
        if ($object eq 'user') {
            $self->{redirect} = "UsersAndGroups/User?user=$name";
        } else {
            $self->{redirect} = "UsersAndGroups/Group?group=$name";
        }
    } elsif ($self->param('deluserforce')) { # Delete user
        $deluser = 1;
    } elsif ($self->param('delgroupforce')) {
        $delgroup = 1;
    } elsif ($self->unsafeParam('deluser')) {
        my $user = new EBox::UsersAndGroups::User(dn => $name);
        $deluser = not $self->_warnUser('user', $user);
    } elsif ($self->unsafeParam('delgroup')) {
        my $group = new EBox::UsersAndGroups::Group(dn => $name);
        $delgroup = not $self->_warnUser('group', $group);
    }

    if ($deluser) {
        my $user = new EBox::UsersAndGroups::User(dn => $name);
        $user->deleteObject();
        $self->{chain} = "UsersAndGroups/Users";
        $self->{msg} = __('User removed successfully');
    } elsif ($delgroup) {
        my $group = new EBox::UsersAndGroups::Group(dn => $name);
        $group->deleteObject();
        $self->{chain} = "UsersAndGroups/Groups";
        $self->{msg} = __('Group removed successfully');
    }
}

1;
