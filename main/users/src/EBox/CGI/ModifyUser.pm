# Copyright (C) 2005-2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

    $self->_requireParam('username', __('user name'));
    my $user = $self->param('username');
    $self->{errorchain} = "UsersAndGroups/User";
    $self->keepParam('username');

    $self->_requireParamAllowEmpty('quota', __('quota'));
    my $userdata = {
        'username' => $user,
        'quota' => $self->param('quota'),
    };
    unless ($users->mode() eq 'slave') {
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

        $userdata->{'givenname'} = $givenName;
        $userdata->{'surname'} = $surname;
        $userdata->{'fullname'} = $fullname;
        $userdata->{'comment'} = $self->param('comment');

        # Change password if not empty
        my $password = $self->unsafeParam('password');
        if ($password) {
            my $repassword = $self->unsafeParam('repassword');
            if ($password ne $repassword){
                throw EBox::Exceptions::External(
                        __('Passwords do not match.'));
            }
            $userdata->{'password'} = $password;
        }

    }

    # Quota can be changed also in slaves
    $users->modifyUser($userdata);

    $self->{redirect} = "UsersAndGroups/User?username=$user";
}


1;
