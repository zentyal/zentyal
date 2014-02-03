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

use Authen::Simple::PAM;
use Fcntl qw(:flock);
use Plack::Request;
use Plack::Util::Accessor qw( secure authenticator no_login_page after_logout ssl_port );

# By now, the expiration time for session is hardcoded here
use constant EXPIRE => 3600; #In seconds  1h
# By now, the expiration time for a script session
use constant MAX_SCRIPT_SESSION => 10; # In seconds


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
#   - env: The PSGI enviroment dictionary.
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
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
sub checkValidUser
{
    my ($self, $username, $password) = @_;

    my $pam = new Authen::Simple::PAM(service => 'zentyal');

    return $pam->authenticate($username, $password);
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
        if ($self->checkValidUser($user, $password)) {
            $env->{'psgix.session.options'}->{change_id}++;
            $env->{'psgix.session'}{user_id} = $user;
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
        _cleansession($env);
    }
    my $redir_to = 'Login/Index';
    return [
        303,
        [Location => $redir_to],
        ["<html><body><a href=\"$redir_to\">Back</a></body></html>"]
    ];
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

    # Workaround to be able to use Plack Session middleware with our Login
    # and Logout forms until we are a real Plack application.
    $env->{'zentyal.session'} = $env->{'psgix.session'};

    if ($path eq '/Login/Index') {
        $self->_login($env);
    } elsif ($path eq '/Logout/Index') {
    } elsif ($path eq '/Logout/Logout') {
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
# FIXME: Maybe this should be moved to some other place...
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
