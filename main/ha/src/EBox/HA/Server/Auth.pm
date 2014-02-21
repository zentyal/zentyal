# Copyright (C) 2014 Zentyal S. L.
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

package EBox::HA::Server::Auth;

use EBox;
use EBox::Global;

# Class: EBox::HA::Server::Auth
#
#     Package to do whatever auth requires
#

# Function: authenticate
#
#    Function to determine if the given user/pass using HTTP auth basic
#    scheme is valid or not
#
# Parameters:
#
#    username - String
#    password - String
#    env      - PSGI environment
#
sub authenticate
{
    my ($username, $password, $env) = @_;

    my $roGlobal = EBox::Global->getInstance('readonly');
    my $currentSecret = $roGlobal->modInstance('ha')->userSecret();
    return ($currentSecret and ($password eq $currentSecret));
}

1;
