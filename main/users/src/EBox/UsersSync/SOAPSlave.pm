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

package EBox::UsersSync::SOAPSlave;

use EBox::Global;
use EBox::Users::Contact;
use EBox::Users::Group;
use EBox::Users::User;

use Devel::StackTrace;

# Public class methods

sub new
{
    my $class = shift;
    my $self = {};

    my $ro = 1;
    $self->{usersMod} = EBox::Global->getInstance($ro)->modInstance('users');

    bless ($self, $class);
    return $self;
}

sub addUser
{
    my ($self, $user) = @_;

    # rencode passwords
    if ($user->{passwords}) {
        my @pass = map { decode_base64($_) } @{$user->{passwords}};
        $user->{passwords} = \@pass;
    }

    my $parent = $self->{usersMod}->objectFromDN($user->{parentDN});
    delete $user->{parentDN};
    $user->{parent} = $parent;
    EBox::Users::User->create(%{$user});

    return $self->_soapResult(0);
}

sub modifyUser
{
    my ($self, $userinfo) = @_;

    my $user = new EBox::Users::User(dn => $userinfo->{dn});
    $user->set('cn', $userinfo->{fullname}, 1);
    $user->set('givenname', $userinfo->{givenname}, 1);
    $user->set('initials', $userinfo->{initials}, 1);
    $user->set('sn', $userinfo->{surname}, 1);
    $user->setDisabled($userinfo->{isDisabled}, 1);
    my @optionalAttributes = ('displayname', 'description', 'mail');
    foreach my $item (@optionalAttributes) {
        if ($userinfo->{$item}) {
            $user->set($item, $userinfo->{$item}, 1);
        } else {
            $user->delete($item, 1);
        }
    }
    $user->set('uidNumber', $userinfo->{uidNumber}, 1);

    if ($userinfo->{password}) {
        $user->changePassword($userinfo->{password}, 1);
    }
    if ($userinfo->{passwords}) {
        # rencode passwords
        my @pass = map { decode_base64($_) } @{$userinfo->{passwords}};
        $user->setPasswordFromHashes(\@pass, 1);
    }

    $user->save();

    return $self->_soapResult(0);
}

sub delUser
{
    my ($self, $dn) = @_;

    my $user = new EBox::Users::User(dn => $dn);
    $user->deleteObject();

    return $self->_soapResult(0);
}

sub addGroup
{
    my ($self, $group) = @_;

    my $parent = $self->{usersMod}->objectFromDN($group->{parentDN});
    delete $group->{parentDN};
    $group->{parent} = $parent;
    EBox::Users::Group->create(%{$group});

    return $self->_soapResult(0);
}

sub modifyGroup
{
    my ($self, $groupinfo) = @_;

    my $group = new EBox::Users::Group(dn => $groupinfo->{dn});
    $group->set('member', $groupinfo->{members}, 1);
    $group->set('description', $groupinfo->{description}, 1);
    $group->set('mail', $groupinfo->{mail}, 1);
    $group->set('gidNumber', $groupinfo->{gidNumber}, 1);
    $group->setSecurityGroup($groupinfo->{isSecurityGroup}, 1);

    $group->save();

    return $self->_soapResult(0);
}

sub delGroup
{
    my ($self, $dn) = @_;

    my $group = new EBox::Users::Group(dn => $dn);
    $group->deleteObject();

    return $self->_soapResult(0);
}

# Method: URI
#
# Overrides:
#
#      <EBox::RemoteServices::Server::Base>
#
sub URI {
    return 'urn:Users/Slave';
}

# Method: _soapResult
#
#    Serialise SOAP result to be WSDL complaint
#
# Parameters:
#
#    retData - the returned data
#
sub _soapResult
{
    my ($class, $retData) = @_;

    my $trace = new Devel::StackTrace();
    if ($trace->frame(2)->package() eq 'SOAP::Server' ) {
        $SOAP::Constants::NS_SL_PERLTYPE = $class->URI();
        return SOAP::Data->name('return', $retData);
    } else {
        return $retData;
    }

}

1;
