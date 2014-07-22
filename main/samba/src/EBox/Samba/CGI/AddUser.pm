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

package EBox::Samba::CGI::AddUser;
use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Samba;
use EBox::Samba::User;
use EBox::Samba::Group;
use EBox::Gettext;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/adduser.mas', @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('samba');

    $self->_requireParam('dn', 'ou dn');
    my $dn = $self->unsafeParam('dn');

    if ($self->param('add')) {
        $self->{json} = { success => 0 };

        $self->_requireParam('username', __('user name'));
        $self->_requireParam('givenname', __('first name'));
        $self->_requireParam('surname', __('last name'));
        $self->_requireParamAllowEmpty('description', __('description'));

        my %params;
        $params{samAccountName} = $self->param('username');
        $params{parent} = $users->objectFromDN($dn);

        $params{givenName} = $self->param('givenname');
        $params{sn} = $self->param('surname');

        $params{password} = $self->unsafeParam('password');
        $params{repassword} = $self->unsafeParam('repassword');

        $params{group} = $self->unsafeParam('group');
        $params{description} = $self->unsafeParam('description');

        for my $field (qw/password repassword/) {
            unless (defined($params{$field}) and $params{$field} ne "") {
                throw EBox::Exceptions::DataMissing('data' => __($field));
            }
        }

        if ($params{password} ne $params{repassword}) {
            throw EBox::Exceptions::External(__('Passwords do not match.'));
        }

        my $newUser = EBox::Samba::User->create(%params);
        if ($params{group}) {
            $newUser->addGroup(new EBox::Samba::Group(dn => $params{group}));
        }
        if (length($params{samAccountName}) >= 20) {
            $users->model('Manage')->setMessage(
                __(q|You have created a 20 or more characters username. Please keep in mind that some Microsoft Client OS's do not support such user lenght. If you plan this user to be logged in through a Windows Workstation, consider deleting it and creating it again with a shorter username|),
                'warning'
               );
        }

        $self->{json}->{success} = 1;
        $self->{json}->{redirect} = '/Samba/Tree/Manage';
    } else {
        my @params = (
                dn => $dn,
                groups => $users->realGroups()
        );
        $self->{params} = \@params;
    }
}

1;
