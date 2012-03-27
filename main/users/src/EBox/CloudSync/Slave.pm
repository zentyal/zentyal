# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::CloudSync::Slave;

use strict;
use warnings;


use base 'EBox::UsersAndGroups::Slave';

use EBox::Global;
use EBox::Exceptions::External;
use Error qw(:try);


sub new
{
    my ($class, $host, $port, $cert) = @_;
    my $self = $class->SUPER::new(name => 'zentyal-cloud');
    bless($self, $class);
    return $self;
}


sub _addUser
{
    my ($self, $user, $pass) = @_;

    my $users = EBox::Global->modInstance('users');
    return if ($user->baseDn() ne $users->usersDn());

    my $userinfo = {
        name       => $user->get('uid'),
        givenname  => $user->get('givenName'),
        uid        => $user->get('uidNumber'),
        gid        => $user->get('gidNumber'),
        surname    => $user->get('sn'),
        password   => $pass,
    };

    if ($user->get('description')) {
        $userinfo->{description} = $user->get('description');
    }

    my $uid = $user->get('uid');
    $self->REST->POST("users/$uid", $userinfo);

    return 0;
}

sub _modifyUser
{
    my ($self, $user, $pass) = @_;

    my $userinfo = {
        fullname   => $user->get('cn'),
        surname    => $user->get('sn'),
        givenname  => $user->get('givenName'),
    };

    $userinfo->{password} = $pass if ($pass);

    if ($user->get('description')) {
        $userinfo->{description} = $user->get('description');
    }

    my $uid = $user->get('uid');
    $self->REST->PUT("users/$uid", $userinfo);

    return 0;
}

sub _delUser
{
    my ($self, $user) = @_;
    my $uid = $user->get('uid');
    $self->REST->DELETE("users/$uid");
    return 0;
}

sub _addGroup
{
    my ($self, $group) = @_;

    my $groupinfo = {
        name     => $group->name(),
        comment  => $group->get('description'),
        gid      => $group->get('gidNumber'),
    };

    my $name = $group->name();
    $self->REST->POST("groups/$name", $groupinfo);

    return 0;
}

sub _modifyGroup
{
    my ($self, $group) = @_;

    my @members = $group->get('member');
    my $groupinfo = {
        name     => $group->name(),
        gid      => $group->get('gidNumber'),
        members  => \@members,
    };

    my $cn = $group->get('cn');
    $self->REST->PUT("groups/$cn", $groupinfo);

    return 0;
}

sub _delGroup
{
    my ($self, $group) = @_;
    my $cn = $group->get('cn');
    $self->REST->DELETE("groups/$cn");
    return 0;
}


# CLIENT METHODS

sub REST
{
    my ($self) = @_;

    my $rs = EBox::Global->modInstance('remoteservices');
    return $rs->REST();
}


1;
