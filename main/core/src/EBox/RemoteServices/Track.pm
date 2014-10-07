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

package EBox::RemoteServices::Track;

# Track registered users

use URI;

# Constant
use constant GO_URL => 'https://go.pardot.com/l/24292/2013-10-28/261g7';

# Function: trackURL
#
#    Return the tracking URL for the newly created community users
#
# Parameters:
#
#    username - String the email address
#
#    newsletter - Boolean subscribed to the NL?
#
# Returns:
#
#    String
#
sub trackURL
{
    my ($username, $newsletter) = @_;

    my $data = { email => $username,
                 subscribed_newsletter => $newsletter };

    my $trackURI = new URI(GO_URL);
    $trackURI->query_form($data);
    return $trackURI->as_string();
}

1;
