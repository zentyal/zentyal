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

package EBox::Users::CGI::AddUser;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Users;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/users/adduser.mas', @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');

    if ($self->param('add')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('username', __('user name'));
        $self->_requireParam('name', __('first name'));
        $self->_requireParam('surname', __('last name'));
        $self->_requireParamAllowEmpty('comment', __('comment'));

        my $user;
        $user->{'user'} = $self->param('username');
        $user->{'name'} = $self->param('name');
        $user->{'surname'} = $self->param('surname');
        $user->{'fullname'} = $user->{'name'} . ' ' . $user->{'surname'};
        $user->{'givenname'} = $user->{'name'};

        $user->{'password'} = $self->unsafeParam('password');
        $user->{'repassword'} = $self->unsafeParam('repassword');
        $user->{'group'} = $self->unsafeParam('group');
        $user->{'comment'} = $self->unsafeParam('comment');

        for my $field (qw/password repassword/) {
            unless (defined($user->{$field}) and $user->{$field} ne "") {
                throw EBox::Exceptions::DataMissing('data' => __($field));
            }
        }

        if ($user->{'password'} ne $user->{'repassword'}){
            throw EBox::Exceptions::External(__('Passwords do not match.'));
        }

        $user->{ou} = $self->unsafeParam('ou');

        my $newUser = EBox::Users::User->create($user, 0);
        if ($user->{'group'}) {
            $newUser->addGroup(new EBox::Users::Group(dn => $user->{'group'}));
        }

        $self->{json}->{success} = 1;
        $self->{redirect} = 'Users/Tree/Manage';
    }
}

1;
