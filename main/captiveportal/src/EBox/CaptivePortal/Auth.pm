# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::CaptivePortal::Auth;
use base qw(Apache2::AuthCookie);

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use EBox::Ldap;
use EBox::NetWrappers qw(ip_mac);

use Crypt::Rijndael;
use Apache2::Connection;
use Apache2::RequestUtil;
use Apache2::Const qw(:common HTTP_FORBIDDEN HTTP_MOVED_TEMPORARILY);
use MIME::Base64;
use Digest::MD5;
use Fcntl qw(:flock);
use File::Basename;
use YAML::XS;
use TryCatch::Lite;

# Session files dir, +rw for captiveportal & zentyal
use constant UMASK => 0007; # (Bond, James Bond)

# Init logger
EBox::initLogger('captiveportal-log.conf');

# Method: _savesession
#
# Parameters:
#
#   - user name
#   - password
#   - ip: client ip
#   - session id: if the id is undef, it creates a new one
#   - key: key for rijndael, if sid is undef creates a new one
# Exceptions:
#   - Internal
#   - When session file cannot be opened to write
sub _savesession
{
    my ($user, $passwd, $ip, $sid, $key) = @_;

    if(not defined($sid)) {
        my $rndStr;
        for my $i (1..64) {
            $rndStr .= rand (2**32);
        }

        my $md5 = Digest::MD5->new();
        $md5->add($rndStr);
        $sid = $md5->hexdigest();

        for my $i (1..64) {
            $rndStr .= rand (2**32);
        }
        $md5 = Digest::MD5->new();
        $md5->add($rndStr);

        $key = $md5->hexdigest();
    }

    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC());

    my $len = length($passwd);
    my $newlen = (int(($len-1)/16) + 1) * 16;

    $passwd = $passwd . ("\0" x ($newlen - $len));

    my $cryptedpass = $cipher->encrypt($passwd);
    my $encodedcryptedpass = MIME::Base64::encode($cryptedpass, '');
    my $sidFile;
    my $filename = EBox::CaptivePortal->SIDS_DIR . $sid;
    umask(UMASK);
    unless (open($sidFile, '>', $filename)){
        throw EBox::Exceptions::Internal(
                "Could not open to write ".  $filename);
    }

    # Lock the file in exclusive mode
    flock($sidFile, LOCK_EX)
        or throw EBox::Exceptions::Lock('EBox::CaptivePortal::Auth');
    # Truncate the file after locking
    truncate($sidFile, 0);

    if (defined($sid)) {
        my $data = {};
        $data->{sid} = $sid;
        $data->{encodedcryptedpass} = $encodedcryptedpass;
        $data->{time} = time();
        $data->{user} = $user;
        $data->{ip} = $ip;
        $data->{mac} = ip_mac($ip);
        print $sidFile YAML::XS::Dump($data);
    }

    # Release the lock
    flock($sidFile, LOCK_UN);
    close($sidFile);

    return $sid . $key;
}

# update session time and ip
sub updateSession
{
    my ($sid, $ip, $time) = @_;

    defined($time) or $time = time();

    my $sidFile;
    my $sess_file = EBox::CaptivePortal->SIDS_DIR . $sid;
    unless (open ($sidFile, '+<', $sess_file)) {
        throw EBox::Exceptions::Internal("Could not open $sess_file");
    }
    # Lock in exclusive
    flock($sidFile, LOCK_EX)
        or throw EBox::Exceptions::Lock('EBox::CaptivePortal::Auth');

    my $sess_info = join('', <$sidFile>);

    # Truncate the file
    truncate($sidFile, 0);
    seek($sidFile, 0, 0);

    # Update session time and ip
    if (defined($sess_info)) {
        my $data = YAML::XS::Load($sess_info);
        $data->{time} = $time;
        $data->{ip} = $ip;
        $data->{mac} = ip_mac($ip);
        print $sidFile YAML::XS::Dump($data);
    }

    # Release the lock
    flock($sidFile, LOCK_UN);
    close($sidFile);
}

# Method: checkPassword
#
#   Check if a given password matches the stored
#
# Parameters:
#
#       user - string containing the user name
#       passwd - string containing the plain password
#
# Returns:
#
#       boolean - true if it's correct, otherwise false
#
# Exceptions:
#
#       <EBox::Exceptions::Internal> - when password's file cannot be opened
sub checkPassword # (user, password)
{
    my ($self, $user, $password) = @_;

    eval 'use EBox::CaptivePortal';

    my $CONF_FILE = EBox::CaptivePortal->LDAP_CONF;

    my $url = EBox::Config::configkeyFromFile('ldap_url', $CONF_FILE);
    my $bind = EBox::Config::configkeyFromFile('ldap_bindstring', $CONF_FILE);
    my $groupDN = EBox::Config::configkeyFromFile('ldap_group', $CONF_FILE);

    return 1 if ($self->_checkLdapPassword($user, $password, $url, $bind, $groupDN));

    # Test secondary ldap if it exists in configuration file
    my $url2 = EBox::Config::configkeyFromFile('ldap2_url', $CONF_FILE);
    my $bind2 = EBox::Config::configkeyFromFile('ldap2_bindstring', $CONF_FILE);

    if (defined($url2) and defined($bind2)) {
        return 1 if ($self->_checkLdapPassword($user, $password, $url2, $bind2));
    }

    # not authorized
    return 0;
}

sub _checkLdapPassword
{
    my ($self, $user, $password, $url, $bind, $groupDN) = @_;

    # replace usrename in bind string
    $bind =~ s/{USERNAME}/$user/g;
    my $authorized = 0;
    try {
        my $ldap = EBox::Ldap::safeConnect($url);
        EBox::Ldap::safeBind($ldap, $bind, $password);
        $authorized = 1; # auth ok
        if ($authorized and $groupDN) {
            # we have not finished
            $authorized = 0;
            # check also the group for the user
            my %attrs = (
                base => $bind,
                filter => "&(uid=$user)(memberOf=$groupDN)",
                scope => 'base'
            );
            my $result = $ldap->search(%attrs);
            $authorized = ($result->count > 0);
        }
    } catch {
        $authorized = 0; # auth failed
    }

    return $authorized;
}

# Method: authen_cred
#
#   Overriden method from <Apache2::AuthCookie>.
#
sub authen_cred  # (request, user, password)
{
    my ($self, $r, $user, $passwd) = @_;

    unless ($self->checkPassword($user, $passwd)) {
        my $ip  = $r->connection->remote_ip();
        EBox::warn("Failed login from: $ip");
        return;
    }

    return _savesession($user, $passwd, $r->connection->remote_ip());
}

# Method: authen_ses_key
#
#   Overriden method from <Apache2::AuthCookie>.
#
sub authen_ses_key  # (request, session_key)
{
    my ($self, $r, $session_data) = @_;

    my $session_key = substr($session_data, 0, 32);
    my $sidFile; # sid file handle

    my $user = undef;

    eval 'use EBox::CaptivePortal';

    my $sess_file = EBox::CaptivePortal->SIDS_DIR . $session_key;
    return unless (-r $sess_file);

    unless (open ($sidFile,  $sess_file)) {
        throw EBox::Exceptions::Internal("Could not open $sess_file");
    }
    # Lock in shared mode for reading
    flock($sidFile, LOCK_SH)
        or throw EBox::Exceptions::Lock('EBox::CaptivePortal::Auth');

    my $sess_info = join('', <$sidFile>);
    my $data = YAML::XS::Load($sess_info);

    if (defined($data)) {
        $user = $data->{user};
    }

    # Release the lock
    flock($sidFile, LOCK_UN);
    close($sidFile);

    if (defined($user)) {
        updateSession($session_key, $r->connection->remote_ip());
        return $user;
    } else {
        $r->subprocess_env(LoginReason => "NotLoggedIn");
    }

    return;
}

# Method: logout
#
#   Overriden method from <Apache2::AuthCookie>.
#
sub logout # (request)
{
    my ($self, $r) = @_;

    eval 'use EBox::CaptivePortal';

    # expire session
    my $session_key = substr($self->key($r), 0, 32);
    updateSession($session_key, $r->connection->remote_ip(), 0);

    # notify captive daemon
    system('cat ' . EBox::CaptivePortal->LOGOUT_FILE);

    $self->SUPER::logout($r);
}

1;
