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

    $self->_requireParam('dn', 'ou dn');
    my $dn = $self->unsafeParam('dn');

    my @params;

    push (@params, dn => $dn);

    $self->{params} = \@params;

    if ($self->param('add')) {
        $self->{json} = { success => 0 };

        my $ou = $users->objectFromDN($dn);

        $self->_requireParam('username', __('user name'));
        $self->_requireParam('name', __('first name'));
        $self->_requireParam('surname', __('last name'));
        $self->_requireParamAllowEmpty('comment', __('comment'));

        my %params;
        $params{uid} = $self->param('username');
        $params{parent} = $users->objectFromDN($dn);

        $params{name} = $self->param('name');
        $params{surname} = $self->param('surname');
        $params{fullname} = $self->param('fullname');
        $params{givenname} = $self->param('givenname');

        $params{password} = $self->unsafeParam('password');
        $params{repassword} = $self->unsafeParam('repassword');

        $params{group} = $self->unsafeParam('group');
        $params{comment} = $self->unsafeParam('comment');

        for my $field (qw/password repassword/) {
            unless (defined($params{$field}) and $params{$field} ne "") {
                throw EBox::Exceptions::DataMissing('data' => __($field));
            }
        }

        if ($params{password} ne $params{repassword}) {
            throw EBox::Exceptions::External(__('Passwords do not match.'));
        }

        my $newUser = EBox::Users::User->create(%params);
        # FIXME!
        if ($params{group}) {
            $newUser->addGroup(new EBox::Users::Group(dn => $params{group}));
        }

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Users/Tree/Manage';
    }
}

1;
