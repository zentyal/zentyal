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

package EBox::UsersSync::Slave;

use base 'EBox::Users::Slave';

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
use EBox::Users::User;

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
        parentDN     => $user->parent()->dn(),
        uid          => $user->get('uid'),
        fullname     => $user->fullname(),
        givenname    => $user->firstname(),
        initials     => $user->initials(),
        surname      => $user->surname(),
        isDisabled   => $user->isDisabled(),
        isSystemUser => $user->isSystem(),
        isInternal   => $user->isInternal(),
        uidNumber    => $user->get('uidNumber'),
        passwords    => \@passwords
    };

    my $displayname = $user->displayname();
    $userinfo->{displayname} = $displayname if ($displayname);
    my $description = $user->description();
    $userinfo->{description} = $description if ($description);
    my $mail = $user->mail();
    $userinfo->{mail} = $mail if ($mail);

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
        dn           => $user->dn(),
        fullname     => $user->fullname(),
        givenname    => $user->firstname(),
        initials     => $user->initials(),
        surname      => $user->surname(),
        displayname  => $user->displayname(),
        description  => $user->description(),
        mail         => $user->mail(),
        isDisabled   => $user->isDisabled(),
        uidNumber    => $user->get('uidNumber'),
    };

    if ($pass) {
        $userinfo->{password} = $pass;
    } else {
        my @passwords = map { encode_base64($_) } @{$user->passwordHashes()};
        $userinfo->{passwords} = \@passwords;
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
        parent          => $group->parent()->dn(),
        name            => $group->name(),
        comment         => $group->description(),
        mail            => $group->mail(),
        isSecurityGroup => $group->isSecurityGroup(),
        isSystemGroup   => $group->isSystem(),
        gidNumber       => $group->get('gidNumber'),
    };

    $self->soapClient->addGroup($groupinfo);

    return 0;
}

sub _modifyGroup
{
    my ($self, $group) = @_;

    my @members = $group->get('member');
    my $groupinfo = {
        dn              => $group->dn(),
        members         => \@members,
        description     => $group->description(),
        mail            => $group->mail(),
        isSecurityGroup => $group->isSecurityGroup(),
        gidNumber       => $group->get('gidNumber'),
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
