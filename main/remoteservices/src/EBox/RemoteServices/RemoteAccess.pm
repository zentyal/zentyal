#!/usr/bin/perl -w

# Copyright (C) 2014 Zentyal S.L.
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

package EBox::RemoteServices::RemoteAccess;

# Class: EBox::RemoteServices::RemoteAccess
#
#      PSGI sub application to handle the remote access.
#

use EBox;
use EBox::Global;

# Constants
use constant REMOTE_ACCESS_COOKIE_NAME => 'EBox_Services_Remote_Access';


# Function: psgiApp
#
#   PSGI sub application to perform the passwordless access if allowed
#
# Parameters:
#
#    env - Hash ref the Plack environment from the request
#
sub psgiApp
{
    return [302, [Location => '/'], ['Remote access granted']];
}

# Function: validate
#
# Parameters:
#
#    env - Hash ref the Plack environment from the request
#
sub validate
{
    my ($env) = @_;

    my $raCookieName = REMOTE_ACCESS_COOKIE_NAME;

    if (($env->{HTTP_X_SSL_CLIENT_USED})  # Only SSL requests
        and (exists $env->{'plack.cookie.parsed'}->{$raCookieName})) {
        EBox::init();
        my $rs = EBox::Global->getInstance(1)->modInstance('remoteservices');
        if ($env->{HTTP_X_SSL_CLIENT_O} eq $rs->caDomain()) {
            return ($rs->eBoxSubscribed() and $rs->model('AccessSettings')->passwordlessValue());
        }
    }
    return 0;
}

1;
