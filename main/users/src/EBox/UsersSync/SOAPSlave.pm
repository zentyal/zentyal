# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::UsersSync::SOAPSlave;

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;
use EBox::Config;
use EBox::Global;

use Devel::StackTrace;
use SOAP::Lite;
use MIME::Base64;

use EBox::UsersAndGroups::User;
use EBox::UsersAndGroups::Group;

# Group: Public class methods

sub addUser
{
    my ($self, $user) = @_;

    # rencode passwords
    if ($user->{passwords}) {
        my @pass = map { decode_base64($_) } @{$user->{passwords}};
        $user->{passwords} = \@pass;
    }

    EBox::UsersAndGroups::User->create($user);

    return $self->_soapResult(0);
}

sub modifyUser
{
    my ($class, $userinfo) = @_;

    my $user = new EBox::UsersAndGroups::User(dn => $userinfo->{dn});
    $user->set('cn', $userinfo->{fullname}, 1);
    $user->set('sn', $userinfo->{surname}, 1);
    $user->set('givenname', $userinfo->{givenname}, 1);
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

    return $class->_soapResult(0);
}

sub delUser
{
    my ($self, $dn) = @_;

    my $user = new EBox::UsersAndGroups::User(dn => $dn);
    $user->deleteObject();

    return $self->_soapResult(0);
}

sub addGroup
{
    my ($class, $group) = @_;

    EBox::UsersAndGroups::Group->create($group->{name}, $group->{comment});

    return $class->_soapResult(0);
}

sub modifyGroup
{
    my ($self, $groupinfo) = @_;

    my $group = new EBox::UsersAndGroups::Group(dn => $groupinfo->{dn});
    $group->set('member', $groupinfo->{members});

    return 1;
}

sub delGroup
{
    my ($self, $dn) = @_;

    my $group = new EBox::UsersAndGroups::Group(dn => $dn);
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
