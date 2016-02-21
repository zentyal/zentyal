# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Middleware::AuthPAM;
use base qw(EBox::Middleware::Auth);

use EBox;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Gettext;

use Authen::Simple::PAM;
use TryCatch;


# Method: checkValidUser
#
#       Check with PAM if the user/password provided is of a valid admin.
#
# Parameters:
#
#       username - string containing the user name
#       password - string containing the plain password
#       env      - Plack enviroment (OPTIONAL).
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
# Overrides: <EBox::Middleware::Auth::checkValidUser>
#
sub checkValidUser
{
    my ($self, $username, $password, $env) = @_;

    my $auth;

    $auth = new Authen::Simple::PAM(
        service => 'zentyal',
        log     => EBox->logger()
    );

    return $auth->authenticate($username, $password);
}

# Method: setPassword
#
#       Changes the password of the given username
#
# Parameters:
#
#       username - username to change the password
#       password - string containing the plain password
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - when password cannot be changed
#   <EBox::Exceptions::External> - when password length is no
#                                  longer than 6 characters
#
sub setPassword
{
    my ($self, $username, $password) = @_;

    unless (length($password) > 5) {
        throw EBox::Exceptions::External(_('The password must be at least 6 characters long'));
    }

    open(my $pipe, "|/usr/bin/sudo /usr/sbin/chpasswd") or
        throw EBox::Exceptions::Internal("Could not change password: $!");

    print $pipe "$username:$password\n";
    close($pipe);
}

1;
