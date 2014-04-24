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

package EBox::CaptivePortal::Middleware::AuthFile;
use base qw(EBox::Middleware::Auth);

use EBox;
use EBox::CaptivePortal;
use EBox::Config;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::NetWrappers qw(ip_mac);

use File::Basename;
use Plack::Request;
use Plack::Session::Store::File;
use TryCatch::Lite;

use constant USERSFILE => '/var/lib/zentyal-captiveportal/users.conf';

my $_parsedUsers = undef;

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

    my $user = userFromFile($username);

    my $isValid = 0;
    if ($user) {
        my $hash = $user->{hash};
        $isValid = ((crypt ($password, $hash)) eq $hash);
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

    my $ret = $self->app->($env);
    $self->_cleanSession($env);

    if ((not exists $env->{'plack.cookie.parsed'}) or
        (not exists $env->{'plack.cookie.parsed'}->{ 'plack_session'})) {
        throw EBox::Exceptions::Internal("Not auth plack cookie");
    }

    my $sid = $env->{'plack.cookie.parsed'}->{ 'plack_session'};
    EBox::CaptivePortal::Middleware::AuthFile::removeSession($sid);

    $env->{'psgix.session.options'}->{'no_store'} = 1;

    # monitored logout file
    my $notifyCmd = "echo $sid > " . EBox::CaptivePortal->LOGOUT_FILE;
    system($notifyCmd);

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

    my $sessionFile =  EBox::CaptivePortal->SIDS_DIR . $sid;

     my $store = new Plack::Session::Store::File(dir => EBox::CaptivePortal->SIDS_DIR);
     unless ($store->remove($sid)) {
         throw EBox::Exceptions::External(__x("Couldn't remove session file for {id}", id => $sid));
     }
}

# Function: hashPassword
#
#   Return a hashed version of the give password salted with a random salt of 4 characters.
#
# Parameters:
#   - password - String the password to process.
#
sub hashPassword
{
    my ($password) = @_;

    my $salt = chr(65+rand(27)).chr(65+rand(27));
    return (crypt ($password, $salt));
}



sub userFromFile
{
    my ($username) = @_;

    my $FH;
    unless (open $FH, USERSFILE) {
        EBox::error("Cannot open user file " . USERSFILE);
        return undef;
    }

    my $user;
    while (my $line = <$FH>) {
        chomp $line;
        unless ($line) {
            next;
        }
        my ($name, $hash, $fullname, $quota) = split("\t", $line);
        if ($name eq $username) {
            $user = {  hash => $hash };
            if ((defined $fullname) and ($fullname ne '')) {
                $user->{fullname} = $fullname;
            }
            if ((defined $quota) and ($quota ne '')) {
                $user->{quota} = $quota;
            }
            last;
        }
    }

    unless (close $FH) {
        throw EBox::Exceptions::Internal('Cannot properly close ' . USERSFILE);
    }

    return $user;
}

sub allUsersFromFile
{
    my $users = {};
    my $FH;
    unless (open $FH, USERSFILE) {
        return $users;
    }
    while (my $line = <$FH>) {
        chomp $line;
        unless ($line) {
            next;
        }
        my ($username, $hash, $fullname, $quota) = split("\t", $line);
        $users->{$username} = {hash => $hash};
        $users->{$username}->{fullname} = $fullname if ((defined $fullname) and ($fullname ne ''));
        $users->{$username}->{quota} = $quota if ((defined $quota) and ($quota ne ''));
    }

    unless (close $FH) {
        throw EBox::Exceptions::Internal('Cannot properly close ' . USERSFILE);
    }

    return $users;
}

# Function: parseUsersFile
#
#   Parses the captiveportal users file from disk and returns its content.
#
# Returns:
#
#   Hash reference with this format:
#
#       {
#           'usernameWithCustomQuota' => {
#               hash     => HASH_PASSWORD_STRING,
#               quota    => 10240,
#           },
#           'usernameWithDefaultQuota' => {
#               hash     => HASH_PASSWORD_STRING,
#               fullname => 'Foo Bar',
#           },
#           ...
#       }
#   or {} if the file is not available.
#
sub parseUsersFileDisabled
{
    if (defined $_parsedUsers) {
        return $_parsedUsers;
    }

    my $users = {};
    my $FH;
    unless (open $FH, USERSFILE) {
        return $users;
    }
    while (my $line = <$FH>) {
        chomp $line;
        unless ($line) {
            next;
        }
        my ($username, $hash, $fullname, $quota) = split("\t", $line);
        $users->{$username} = {hash => $hash};
        $users->{$username}->{fullname} = $fullname if ((defined $fullname) and ($fullname ne ''));
        $users->{$username}->{quota} = $quota if ((defined $quota) and ($quota ne ''));
    }

    unless (close $FH) {
        throw EBox::Exceptions::Internal('Cannot properly close ' . USERSFILE);
    }

    $_parsedUsers = $users;
    return $_parsedUsers;
}

# Function: writeUsersFile
#
#   Dumps a list of captiveportal users into disk.
#
# Parameters:
#
#   users - Hash reference with this format:
#
#       {
#           'usernameWithCustomQuota' => {
#               hash     => HASH_PASSWORD_STRING,
#               quota    => 10240,
#           },
#           'usernameWithDefaultQuota' => {
#               hash     => HASH_PASSWORD_STRING,
#               fullname => 'Foo Bar',
#           },
#           ...
#       }
#
sub writeUsersFile
{
    my ($users) = @_;

    if (defined $_parsedUsers) {
        # Remove the cache.
        $_parsedUsers = undef;
    }

    my $defaults = {
        uid  => EBox::CaptivePortal::CAPTIVE_USER(),
        gid  => EBox::CaptivePortal::CAPTIVE_GROUP(),
        mode => 660
    };

    my $data = '';
    foreach my $user (keys %{$users}) {
        my $username = $users->{$user};
        my $hash = $users->{$user}->{hash};
        my $quota = '';
        my $fullname = '';
        if (defined $users->{$user}->{quota}) {
            $quota = $users->{$user}->{quota};
        }
        if (defined $users->{$user}->{fullname}) {
            $fullname = $users->{$user}->{fullname};
        }
        $data .= "$user\t$hash\t$fullname\t$quota\n";
    }

    EBox::Module::Base::writeFile(USERSFILE, $data, $defaults)
}

1;
