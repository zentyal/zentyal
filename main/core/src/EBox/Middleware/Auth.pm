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
use EBox::Exceptions::Lock;

use Fcntl qw(:flock);
use JSON::XS;
use Plack::Request;
use Plack::Util::Accessor qw( app_name );
use TryCatch;
use URI;

# By now, the expiration time for session is hardcoded here
use constant EXPIRE => 3600; #In seconds  1h
# By now, the expiration time for a script session
use constant MAX_SCRIPT_SESSION => 10; # In seconds


sub prepare_app
{
    my ($self) = @_;

    unless ($self->app_name) {
        throw EBox::Exceptions::Internal('app_name must be set');
    }
}

# Method: _cleanSession
#
#   Cleans the session and invalidates any existing credentials from it.
#
# Parameters:
#
#   env - Hash ref the PSGI enviroment dictionary.
#
sub _cleanSession
{
    my ($class, $env) = @_;

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
# Parameters:
#
#       env - Hash ref the PSGI enviroment dictionary.
#
# Returns:
#
#       Boolean - indicate if a script session is already opened
#
sub _actionScriptSession
{
    my ($self, $env) = @_;

    # This is a request from a subapp?
    if ((exists $env->{'zentyal'}) and (exists $env->{'zentyal'}->{'webadminsubapp'})
        and ($env->{PATH_INFO} =~ /^$env->{'zentyal'}->{'webadminsubapp'}/)) {
        # Let the requests from the auth subapp to go
        return 0;
    }

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

    unless (defined $env) {
        throw EBox::Exceptions::MissingArgument("env");
    }

    unless ((exists $env->{'psgix.session'}{last_time}) and
            (exists $env->{'psgix.session'}{user_id})) {
        # The session is not valid.
        return 0;
    }

    my $last_time = $env->{'psgix.session'}{last_time};
    my $user = $env->{'psgix.session'}{user_id};

    my $expired =  _timeExpired($last_time);
    my $global;
    if ($self->app_name eq 'webadmin') {
        $global = $self->_global();
    }

    if ($self->_actionScriptSession($env)) {
        $env->{'psgix.session'}{AuthReason} = 'Script active';
        $self->_cleanSession($env);
    } elsif (not $expired) {
        # Increase the last time this session was valid.
        $env->{'psgix.session'}{last_time} = time();
        if ($self->app_name eq 'webadmin') {
            my $audit = $global->modInstance('audit');
            $audit->setUsername($user);
        }
        return 1;
    } elsif ($expired) {
        if ($self->app_name eq 'webadmin') {
            my $audit = $global->modInstance('audit');
            my $ip = $env->{'REMOTE_ADDR'};
            $audit->logSessionEvent($user, $ip, 'expired');
        }

        $env->{'psgix.session'}{AuthReason} = 'Expired';
        $self->_cleanSession($env);
    } else {
        # XXX: Review this code path. Seems to be dead code...
        $env->{'psgix.session'}{AuthReason} = 'Already';
    }

    return 0;
}

# Method: checkValidUser
#
#   Check whether the user/password provided is of a valid admin. This method should be overrided in a subclass
#   to implement different kinds of user validation.
#
# Parameters:
#
#       username - string containing the user name
#       password - string containing the plain password
#       env      - Plack enviroment.
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
sub checkValidUser
{
    my ($self, $username, $password, $env) = @_;

    return 0;
}

sub _login
{
    my ($self, $env) = @_;

    if ($env->{REQUEST_METHOD} eq 'POST') {
        my $params = new Plack::Request($env)->parameters;
        my $user_id;

        my $log = EBox->logger();
        if ($self->_actionScriptSession($env)) {
            $log->warn('Failed login since a script session is opened');
            $env->{'psgix.session'}{AuthReason} = 'Script active';
            return $self->app->($env);
        }

        my $ip = $env->{'REMOTE_ADDR'};
        my $audit;
        if ($self->app_name eq 'webadmin') {
            $audit = $self->_global()->modInstance('audit');
        }
        my $redir_to = $params->get('destination');
        my $user = $params->get('credential_0');
        my $password = $params->get('credential_1');
        # TODO: Expand to support Remote's SSL login.
        if ($self->checkValidUser($user, $password, $env)) {
            $env->{'psgix.session.options'}->{change_id}++;
            $env->{'psgix.session'}{user_id} = $user;
            $env->{'psgix.session'}{last_time} = time();
            if ($self->app_name eq 'webadmin') {
                $audit->logSessionEvent($user, $ip, 'login');
            }
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
            $self->_cleanSession($env);
            $log->warn("Failed login from: $ip");
            if ($self->app_name eq 'webadmin') {
                $audit->logSessionEvent($user, $ip, 'fail');
            }
        }
    }
    # Leave Zentyal application to print the login form with any error that may exist.
    return $self->app->($env);
}

sub _logout
{
    my ($self, $env) = @_;

    if($env->{REQUEST_METHOD} eq 'POST') {
        if ($self->app_name eq 'webadmin') {
            my $audit = $self->_global()->modInstance('audit');
            my $ip = $env->{'REMOTE_ADDR'};
            my $user = $env->{'psgix.session'}{user_id};
            $audit->logSessionEvent($user, $ip, 'logout');
        }
        my $ret = $self->app->($env);
        $self->_cleanSession($env);
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

# Redirect properly to the login page
sub _redirectToLogin
{
    my ($self, $env) = @_;

    my $ajaxRequest = (exists $env->{HTTP_X_REQUESTED_WITH} and $env->{HTTP_X_REQUESTED_WITH} eq 'XMLHttpRequest');
    my $path;
    if ($ajaxRequest and $env->{REQUEST_METHOD} ne 'GET' and exists $env->{HTTP_REFERER}) {
        my $uri = new URI($env->{HTTP_REFERER});
        $path = $uri->path();  # We assume the referer is always another Zentyal page
    } else {
        $path = $env->{REQUEST_URI};
    }

    # Store in session where we should return after login.
    $env->{'psgix.session'}{'redir_to'} = $path;

    my $login_url = '/Login/Index';
    if ($ajaxRequest) {
        return [
            200,
            undef,
            [ JSON::XS->new()->encode({'success' => 1, 'redirect' => $login_url}) ]
           ];
    } else {
        return [
            302,
            [Location => $login_url],
            ["<html><body><a href=\"$login_url\">You need to authenticate first</a></body></html>"]
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
        # Require authentication, redirect to the login form.
        return $self->_redirectToLogin($env);
    }
}

1;
