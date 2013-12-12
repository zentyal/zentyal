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

package EBox::UsersSync::Slave;

use strict;
use warnings;


use base 'EBox::UsersAndGroups::Slave';

# Dir containing certificates for this master
use constant SSL_DIR => EBox::Config::conf() . 'ssl/';

# Dir storing slave
use constant SLAVES_CERTS_DIR => '/var/lib/zentyal/conf/users/slaves/';

use EBox::Global;
use EBox::Exceptions::External;
use EBox::Util::Random;
use EBox::Sudo;
use EBox::SOAPClient;
use EBox::Gettext;
use URI::Escape;
use File::Slurp;
use Error qw(:try);
use MIME::Base64;

sub new
{
    my ($class, $host, $port, $id) = @_;
    my $self = $class->SUPER::new(name => $id);
    $self->{host} = $host;
    $self->{port} = $port;
    $self->{cert} = SLAVES_CERTS_DIR . $id;
    bless($self, $class);
    return $self;
}


sub _addUser
{
    my ($self, $user) = @_;

    # encode passwords
    my @passwords = map { encode_base64($_) } @{$user->passwordHashes()};
    my $userinfo = {
        user       => $user->get('uid'),
        fullname   => $user->get('cn'),
        surname    => $user->get('sn'),
        givenname  => $user->get('givenName'),
        uidNumber  => $user->get('uidNumber'),
        passwords  => \@passwords
    };

    if ($user->get('description')) {
        $userinfo->{comment} = $user->get('description');
    }

    # Different OU?
    my $users = EBox::Global->modInstance('users');
    if ($user->baseDn() ne $users->usersDn()) {
        $userinfo->{ou} = $user->baseDn();
    }

    # Convert userinfo to SOAP::Data to avoid automatic conversion errors
    my @params;
    for my $k (keys %$userinfo) {
        if (ref($userinfo->{$k}) eq 'ARRAY') {
            push(@params, SOAP::Data->name($k => SOAP::Data->value(@{$userinfo->{$k}})));
        } else {
            push(@params, SOAP::Data->name($k => $userinfo->{$k}));
        }
    }

    $userinfo = SOAP::Data->name("userinfo" => \SOAP::Data->value(@params));
    $self->soapClient->addUser($userinfo);

    return 0;
}

sub _modifyUser
{
    my ($self, $user, $pass) = @_;

    my $userinfo = {
        dn         => $user->dn(),
        fullname   => $user->get('cn'),
        surname    => $user->get('sn'),
        givenname  => $user->get('givenName'),
        uidNumber  => $user->get('uidNumber'),
    };

    if ($pass) {
        $userinfo->{password} = $pass;
    } else {
        my @passwords = map { encode_base64($_) } @{$user->passwordHashes()};
        $userinfo->{passwords} = \@passwords;
    }

    if ($user->get('description')) {
        $userinfo->{description} = $user->get('description');
    }

    $self->soapClient->modifyUser($userinfo);

    return 0;
}

sub _delUser
{
    my ($self, $user) = @_;
    $self->soapClient->delUser($user->dn());
    return 0;
}

sub _addGroup
{
    my ($self, $group) = @_;

    my $groupinfo = {
        name     => $group->name(),
        comment  => $group->get('description'),
    };

    $self->soapClient->addGroup($groupinfo);

    return 0;
}

sub _modifyGroup
{
    my ($self, $group) = @_;

    my @members = $group->get('member');
    my $groupinfo = {
        dn       => $group->dn(),
        members  => \@members,
    };

    $self->soapClient->modifyGroup($groupinfo);

    return 0;
}

sub _delGroup
{
    my ($self, $group) = @_;
    $self->soapClient->delGroup($group->dn());
    return 0;
}



# CLIENT METHODS

sub soapClient
{
    my ($self) = @_;

    my $hostname = $self->{host};
    my $port = $self->{port};

    unless ($self->{client}) {
        $self->{client} = EBox::SOAPClient->instance(
            name  => 'urn:Users/Slave',
            proxy => "https://$hostname:$port/slave/",
            certs => {
                cert => SSL_DIR . 'ssl.cert',
                private => SSL_DIR . 'ssl.key',
                ca => $self->{cert},
            }
        );
    }
    return $self->{client};
}


1;
