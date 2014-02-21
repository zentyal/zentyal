# Copyright (C) 2012-2014 Zentyal S.L.
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

use warnings;
use strict;

package EBox::RemoteServices::RESTClient;

# Class: EBox::RemoteServices::RESTClient
#
#   Zentyal Cloud/Remote REST client. It provides a common
#   interface to access Zentyal Cloud/Remote services
#
use base 'EBox::RESTClient';

use v5.10;

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant SUBS_WIZARD_URL => '/Wizard?page=RemoteServices/Wizard/Subscription';

# Method: new
#
#   Zentyal Cloud/Remote REST client. It provides a common
#   interface to access Zentyal Cloud services
#
# Named parameters:
#
#   credentials - Hash ref containing the credentials required
#                 to access the given server
#                 It must contain the following keys:
#
#                    realm - String the realm
#                    username - String the username
#                    password - String the password
#
#                 (Optional)
#
#
sub new
{
    my ($class, %params) = @_;

    # Get the server from conf
    my $key = 'rs_api';

    # TODO: Use cloudDomain when available
    my $self = $class->SUPER::new(server => EBox::Config::configkey($key), %params);

    if ( exists $self->{credentials} and (not $self->{credentials}->{realm}) ) {
        $self->{credentials}->{realm} = 'Zentyal Cloud API';
    }

    return $self;
}


# Function: _invalidCredentialsMsg
#
#     Return the invalid credentials message
#
# Returns:
#
#     String - the message
#
sub _invalidCredentialsMsg
{
    my $forgottenURL = "https://remote.zentyal.com/reset/";
    return __x('User/email address and password do not match. Did you forget your password? '
               . 'You can reset it {ohp}here{closehref}. '
               . 'If you need a new account you can subscribe {openhref}here{closehref}.'
               , openhref  => '<a href="'. SUBS_WIZARD_URL . '" target="_blank">',
               ohp       => '<a href="' . $forgottenURL . '" target="_blank">',
               closehref => '</a>');

}

1;
