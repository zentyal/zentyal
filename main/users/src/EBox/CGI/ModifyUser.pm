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

package EBox::CGI::UsersAndGroups::ModifyUser;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::UsersAndGroups;
use EBox::UsersAndGroups::User;
use EBox::Gettext;
use EBox::Exceptions::External;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Users and Groups', @_);

    $self->{errorchain} = "UsersAndGroups/Users";
    bless($self, $class);
    return $self;
}

sub _process($) {
    my $self = shift;

    my $users = EBox::Global->modInstance('users');

    $self->_requireParam('user', __('user name'));
    $self->_requireParamAllowEmpty('quota', __('quota'));

    # retrieve user object
    my $user = $self->unsafeParam('user');
    $user = new EBox::UsersAndGroups::User(dn => $user);

    $self->{errorchain} = "UsersAndGroups/User";
    $self->keepParam('user');

    $user->set('quota', $self->param('quota'), 1);

    if ($users->editableMode()) {
        $self->_requireParam('name', __('first name'));
        $self->_requireParam('surname', __('last name'));
        $self->_requireParamAllowEmpty('comment', __('comment'));
        $self->_requireParamAllowEmpty('password', __('password'));
        $self->_requireParamAllowEmpty('repassword', __('confirm password'));

        my $givenName = $self->param('name');
        my $surname = $self->param('surname');

        my $fullname;
        if ($givenName) {
            $fullname = "$givenName $surname";
        } else {
            $fullname = $surname;
        }
        my $comment = $self->unsafeParam('comment');
        if (length ($comment)) {
            $user->set('description', $comment, 1);
        } else {
            $user->delete('description', 1);
        }

        $user->set('givenname', $givenName, 1);
        $user->set('sn', $surname, 1);
        $user->set('cn', $fullname, 1);

        # Change password if not empty
        my $password = $self->unsafeParam('password');
        if ($password) {
            my $repassword = $self->unsafeParam('repassword');
            if ($password ne $repassword){
                throw EBox::Exceptions::External(__('Passwords do not match.'));
            }

            $user->changePassword($password, 1);
        }

    }

    $user->save();

    $self->{redirect} = 'UsersAndGroups/User?user=' . $user->dn();
}


1;
