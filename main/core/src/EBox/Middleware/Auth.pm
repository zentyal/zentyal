# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
#
# Based on Plack::Middleware::Auth::Form Copyright (c) 2011 by Zbigniew Lukasiak <zby@cpan.org>.
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

package EBox::Middleware::Auth;
use base qw(Plack::Middleware);

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::Lock;

use Crypt::Rijndael;
use Digest::MD5;
use Fcntl qw(:flock);
use MIME::Base64;
use Plack::Request;
use Plack::Util::Accessor qw( auth_type app_name store_passwd );
use TryCatch::Lite;

# By now, the expiration time for session is hardcoded here
use constant EXPIRE => 3600; #In seconds  1h
# By now, the expiration time for a script session
use constant MAX_SCRIPT_SESSION => 10; # In seconds
use constant AUTH_PAM  => 1;
use constant AUTH_LDAP => 2;


sub prepare_app {
    my ($self) = @_;

    unless ($self->app_name) {
        throw EBox::Exceptions::Internal('app_name must be set');
    }
    if ($self->auth_type) {
        if (lc ($self->auth_type) eq 'pam') {
            $self->{auth_type} = AUTH_PAM;
        } elsif (lc ($self->auth_type) eq 'ldap') {
            $self->{auth_type} = AUTH_LDAP;
        } else {
            throw EBox::Exceptions::Internal('Unknown auth_type: "' . $self->auth_type . '"');
        }
    } else {
        $self->{auth_type} = AUTH_LDAP;
    }
}

sub _cleansession # (env)
{
    my ($env) = @_;

    if (exists $env->{'psgix.session'}) {
        delete $env->{'psgix.session'}{user_id};
        delete $env->{'psgix.session'}{last_time};
    }
}


sub _timeExpired
{
    my ($last_time) = @_;

    my $expires = $last_time + EXPIRE;

    my $expired = (time() > $expires);
    return $expired;
}

# FIXME: workaround to avoid apache segfault after TryCatch migration
#        when importing EBox::Global directly on EBox::Auth
#
#        EBox::Global is Class::Singleton so it must be
#        related with that
#
sub _global
{
    eval 'use EBox::Global';
    return EBox::Global->getInstance();
}

# Method: _actionScriptSession
#
#       Check whether a script session is already opened or not
#
# Returns:
#
#       Boolean - indicate if a script session is already opened
#
sub _actionScriptSession
{

    my ($self) = @_;

    # The script session filehandle
    my $scriptSessionFile;

    unless (-e EBox::Config->scriptSession()) {
        return undef;
    }

    # Trying to open the script sid
    unless (open ($scriptSessionFile, '<', EBox::Config->scriptSession())) {
        throw EBox::Exceptions::Internal('Could not open ' .  EBox::Config->scriptSession());
    }

    # Lock in shared mode
    unless (flock ($scriptSessionFile, LOCK_SH)) {
        throw EBox::Exceptions::Lock($self);
    }

    # The file structure is the following:
    # TIMESTAMP
    my ($timeStamp) = <$scriptSessionFile>;

    # Release the lock and close the file
    flock ($scriptSessionFile, LOCK_UN);
    close ($scriptSessionFile);

    # time() return the # of seconds since an epoch (1 Jan 1970
    # typically)

    my $expireTime = $timeStamp + MAX_SCRIPT_SESSION;
    return ($expireTime >= time());
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
sub _validateSession {
    my ($self, $env) = @_;

    my $global = $self->_global();

    unless ((exists $env->{'psgix.session'}{last_time}) and
            (exists $env->{'psgix.session'}{user_id})) {
        # The session is not valid.
        return 0;
    }

    my $last_time = $env->{'psgix.session'}{last_time};
    my $user = $env->{'psgix.session'}{user_id};

    my $expired =  _timeExpired($last_time);

    if ($self->_actionScriptSession()) {
        $env->{'psgix.session'}{AuthReason} = 'Script active';
        _cleansession($env);
    } elsif (not $expired) {
        # Increase the last time this session was valid.
        $env->{'psgix.session'}{last_time} = time();
        my $audit = $global->modInstance('audit');
        $audit->setUsername($user);
        return 1;
    } elsif ($expired) {
        my $audit = $global->modInstance('audit');
        my $ip = $env->{'REMOTE_ADDR'};
        $audit->logSessionEvent($user, $ip, 'expired');

        $env->{'psgix.session'}{AuthReason} = 'Expired';
        _cleansession($env);
    } else {
        # XXX: Review this code path. Seems to be dead code...
        $env->{'psgix.session'}{AuthReason} = 'Already';
    }

    return 0;
}

# Method: checkValidUser
#
#       Check with PAM if the user/password provided is of a valid admin
#
# Parameters:
#
#       username - string containing the user name
#       password - string containing the plain password
#       env      - Plack enviroment (OPTIONAL). Used by the LDAP validation to store the user DN.
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
sub checkValidUser
{
    my ($self, $username, $password, $env) = @_;

    my $auth;
    if ($self->{auth_type} == AUTH_PAM) {
        use Authen::Simple::PAM;

        $auth = new Authen::Simple::PAM(
            service => 'zentyal',
            log     => EBox->logger()
        );

        return $auth->authenticate($username, $password);
    } elsif ($self->{auth_type} == AUTH_LDAP) {
        use Authen::Simple::LDAP;
        use EBox::Ldap;

        my $ldap = EBox::Ldap->instance();
        my $baseDN = $ldap->dn();
        $ldap->clearConn();

        my $filter = "(&(objectclass=posixAccount)(uid=%s))";
        my $scope = 'sub';
        $auth = new Authen::Simple::LDAP(
            host => $ldap->url(),
            basedn => $baseDN,
            filter => $filter,
            scope  => $scope,
            log    => EBox->logger()
        );

        if ($auth->authenticate($username, $password)) {
            if (defined $env) {
                my $args = {
                    base => $baseDN,
                    filter => sprintf ($filter, $username),
                    scope => $sub,
                };
                my $search = $ldap->search($args);
                my $userDN = $search->entry(0)->dn();
                $env->{'psgix.session'}{userDN} = $userDN;
            }
            return 1;
        } else {
            return 0;
        }
    } else {
        throw EBox::Exceptions::Internal("Don't know the auth_type to use");
    }

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

sub _login
{
    my ($self, $env) = @_;

    if ($env->{REQUEST_METHOD} eq 'POST') {
        my $params = new Plack::Request($env)->parameters;
        my $user_id;

        my $log = EBox->logger();
        if ($self->_actionScriptSession()) {
            $log->warn('Failed login since a script session is opened');
            $env->{'psgix.session'}{AuthReason} = 'Script active';
            return $self->app->($env);
        }

        my $ip = $env->{'REMOTE_ADDR'};
        my $audit = $self->_global()->modInstance('audit');
        my $redir_to = $params->get('destination');
        my $user = $params->get('credential_0');
        my $password = $params->get('credential_1');
        # TODO: Expand to support Remote's SSL login.
        if ($self->checkValidUser($user, $password, $env)) {
            $env->{'psgix.session.options'}->{change_id}++;
            $env->{'psgix.session'}{user_id} = $user;
            if ($self->store_passwd) {
                my $key = _randomKey();
                $env->{'psgix.session'}{key} = $key;
                $env->{'psgix.session'}{passwd} = _cipherPassword($password, $key);
            }
            $env->{'psgix.session'}{last_time} = time();
            $audit->logSessionEvent($user, $ip, 'login');
            my $tmp_redir = delete $env->{'psgix.session'}{redir_to};
            unless (defined($redir_to)){
                $redir_to = $tmp_redir;
                if (URI->new($redir_to)->path eq $env->{PATH_INFO}) {
                    $redir_to = '/'
                }
            }
            return [
                302,
                [Location => $redir_to],
                ["<html><body><a href=\"$redir_to\">Back</a></body></html>"]
            ];
        } else {
            $env->{'psgix.session'}{AuthReason} = 'Incorrect password';
            _cleansession($env);
            $log->warn("Failed login from: $ip");
            $audit->logSessionEvent($user, $ip, 'fail');
        }
    }
    # Leave Zentyal application to print the login form with any error that may exist.
    return $self->app->($env);
}

sub _logout
{
    my ($self, $env) = @_;

    if($env->{REQUEST_METHOD} eq 'POST') {
        my $audit = $self->_global()->modInstance('audit');
        my $ip = $env->{'REMOTE_ADDR'};
        my $user = $env->{'psgix.session'}{user_id};
        $audit->logSessionEvent($user, $ip, 'logout');
        my $ret = $self->app->($env);
        _cleansession($env);
        return $ret;
    } else {
        # The workflow has been manipulated to reach this form, ignore it and redirect to the main page.
        my $redir_to = '/';
        return [
            303,
            [Location => $redir_to],
            ["<html><body><a href=\"$redir_to\">Back</a></body></html>"]
        ];
    }
}

# Method: call
#
#   Handles validation of credentials to allow access to Zentyal.
#
# Overrides: <Plack::Middleware::call>
#
sub call
{
    my ($self, $env) = @_;

    my $path = $env->{PATH_INFO};
    $env->{'psgix.session'}{app} = $self->app_name;

    if ($path eq '/Login/Index') {
        $self->_login($env);
    } elsif ($path eq '/Logout/Logout') {
        # We get here from Logout/Index, once the logout is confirmed.
        $self->_logout($env);
    } elsif ($self->_validateSession($env)) {
        delete $env->{'psgix.session'}{AuthReason};
        return $self->app->($env);
    } else {
        # Store in session where should we return after login.
        $env->{'psgix.session'}{'redir_to'} = $path;

        # Require authentication, redirect to the login form.
        my $login_url = '/Login/Index';
        return [
            302,
            [Location => $login_url],
            ["<html><body><a href=\"$login_url\">You need to authenticate first</a></body></html>"]
        ];
    }
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
        throw EBox::Exceptions::External('The password must be at least 6 characters long');
    }

    open(my $pipe, "|/usr/bin/sudo /usr/sbin/chpasswd") or
        throw EBox::Exceptions::Internal("Could not change password: $!");

    print $pipe "$username:$password\n";
    close($pipe);
}

## Remote access constants
#use constant CC_USER => '__remote_access__';

## Method: loginCC
##
##      Login from Control Center, which is different if the
##      passwordless option is activated
##
## Parameters:
##
##      request - <Apache2::RequestRec> the HTTP request
##
## Return:
##
##     the same response as <Apache2::AuthCookie::login> gives back
##
#sub loginCC
#{
#    my ($self, $req) = @_;
#
#    if ( $self->recognize_user($req) == OK ) {
#        my $retVal = $self->authenticate($req);
#        if ($req->uri() =~ m:^/ebox:) {
#            $req->headers_out()->set('Location' => '/');
#            return HTTP_MOVED_TEMPORARILY;
#        }
#        return $retVal;
#    } else {
#        my $global = $self->_global();
#        if ($global->modExists('remoteservices')) {
#            my $remoteServMod = $global->modInstance('remoteservices');
#            if ( $remoteServMod->eBoxSubscribed()
#                 and $remoteServMod->model('AccessSettings')->passwordlessValue()) {
#                # Do what login does
#                my $sessionKey = $self->authen_cred($req, CC_USER, '', 1);
#                $self->send_cookie($req, $sessionKey);
#                $self->handle_cache($req);
#                $req->headers_out()->set('Location' => '/');
#                return HTTP_MOVED_TEMPORARILY;
#            }
#        }
#        EBox::initLogger('eboxlog.conf');
#        EBox::CGI::Run->run('/Login/Index', 'EBox');
#        return OK;
#    }
#}
#

1;
