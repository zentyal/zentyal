#!/usr/bin/perl -w

# Copyright (C) 2009 eBox Technologies S.L.
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

# Class: EBox::UsersAndGroups::UserUpdater
#
#      This is a WS server to receive notifications from a master eBox
#      when users are added or removedj
#

package EBox::UsersAndGroups::UserUpdater;

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;
use EBox::Config;
use EBox::Global;

use Devel::StackTrace;
use SOAP::Lite;

# Group: Public class methods

# Method: addUser
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
sub addUser
{
    my ($class, $user, $password) = @_;

    my $users = EBox::Global->modInstance('users');
    $users->waitSync();
    $users->rewriteObjectClasses("uid=$user," . $users->usersDn);
    $users->initUser($user, $password);

    return $class->_soapResult(0);
}

sub addGroup
{
    my ($class, $group) = @_;

    my $users = EBox::Global->modInstance('users');
    $users->waitSync();
    $users->rewriteObjectClasses("cn=$group," . $users->groupsDn);
    $users->initGroup($group);

    return $class->_soapResult(0);
}

sub modifyUser
{
    my ($class, $user) = @_;

    my $users = EBox::Global->modInstance('users');
    $users->updateUser($user);

    return $class->_soapResult(0);
}

sub delUser
{
    my ($class, $user) = @_;

    my $users = EBox::Global->modInstance('users');
    $users->delUserSlave($user);

    return $class->_soapResult(0);
}

# Method: URI
#
# Overrides:
#
#      <EBox::RemoteServices::Server::Base>
#
sub URI {
    return 'urn:EBox/Users';
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
