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

package EBox::RemoteServices::Desktop::Subscription;

use strict;
use warnings;

use EBox::RemoteServices::Cred;

# Method: subscribe
#
#   Perform a subscription
#
# Returns:
#
#   Hash ref containing:
#       uuid - uuid assigned to the subscribed desktop
#       password - password for that desktop
#
sub subscribe
{
    my $cred = new EBox::RemoteServices::Cred();
    my $ret = $cred->RESTClient()->POST('/v1/desktops/')->data();
    return {
        'uuid'      => $ret->{'uuid'},
        'password'  => $ret->{'secret'},
    };
}

1;
