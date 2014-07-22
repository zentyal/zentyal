# Copyright (C) 2011-2014 Zentyal S.L.
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

package EBox::CaptivePortal::Middleware::AuthLDAP;
use base qw(EBox::Middleware::Auth);

use EBox;
use EBox::CaptivePortal;
use EBox::Config;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::NetWrappers qw(ip_mac);

use Authen::Simple::LDAP;
use File::Basename;
use Plack::Request;
use Plack::Session::Store::File;
use TryCatch::Lite;


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
        delete $env->{'psgix.session'}{ip};
        delete $env->{'psgix.session'}{mac};
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

    my $isValid = $self->SUPER::_validateSession($env);
    if ($isValid) {
        # Update the IP from the client.
        my $request = new Plack::Request($env);
        $env->{'psgix.session'}{ip} = $request->address();
        $env->{'psgix.session'}{mac} = ip_mac($request->address());
    }
    return $isValid;
}

sub _checkLDAPPassword
{
    my ($self, $username, $password, $url, $bindDN, $groupDN) = @_;

    # Replace username in bind string.
    $bindDN =~ s/{USERNAME}/$username/g;
    my $filter;
    if ($groupDN) {
        $filter = "(&(memberOf=$groupDN)(uid=%s))";
    } else {
        $filter = "(uid=%s)";
    }
    my $scope = 'base';
    my $auth = new Authen::Simple::LDAP(
        binddn => $bindDN,
        bindpw => $password,
        host   => $url,
        basedn => $bindDN,
        filter => $filter,
        scope  => $scope,
        log    => EBox->logger()
    );

    return $auth->authenticate($username, $password);
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

    my $CONF_FILE = EBox::CaptivePortal->LDAP_CONF;

    my $url = EBox::Config::configkeyFromFile('ldap_url', $CONF_FILE);
    my $bindDN = EBox::Config::configkeyFromFile('ldap_bindstring', $CONF_FILE);
    my $groupDN = EBox::Config::configkeyFromFile('ldap_group', $CONF_FILE);

    my $isValid = 0;
    if ($self->_checkLDAPPassword($username, $password, $url, $bindDN, $groupDN)) {
        $isValid = 1;
    }

    unless ($isValid) {
        # Test secondary ldap if it exists in configuration file
        my $url2 = EBox::Config::configkeyFromFile('ldap2_url', $CONF_FILE);
        my $bindDN2 = EBox::Config::configkeyFromFile('ldap2_bindstring', $CONF_FILE);

        if (defined($url2) and defined($bindDN2) and
            $self->_checkLDAPPassword($username, $password, $url2, $bindDN2)) {
            $isValid = 1;
        }
    }

    my $request = new Plack::Request($env);
    if ($isValid) {
        # Store IP and mac address
        $env->{'psgix.session'}{ip} = $request->address();
        $env->{'psgix.session'}{mac} = ip_mac($request->address());
    } else {
        # not authorized
        EBox::warn("Failed login from: " . $request->address());
    }
    return $isValid;
}

sub _logout
{
    my ($self, $env) = @_;

    my $ret = $self->SUPER::_logout();

    if($env->{REQUEST_METHOD} eq 'POST') {
        # Wakeup captive daemon updating the access time of the Inotify2 monitored logout file
        system('cat ' . EBox::CaptivePortal->LOGOUT_FILE);
    }

    return $ret;
}

# Method: call
#
#   Handles validation of credentials to allow access to Zentyal.
#
# Overrides: <EBox::Middleware::Auth::call>
#
sub call
{
    my ($self, $env) = @_;

    my $path = $env->{PATH_INFO};
    $env->{'psgix.session'}{app} = $self->app_name;

    if ($path eq '/Login') {
        $self->_login($env);
    } elsif ($path eq '/Logout') {
        $self->_logout($env);
    } elsif ($self->_validateSession($env)) {
        delete $env->{'psgix.session'}{AuthReason};
        return $self->app->($env);
    } else {
        # Store in session where should we return after login.
        $env->{'psgix.session'}{'redir_to'} = $path;

        # Require authentication, redirect to the login form.
        my $login_url = '/Login';
        return [
            302,
            [Location => $login_url],
            ["<html><body><a href=\"$login_url\">You need to authenticate first</a></body></html>"]
        ];
    }
}

# Function: currentSessions
#
#   Current existing sessions array:
#
# Returns:
#
#   Array ref with this layout:
#
#   [
#      {
#          user => 'username',
#          ip   => 'X.X.X.X',
#          mac  => 'XX:XX:XX:XX:XX:XX', (optional, if known)
#          sid  => 'session id',
#          time => X,                   (last session update timestamp)
#      },
#      ...
#   ]
#
sub currentSessions
{
    my @sessions = ();
    my $store = new Plack::Session::Store::File(dir => EBox::CaptivePortal->SIDS_DIR);
    for my $sess_file (glob(EBox::CaptivePortal->SIDS_DIR . '*')) {
        my $sid = basename($sess_file);
        my $session = $store->fetch($sid);
        if ($session and (defined ($session->{user_id}))) {
            my %filteredSession = ();
            $filteredSession{sid} = $sid;
            $filteredSession{user} = $session->{user_id};
            $filteredSession{ip} = $session->{ip} if (defined ($session->{ip}));
            $filteredSession{mac} = $session->{mac} if (defined ($session->{mac}));
            $filteredSession{time} = $session->{last_time} if (defined ($session->{last_time}));
            push (@sessions, \%filteredSession);
        }
    }
    return \@sessions;
}

# Function: removeSession
#
#   Removes the session file for the given session id.
#
sub removeSession
{
    my ($sid) = @_;

    my $store = new Plack::Session::Store::File(dir => EBox::CaptivePortal->SIDS_DIR);
    unless ($store->remove($sid)) {
        throw EBox::Exceptions::External(_("Couldn't remove session file"));
    }
}

# Function: updateSession
#
#   Update session time and ip.
#
sub updateSession
{
    my ($sid, $ip, $time) = @_;

    unless (defined ($time)) {
        $time = time();
    }

    my $store = new Plack::Session::Store::File(dir => EBox::CaptivePortal->SIDS_DIR);
    my $session = $store->fetch($sid);
    unless ($session) {
        throw EBox::Exceptions::Internal("Session '$sid' doesn't exist");
    }
    $session->{last_time} = $time;
    $session->{ip} = $ip;
    $session->{mac} = ip_mac($ip);
    $store->store($sid, $session);
}

1;
