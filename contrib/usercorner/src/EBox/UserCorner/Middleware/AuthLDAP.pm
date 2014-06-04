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

package EBox::UserCorner::Middleware::AuthLDAP;
use base qw(EBox::Middleware::Auth);

use EBox;
use EBox::Exceptions::Internal;
use EBox::Ldap;

use Authen::Simple::LDAP;
use Crypt::Rijndael;
use Digest::MD5;
use MIME::Base64;


# Method: _cleanSession
#
#   Cleans the session and invalidates any existing credentials from it.
#
# Parameters:
#
#   env - Hash ref the PSGI enviroment dictionary.
#
# Overrides: <EBox::Middleware::Auth::_cleanSession>
#
sub _cleanSession
{
    my ($class, $env) = @_;

    if (exists $env->{'psgix.session'}) {
        delete $env->{'psgix.session'}{userDN};
        delete $env->{'psgix.session'}{key};
        delete $env->{'psgix.session'}{passwd};
    }
    $class->SUPER::_cleanSession();
}

# Method: _validateSession
#
#   Validate whether there is an existing valid session.
#
# Parameters:
#
#   env - Hash ref the PSGI enviroment dictionary.
#
# Returns:
#
#   boolean - Whether current session is valid or not.
#
# Overrides: <EBox::Middleware::Auth::_validateSession>
#
sub _validateSession {
    my ($self, $env) = @_;

    unless (defined $env) {
        throw EBox::Exceptions::MissingArgument("env");
    }

    unless ((exists $env->{'psgix.session'}{userDN}) and
            (exists $env->{'psgix.session'}{key}) and
            (exists $env->{'psgix.session'}{passwd})) {
        # The session is not valid.
        return 0;
    }
    $self->SUPER::_validateSession($env);
}

sub _randomKey
{
    my $rndStr;
    for my $i (1..64) {
        $rndStr .= rand (2**32);
    }

    my $md5 = Digest::MD5->new();
    $md5->add($rndStr);
    return $md5->hexdigest();
}

sub _cipherPassword
{
    my ($passwd, $key) = @_;

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());

    my $len = length($passwd);
    my $newlen = (int (($len - 1) / 16) + 1) * 16;

    $passwd = $passwd . ("\0" x ($newlen - $len));

    my $cryptedpass = $cipher->encrypt($passwd);
    return MIME::Base64::encode($cryptedpass, '');
}

# Method: checkValidUser
#
#   Check with LDAP if the user/password provided is of a valid admin. Stores in the session the userDN and cypher
#   password to allow LDAP usage later.
#
# Parameters:
#
#       username - string containing the user name
#       password - string containing the plain password
#       env      - Plack enviroment (OPTIONAL). Used by the LDAP validation to store the user DN and password.
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
sub checkValidUser
{
    my ($self, $username, $password, $env) = @_;

    my $ldap = EBox::Ldap->instance();
    my $baseDN = $ldap->dn();
    my $binddn = EBox::UserCorner::roRootDn();
    my $bindpw = EBox::UserCorner::getRoPassword();

    my $filter = "(&(objectclass=posixAccount)(uid=%s))";
    my $scope = 'sub';
    my $auth = new Authen::Simple::LDAP(
        binddn => $binddn,
        bindpw => $bindpw,
        host   => $ldap->url(),
        basedn => $baseDN,
        filter => $filter,
        scope  => $scope,
        log    => EBox->logger()
    );

    my $userDN = $auth->authenticate($username, $password);
    if ($userDN) {
        if (defined $env) {
            $env->{'psgix.session'}{userDN} = $userDN;
            my $key = _randomKey();
            $env->{'psgix.session'}{key} = $key;
            $env->{'psgix.session'}{passwd} = _cipherPassword($password, $key);
        }
    }
    $ldap->clearConn();
    return $userDN;
}

# Method: sessionPassword
#
#   Return the stored password in the session if there is no password stored throws EBox::Exceptions::Internal
#   exception.
#
# Arguments:
#
#   request  - Plack::Request The request object.
#
# Return:
#   String - The clear text password provided for the login.
#
# Raises:
#
#   <EBox::Exceptions::Internal>: If there is no previous password stored in the session.
#
sub sessionPassword
{
    my ($self, $request) = @_;

    my $session = $request->session();

    unless ((defined $session->{key}) and (defined $session->{passwd})) {
        throw EBox::Exceptions::Internal("There is no password stored");
    }

    my $cipher = Crypt::Rijndael->new($session->{key}, Crypt::Rijndael::MODE_CBC());

    my $decodedcryptedpass = MIME::Base64::decode($session->{passwd});
    my $pass = $cipher->decrypt($decodedcryptedpass);
    $pass =~ tr/\x00//d;
    return $pass;
}

# Method: updateSessionPassword
#
#   Update the stored password in the session if there is no password stored throws <EBox::Exceptions::Internal>
#   exception.
#
# Arguments:
#
#   request  - Plack::Request The request object.
#   password - String The new password to store in the session.
#
# Raises:
#
#   <EBox::Exceptions::Internal>: If there is no previous password stored in the session.
#
sub updateSessionPassword
{
    my ($self, $request, $password) = @_;

    my $session = $request->session();

    unless ((defined $session->{key}) and (defined $session->{passwd})) {
        throw EBox::Exceptions::Internal("There is no previous password stored!");
    }

    my $key = $session->{key};
    $session->{passwd} = _cipherPassword($password, $key);
}

1;
