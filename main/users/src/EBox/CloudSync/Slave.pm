# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::CloudSync::Slave;

use base 'EBox::Users::Slave';

use EBox::Global;
use EBox::Exceptions::External;
use EBox::Users::User;

use Error qw(:try);
use MIME::Base64;

sub new
{
    my ($class, $host, $port, $cert) = @_;
    my $self = $class->SUPER::new(name => 'zentyal-cloud');

    $self->{usersMod} = EBox::Global->modInstance('users');

    bless($self, $class);
    return $self;
}

sub _addUser
{
    my ($self, $user, $pass) = @_;

    # refresh user info to avoid cache problems with passwords:
    $user = $self->{usersMod}->userByUID($user->name());

    return if ($user->isInternal());

    my @passwords = map { encode_base64($_) } @{$user->passwordHashes()};
    my $userinfo = {
        name        => $user->get('uid'),
        firstname   => $user->get('givenName'),
        lastname    => $user->get('sn'),
        description => ($user->get('description') or ''),
        uid         => $user->get('uidNumber'),
        gid         => $user->get('gidNumber'),
        passwords   => \@passwords,
        ou          => $self->get_ou($user),
    };

    my $uid = $user->get('uid');
    $self->RESTClient->POST("/v1/users/users/$uid", query => $userinfo, retry => 1);

    return 0;
}

sub _modifyUser
{
    my ($self, $user, $pass) = @_;

    # refresh user info to avoid cache problems with passwords:
    $user = $self->{usersMod}->userByUID($user->name());

    return if ($user->isInternal());

    my @passwords = map { encode_base64($_) } @{$user->passwordHashes()};
    my $userinfo = {
        firstname  => $user->get('givenName'),
        lastname   => $user->get('sn'),
        description => ($user->get('description') or ''),
        passwords  => \@passwords,
        ou          => $self->get_ou($user),
    };

    my $uid = $user->get('uid');
    $self->RESTClient->PUT("/v1/users/users/$uid", query => $userinfo, retry => 1);

    return 0;
}

sub _delUser
{
    my ($self, $user) = @_;

    return if ($user->isInternal());

    my $uid = $user->get('uid');
    $self->RESTClient->DELETE("/v1/users/users/$uid", retry => 1);
    return 0;
}

sub _addGroup
{
    my ($self, $group) = @_;

    return if (not $group->isSecurityGroup());

    my $groupinfo = {
        name        => $group->name(),
        gid         => $group->get('gidNumber'),
        description => ($group->get('description') or ''),
        ou          => $self->get_ou($group),
    };

    my $name = $group->name();
    $self->RESTClient->POST("/v1/users/groups/$name", query => $groupinfo, retry => 1);

    return 0;
}

sub _modifyGroup
{
    my ($self, $group) = @_;

    return if (not $group->isSecurityGroup());

    # FIXME: We should sync contacts too!
    my @members = map { $_->name() } @{$group->users()};
    my $groupinfo = {
        name        => $group->name(),
        gid         => $group->get('gidNumber'),
        description => ($group->get('description') or ''),
        members     => \@members,
        ou          => $self->get_ou($group),
    };

    my $name = $group->get('cn');
    $self->RESTClient->PUT("/v1/users/groups/$name", query => $groupinfo, retry => 1);

    return 0;
}

sub _delGroup
{
    my ($self, $group) = @_;

    return if (not $group->isSecurityGroup());

    my $name = $group->get('cn');
    $self->RESTClient->DELETE("/v1/users/groups/$name", retry => 1);
    return 0;
}


sub get_ou
{
    my ($self, $entry) = @_;
    my $tail = ','.$self->{usersMod}->ldap->dn();
    my $ou = $entry->baseDn();
    $ou =~ s/$tail//;
    return $ou;
}

sub RESTClient
{
    my $rs = new EBox::Global->modInstance('remoteservices');
    return $rs->REST();
}

1;
